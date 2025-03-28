// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {MyMevBot} from "../src/MyMevBot.sol";
import "../src/interfaces/IUniswapV2Pair.sol";

contract ArbitrageTest is Test {
    MyMevBot public myMevBot;
    address public weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public USDC_WETH_pool = 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc;
    address public ETH_USDT_pool = 0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852;
    address public flashLenderPool = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;

    function setUp() public {
        vm.rollFork(20055371);

        myMevBot = new MyMevBot(flashLenderPool, weth, usdc, usdt, router);

        // Deal 0xBeeb with some tokens
        deal(usdt, address(0xBeeb), 3_000_000e6);
        deal(weth, address(0xBeeb), 10 ether);

        vm.startPrank(address(0xBeeb));
        IUniswapV2Pair(usdt).transfer(ETH_USDT_pool, 3_000_000e6);

        IUniswapV2Pair(weth).transfer(ETH_USDT_pool, 10 ether);

        IUniswapV2Pair(ETH_USDT_pool).mint(address(0xB0b));
        vm.stopPrank();
    }

    function test_PerformArbitrage() public {
        vm.prank(address(0xb0b));
        myMevBot.performArbitrage();

        uint256 puzzleBal = IUniswapV2Pair(usdc).balanceOf(address(myMevBot));

        require(puzzleBal > 0, "Arbitrage Failed.");
    }
}
