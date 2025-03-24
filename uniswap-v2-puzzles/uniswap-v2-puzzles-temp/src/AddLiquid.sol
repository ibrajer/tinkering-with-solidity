// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IERC20.sol";

contract AddLiquid {
    /**
     *  ADD LIQUIDITY WITHOUT ROUTER EXERCISE
     *
     *  The contract has an initial balance of 1000 USDC and 1 WETH.
     *  Mint a position (deposit liquidity) in the pool USDC/WETH to msg.sender.
     *  The challenge is to provide the same ratio as the pool then call the mint function in the pool contract.
     *
     */
    function addLiquidity(address usdc, address weth, address pool, uint256 usdcReserve, uint256 wethReserve) public {
        IUniswapV2Pair pair = IUniswapV2Pair(pool);

        // your code start here

        // see available functions here: https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Pair.sol

        // pair.getReserves();
        // pair.mint(...);

        // total supply of all LP tokens
        uint256 totalSupply = pair.totalSupply();

        // maximum balance that this contract can provide per token
        uint256 usdcBalanceTotal = IERC20(usdc).balanceOf(address(this));
        uint256 wethBalanceTotal = IERC20(weth).balanceOf(address(this));

        // calculate liquidity if we took maximum balance per USDC and per WETH
        uint256 liquidity0 = (usdcBalanceTotal * totalSupply) / usdcReserve;
        uint256 liquidity1 = (wethBalanceTotal * totalSupply) / wethReserve;

        // pick the minimum one because the mint function will always opt for minimum
        if (liquidity0 <= liquidity1) {
            // transfer maximum USDC balance and calculate amount of WETH tokens to have the correct ratio
            uint256 wethTokens = (liquidity0 * wethReserve) / totalSupply;
            IERC20(usdc).transfer(address(pool), usdcBalanceTotal);
            IERC20(weth).transfer(address(pool), wethTokens);
        } else {
            // transfer maximum WTH balance and calculate amount of USDC tokens to have the correct ratio
            uint256 usdcTokens = (liquidity1 * usdcReserve) / totalSupply;
            IERC20(usdc).transfer(address(pool), usdcTokens);
            IERC20(weth).transfer(address(pool), wethBalanceTotal);
        }

        uint256 liquidity = pair.mint(msg.sender);
        // it won't be equal because Uniswap rounds down, the test is also failing
        //require(min(liquidity0, liquidity1) == liquidity, "liquidity not equal");
    }

    // Internal function
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }
}
