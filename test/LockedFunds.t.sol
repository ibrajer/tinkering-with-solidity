// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Test, console} from "forge-std/Test.sol";
import {NotBasedRewarder} from "../src/LockedFunds.sol";

contract SimpleToken is ERC20 {
    constructor() ERC20("SimpleToken", "STK") {
        _mint(msg.sender, 1000 * 10 ** decimals());
    }
}

contract LockedFundsTest is Test {
    address owner = address(0x1);
    address user = address(0x2);
    NotBasedRewarder public rewarder;
    SimpleToken public rewardToken;
    SimpleToken public depositToken;

    function setUp() public {
        vm.startPrank(owner);
        rewardToken = new SimpleToken();
        depositToken = new SimpleToken();
        rewarder = new NotBasedRewarder(rewardToken, depositToken);
        depositToken.transfer(user, 1000);
        rewardToken.transfer(user, 1000);
        vm.stopPrank();

        vm.startPrank(user);
        rewardToken.approve(address(rewarder), 100);
        rewarder.deposit(100);
        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.prank(user);
        rewarder.withdraw(10);
    }
}
