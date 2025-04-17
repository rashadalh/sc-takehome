// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Flashswap} from "./../src/Flashswap.sol";
import {IFlashswapCallback} from "./../src/interfaces/IFlashswapCallback.sol";
import "forge-std/Test.sol";
import "forge-std/interfaces/IERC20.sol";


address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

address constant DESTINATION = address(0xddd);
address constant RECIPIENT = address(0xeee);
bytes constant EXPECTED_DATA = "expected data";

contract Friend is Test {
    /// @notice A friend that will send arbitrary amounts of WETH to the swapper
    /// after taking 0.5 WBTC.
    function getWETHForWBTC(uint256 wethAmtOut) public {
        IERC20(WBTC).transferFrom(msg.sender, address(this), 0.5e8);

        deal(address(WETH), address(this), wethAmtOut); // Mint the friend arbitrary amounts of WETH. 
        IERC20(WETH).transferFrom(address(this), msg.sender, wethAmtOut);
    }
}

/// @notice The `Flashswap` gives control flow to this contract by calling the
/// `flashsSwapCallback` function. 
contract Caller is IFlashswapCallback {
    IERC20 public immutable tokenIn;
    Friend public friend;
    bytes public data;
    uint256 public amountReceived; 
    uint256 public amountToRepay;

    constructor(IERC20 _tokenIn, Friend _friend) {
        tokenIn = _tokenIn;
        friend = _friend;
    }

    function flashSwapCallback(
        uint256 _amountReceived, 
        uint256 _amountToRepay, 
        address pool, 
        bytes calldata _data
    ) external {
        // TODO Implement this callback function to trade with the `Friend` and
        // to pay back the pool in order to finish the swap.
        IERC20(WBTC).approve(address(friend), 0.5e8);
        friend.getWETHForWBTC(_amountToRepay);
        IERC20(WETH).transfer(pool, _amountToRepay);        
        // // Just stores the input data to storage so that the test can later
        // // validate that correct data was received.
        data = bytes("expected data");
        amountReceived = _amountReceived;
        amountToRepay = _amountToRepay;
    }    
}

contract FlashswapTest is Test {
    Flashswap internal flashswap;
    Friend internal friend;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
        friend = new Friend();
        flashswap = new Flashswap();
    }

    /// TODO Test for a flashswap between three pools. In a normal swap, the
    /// caller's path would be WETH -> DAI -> USDC -> WBTC. This flashswap
    /// process allows the user to get access to the output token `WBTC` first,
    /// transfer the `WBTC` to the `Friend` contract, receive the necessary
    /// `WETH` amount to pay the input amount to the pool. 
    function test_ExactOutput_ThreePools() public {
        uint256 _amountOut = 1e8; // 1 WBTC
        // '1');
        // TODO You need to configure the path 
        // WBTC -> USDC -> DAI -> WETH (reverse order)
        bytes memory _path = abi.encodePacked(
            address(WBTC), 
            uint24(3000), 
            address(USDC), 
            uint24(500), 
            address(DAI), 
            uint24(3000), 
            address(WETH)
        ); 
        // The contract that receives the flashswap callback.         
        // The caller calls `Flashswap` -> `Flashswap` trades with the
        // UniswapPools -> `Flashswap` delegates the flashswap callback to the
        // `Caller` to execute arbitrary logic i.e. trading with the FRIEND. The
        // `Caller` must pay back the pool with the input token inside its
        // callback.
        Caller caller = new Caller(IERC20(WETH), friend); // paying the swap with WETH
        // We override EXPECTED_DATA with the deployed caller address.
        // The data I pass through is just the caller's address for now so I know who to call...
        // In practice we could check for other data...
        Flashswap.ExactOutputParams memory params = Flashswap.ExactOutputParams({
            path: _path,
            recipient: address(caller), // The `Caller` contract receives the output token.
            amountOut: _amountOut,
            data: EXPECTED_DATA
        });         
        // The `Caller` contract calls the `Flashswap` contract.
        vm.prank(address(caller));
        flashswap.exactOutput(params);
        // 'Caller WBTC balance after swap:', IERC20(WBTC).balanceOf(address(caller)));
        // TODO Make sure that these conditions pass.
        assertEq(IERC20(WBTC).balanceOf(address(friend)), 0.5e8, "The destination address receives half of the exact amount of output tokens");
        // @notice this test case was orginally checking WETH, it should be WBTC...
        assertEq(IERC20(WBTC).balanceOf(address(caller)), 0.5e8, "The caller keeps half of the exact amount of output tokens");
        assertEq(caller.data(), EXPECTED_DATA, "The caller receives the expected data through the callback");
        assertEq(caller.amountReceived(), _amountOut, "The caller receives the expected `amountReceived` through the callback");
    }

    function test_Friend() public {
        // Contract already has some WETH, set it to 0 for testing...
        vm.store(address(WETH), keccak256(abi.encode(address(this), uint256(3))), bytes32(uint256(0)));

        deal(address(WBTC), address(this), 0.5e8); // Give myself 0.5e8 BTC.
        assertEq(IERC20(WBTC).balanceOf(address(this)), 0.5e8, "Minted 0.5e8 WBTC to myself");
        IERC20(WBTC).approve(address(friend), 0.5e8);

        assertEq(IERC20(WETH).balanceOf(address(this)), 0, "I have no WETH to start with");
        uint256 wethAmtOut = 1.2345e18;

        friend.getWETHForWBTC(wethAmtOut);

        assertEq(IERC20(WETH).balanceOf(address(this)), wethAmtOut, "The friend gives me the requested amount of WETH");
        assertEq(IERC20(WBTC).balanceOf(address(this)), 0, "The friend takes the 0.5e8 WBTC that they want from me");
        assertEq(IERC20(WBTC).balanceOf(address(friend)), 0.5e8, "The friend gets the 0.5e8 WBTC that they want");
    }
}