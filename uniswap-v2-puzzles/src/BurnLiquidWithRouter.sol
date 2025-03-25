// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IERC20.sol";

contract BurnLiquidWithRouter {
    /**
     *  BURN LIQUIDITY WITH ROUTER EXERCISE
     *
     *  The contract has an initial balance of 0.01 UNI-V2-LP tokens.
     *  Burn a position (remove liquidity) from USDC/ETH pool to this contract.
     *  The challenge is to use Uniswapv2 router to remove all the liquidity from the pool.
     *
     */
    address public immutable router;

    constructor(address _router) {
        router = _router;
    }

    function burnLiquidityWithRouter(address pool, address usdc, address weth, uint256 deadline) public {
        IUniswapV2Pair pair = IUniswapV2Pair(pool);
        uint256 lpTokens = pair.balanceOf(address(this));
        pair.approve(router, lpTokens);
        (uint256 usdcTokens, uint256 wethTokens) =
            IUniswapV2Router(router).removeLiquidity(usdc, weth, lpTokens, 1, 1, address(this), deadline);
        require(usdcTokens > 0, "no USDC received");
        require(wethTokens > 0, "no WETH received");
        require(IERC20(usdc).balanceOf(address(this)) == usdcTokens, "balance of USDC not correct");
        require(IERC20(weth).balanceOf(address(this)) == wethTokens, "balance of WETH not correct");
    }
}

interface IUniswapV2Router {
    /**
     *     tokenA: the address of tokenA, in our case, USDC.
     *     tokenB: the address of tokenB, in our case, WETH.
     *     liquidity: the amount of LP tokens to burn.
     *     amountAMin: the minimum amount of amountA to receive.
     *     amountBMin: the minimum amount of amountB to receive.
     *     to: recipient address to receive tokenA and tokenB.
     *     deadline: timestamp after which the transaction will revert.
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
}
