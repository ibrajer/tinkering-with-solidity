// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IERC20.sol";

contract BurnLiquid {
    /**
     *  BURN LIQUIDITY WITHOUT ROUTER EXERCISE
     *
     *  The contract has an initial balance of 0.01 UNI-V2-LP tokens.
     *  Burn a position (remove liquidity) from USDC/ETH pool to this contract.
     *  The challenge is to use the `burn` function in the pool contract to remove all the liquidity from the pool.
     *
     */
    function burnLiquidity(address pool) public {
        /**
         *     burn(address to);
         *
         *     to: recipient address to receive tokenA and tokenB.
         */
        IUniswapV2Pair pair = IUniswapV2Pair(pool);

        uint256 lpTokens = pair.balanceOf(address(this));
        // first burner must send LP tokens within the same transaction
        pair.transfer(pool, lpTokens);
        // now LP tokens can be burned and USDC and ETH tokens will be received in return
        pair.burn(address(this));
    }
}
