// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;
/// NOTE You may import more dependencies as needed
import {IUniswapV3SwapCallback} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {PoolAddress, Path, CallbackValidation, TickMath} from "./dependencies/Uniswap.sol";

import "forge-std/interfaces/IERC20.sol";
import {IFlashswapCallback} from "./interfaces/IFlashswapCallback.sol";
import {console2 as console} from "forge-std/console2.sol";  // newer, more overloads
/// @title Flashswap
/// @notice Enables a "multi-hop flashswap" using Uniswap.
contract Flashswap is IUniswapV3SwapCallback {
    address internal constant FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    
    /// @dev Transient storage variable used for returning the computed amount in for an exact output swap.
    uint256 private amountInCached = 0;

    struct ExactOutputParams {
        bytes path; // Uniswap multi-hop swap path
        address recipient; 
        uint256 amountOut;
        bytes data; // Data passed to the caller's own callback control flow
    }

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        bytes data;
    }

    struct SwapCallbackData {
        bytes path;
        address payer;
        bytes userData;
    }

    function pay(
        address token,
        address payer,
        address recipient,
        uint256 amount
    ) internal {
        // If the payer is this contract, we can just transfer directly
        if (payer == address(this)) {
            IERC20(token).transfer(recipient, amount);
        } else {
            // Otherwise, we need to transfer from the payer
            // This would require approval from the payer
            IERC20(token).transferFrom(payer, recipient, amount);
        }
    }

    /// TODO Implement this callback function. See the interface for more descriptions.
    /// @inheritdoc IUniswapV3SwapCallback
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    ) external override {
        require(amount0Delta > 0 || amount1Delta > 0); // swaps entirely within 0-liquidity regions are not supported
        SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));
        (address tokenIn, address tokenOut, uint24 fee) = Path.decodeFirstPool(data.path);
        CallbackValidation.verifyCallback(FACTORY, tokenIn, tokenOut, fee);

        // Simple logging
        console.log("--- Callback Entry ---");

        (bool isExactInput, uint256 amountToPay) =
            amount0Delta > 0
                ? (tokenIn < tokenOut, uint256(amount0Delta))
                : (tokenOut < tokenIn, uint256(amount1Delta));
        if (isExactInput) {
            console.log("isExactInput");
            pay(tokenIn, data.payer, msg.sender, amountToPay);
        } else {
            // either initiate the next swap or pay
            if (Path.hasMultiplePools(data.path)) {
                bytes memory newPath = Path.skipToken(data.path);
                console.log("hasMultiplePools");
                console.log("about to initiate next swap");
                console.log("pool caller is: ", msg.sender);
                // Create a new SwapCallbackData that preserves the original userData
                SwapCallbackData memory newData = SwapCallbackData({
                    path: newPath,
                    payer: data.payer,
                    userData: data.userData
                });
                exactOutputInternal(amountToPay, msg.sender, 0, newData);
                console.log("next swap initiated");
            } else {
                amountInCached = amountToPay;
                tokenIn = tokenOut; // swap in/out because exact output swaps are reversed
                //pay(tokenIn, data.payer, msg.sender, amountToPay);

                // Simple logging
                console.log("--- Final Callback ---");
                console.log("amount0Delta value:");
                //console.logInt(amount0Delta);
                console.log("amount1Delta value:");
                //console.logInt(amount1Delta);
                
                // Check if we're at the first hop of the reverse path (WBTC-USDC pool)
                // We only want to trigger the flashSwapCallback for the first pool in the reverse path
                // which is the one that gives us WBTC (the desired output token)
                
                // The first token in the path is the desired output token (in exactOutput swaps)
                // Get it from the data.path by decoding the first pool's tokenIn
                console.log("tokenOut:", tokenOut);
                
                uint256 amountReceived;
                if (amount0Delta < 0) {
                    amountReceived = uint256(-amount0Delta);
                } else {
                    amountReceived = uint256(amount0Delta);
                }

                address callerAddr = abi.decode(data.userData, (address));
                console.log("-- callerAddr --");
                console.log(callerAddr);

                IFlashswapCallback(callerAddr).flashSwapCallback(
                    amountReceived,
                    amountToPay,
                    msg.sender,
                    data.userData
                );
                console.log("flashSwapCallback completed");
                
            }
        }
    }

    /// @dev Performs a single exact output swap
    function exactOutputInternal(
        uint256 amountOut,
        address recipient,
        uint160 sqrtPriceLimitX96,
        SwapCallbackData memory data
    ) private returns (uint256 amountIn) {
        // allow swapping to the router address with address 0
        if (recipient == address(0)) recipient = address(this);

        (address tokenOut, address tokenIn, uint24 fee) = Path.decodeFirstPool(data.path);

        bool zeroForOne = tokenIn < tokenOut;

        (int256 amount0Delta, int256 amount1Delta) =
            _getPool(tokenIn, tokenOut, fee).swap(
                recipient,
                zeroForOne,
                -int256(amountOut),
                sqrtPriceLimitX96 == 0
                    ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                    : sqrtPriceLimitX96,
                abi.encode(data)
            );

        uint256 amountOutReceived;
        (amountIn, amountOutReceived) = zeroForOne
            ? (uint256(amount0Delta), uint256(-amount1Delta))
            : (uint256(amount1Delta), uint256(-amount0Delta));
        // it's technically possible to not receive the full output amount,
        // so if no price limit has been specified, require this possibility away
        console.logUint(amountOutReceived);
        console.logUint(amountOut);
        if (sqrtPriceLimitX96 == 0) require(amountOutReceived == amountOut, "Not enough output");
    }

    /// TODO Implement this function.
    /// @notice This is the entrypoint for the caller.
    /// @param params See `ExactOutputParams`.
    function exactOutput(ExactOutputParams calldata params) external {
        // it's okay that the payer is fixed to msg.sender here, as they're only paying for the "final" exact output
        // swap, which happens first, and subsequent swaps are paid for within nested callback frames

        exactOutputInternal(
            params.amountOut,
            params.recipient,
            0,
            SwapCallbackData({path: params.path, payer: msg.sender, userData: abi.encode(msg.sender)})
        );
        console.log("exactOutput completed");

        // amountIn = amountInCached;
        // require(amountIn <= params.amountInMaximum, 'Too much requested');
        // amountInCached = 0;
    }

    /// NOTE: This implementation is optional.
    /// @notice Instead of having the user specify the exact ouptut amount they
    /// want in the swap, they can specify the exact input amount.
    /// @param params See `ExactInputParams`.
    function exactInput(ExactInputParams calldata params) external {}

    /// @dev Returns the pool for the given token pair and fee. The pool contract may or may not exist.
    function _getPool(address tokenA, address tokenB, uint24 fee) private pure returns (IUniswapV3Pool) {
        return IUniswapV3Pool(PoolAddress.computeAddress(FACTORY, PoolAddress.getPoolKey(tokenA, tokenB, fee)));
    }
}