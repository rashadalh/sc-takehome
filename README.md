## Ion Takehome
- Because takehomes are not paid for hours worked, this task is designed to help us gauge the participants’ skills and understanding, rather than to produce work that will be used by the team.
- To respect the participant’s work, we will not be taking this work or modifying it for the team’s interest in any way.
## Problem

**Here's the scenario:**
1. I want to purchase 1 WBTC by paying the necessary amount of WETH.
2. But I do not yet have any WETH that I can use to pay for this swap. 
3. Fortunately, I have a friend who will transfer me the necessary WETH amount, **if I give them just 0.5 of WBTC.** 
4. This is a great deal, since I'm not paying for anything and I get half of WBTC.
5. One issue is that I don't have access to that 0.5 WBTC, **before I make the swap itself.**
    - So we need a way to access the token that I'm buying first, send a part of that token to the friend, receive the WETH amount necessary to purchase the WBTC amount, then pay the Uniswap pool. 
6. [Callbacks](https://github.com/Uniswap/v3-core/blob/main/contracts/UniswapV3Pool.sol#L776) in Uniswap's `swap` function helps us achieve this.
    - Concretely, 
        1. I can receive the 1 WBTC amount that I'm buying before this callback function is called.
        2. In the callback, I can transfer 0.5 WBTC to my friend, then receive some amount of WETH from my friend. 
        3. Then at the end of the callback, I can use this WETH that I received from my friend to pay for the cost of the
        swap. (If I don't pay the pool, then Uniswap will revert the swap);
        4. We call this a `flashswap` since we gain access to the output asset first, take control flow, and have the pool guarantee that the call succeeds if and only if the input asset is paid for.
7. Now here's the real problem: How can I implement a **multi-hop flashswap**?
    - A single-hop flashswap between WETH (sell) <> WBTC (buy) means I get access to WBTC, insert a callback in the middle, then pays the WETH back to the pool. 
    - A multi-hop flashswap between WETH (sell) <> DAI <> USDC <> WBTC (buy) means I get access to WBTC, do a callback, then pay WETH. 
    - In both cases, I am buying WBTC and paying WETH and taking control flow in between. But importantly, the second bullet point ***conducts the swap across multiple pools***. 
    - Your job is to implement this second bullet point, a ***multi-hop flashswap*** that allows you to access to the output token (WBTC) before paying the input token (WETH), while routing the swap across multiple pools

## Task
- There are three pools.
    1. WBTC <> USDC
    2. USDC <> DAI 
    3. DAI <> WETH
- **TODO**
    - See all the `TODO` items in `Flashswap.sol` and `Flashswap.t.sol` 
    - Implement the `exactOutput` and the `uniswapV3SwapCallback` functions for the multi-hop flashswap. 
    - Implement the `Caller.flashSwapCallback` function.  
    - Implement the `_path` in `test_ExactOutput_ThreePools`. 
    - Run the `test_ExactOutput_ThreePools` test and make it pass!
- `test_ExactOutput_ThreePool` 
    - This test is meant to validate the following process:
        1. Flashswap WETH (sell) <> WBTC (buy) using the three pools in the path.
        2. After you receive WBTC, trade with the `Friend` contract in the callback. (The `Friend` will take `0.5` WBTC and give you any requested amount of `WETH`). 
        3. Use the `WETH` from the friend to pay the swap. 
        4. Congratulations! You just finished a multi-hop flashswap. 
    - NOTE You must set up the `.env` file for the fork test. See `.env.example`.
- It is strongly recommended that you review the `FlashSwap.t.sol` and `Flashswap.sol` for the `TODO` items as you begin.

## Resources
1. Multi-hop Swap
- [SwapRouter.sol contract implements a multi-hop swap](https://github.com/Uniswap/v3-periphery/blob/697c2474757ea89fec12a4e6db16a574fe259610/contracts/SwapRouter.sol#L57-L84) that takes in the path that encodes a list of pools that the swap should go through.
- Your solution is also a multi-hop swap and may look very similar to this contract. 
2. Path
- Uniswap swap paths can be [encoded in bytes and decoded](https://uniswapv3book.com/milestone_4/path.html?highlight=path#swap-path) using the [`Path.sol` library](https://github.com/Uniswap/v3-periphery/blob/697c2474757ea89fec12a4e6db16a574fe259610/contracts/libraries/Path.sol). 
- Example of using the `path` is also in `SwapRouter.sol`. 
3. You may need to review other resources related to UniV3 if not yet familiar.

## Note
1. Recommendations
- Start by diagramming out the flow for callback control flow to ensure understanding of the requirements. 
2. NOTE
- If the task is challenging, please do not hestitate to reach out with any questions if there are blockers. 
    - We would ***much rather have open discussions around the problem to work it out together as part of the takehome process*** than to have the participant be discouraged and not complete the task. We are looking for a glimpse into your thought process as you tacke non-trivial problems. 
- You are also encouraged to reference any resources or tools online if it helps your process.

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
