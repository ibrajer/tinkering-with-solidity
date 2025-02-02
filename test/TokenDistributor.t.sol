// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Test, console} from "forge-std/Test.sol";
import {TokenDistributor} from "../src/TokenDistributor.sol";

contract SimpleToken is ERC20 {
    constructor() ERC20("SimpleToken", "STK") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}

contract TokenDistributorTest is Test {
    address tokenOwner = address(0x1);
    TokenDistributor public tokenDistributor;
    SimpleToken public simpleToken;
    address[] public recipients;

    function setUp() public {
        vm.startPrank(tokenOwner);
        simpleToken = new SimpleToken();
        tokenDistributor = new TokenDistributor(address(simpleToken), tokenOwner);
        vm.stopPrank();
    }

    function testDistribution() public {
        vm.startPrank(tokenOwner);
        recipients.push(address(0x10));
        recipients.push(address(0x11));
        recipients.push(address(0x12));

        for (uint256 i = 0; i < recipients.length; i++) {
            assertEq(0, simpleToken.balanceOf(recipients[i]));
        }

        // uint256 amount = 100;
        // tokenDistributor.distributeTokens(recipients, amount);

        // for (uint256 i = 0; i < recipients.length; i++) {
        //     assertEq(100, simpleToken.balanceOf(recipients[i]));
        // }
        vm.stopPrank();
    }
}
