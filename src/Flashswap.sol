// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;
/// NOTE You may import more dependencies as needed
import {IUniswapV3SwapCallback} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {PoolAddress, Path, CallbackValidation} from "./dependencies/Uniswap.sol";

/// @title Flashswap
/// @notice Enables a "multi-hop flashswap" using Uniswap.
contract Flashswap is IUniswapV3SwapCallback {
    address internal constant FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

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

    /// TODO Implement this callback function. See the interface for more
    /// descriptions.
    /// @inheritdoc IUniswapV3SwapCallback
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external override {}

    /// TODO Implement this function.
    /// @notice This is the entrypoint for the caller.
    /// @param params See `ExactOutputParams`.
    function exactOutput(ExactOutputParams calldata params) external {}

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