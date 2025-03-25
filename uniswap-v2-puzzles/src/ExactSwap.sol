// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IERC20.sol";

contract ExactSwap {
    /**
     *  PERFORM AN SIMPLE SWAP WITHOUT ROUTER EXERCISE
     *
     *  The contract has an initial balance of 1 WETH.
     *  The challenge is to swap an exact amount of WETH for 1337 USDC token using the `swap` function
     *  from USDC/WETH pool.
     *
     */
    function performExactSwap(address pool, address weth, address usdc) public {
        /**
         *     swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data);
         *
         *     amount0Out: the amount of USDC to receive from swap.
         *     amount1Out: the amount of WETH to receive from swap.
         *     to: recipient address to receive the USDC tokens.
         *     data: leave it empty.
         */
        IUniswapV2Pair pair = IUniswapV2Pair(pool);

        (uint256 usdcReserve, uint256 wethReserve,) = pair.getReserves();

        uint256 desiredUsdc = 1337 * 1e6;
        uint256 desiredUsdcAfterFee = desiredUsdc * 997 / 1000;
        uint256 exactWeth = wethReserve - ((wethReserve * usdcReserve) / (usdcReserve + desiredUsdc));
        IERC20(weth).transfer(pool, exactWeth);
        pair.swap(desiredUsdc, 0, address(this), "");
    }
}
