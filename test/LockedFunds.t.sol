// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {NotBasedToken, NotBasedRewarder} from "../src/LockedFunds.sol";

contract LockedFundsTest is Test {
    address owner = address(0x1);
    address user = address(0x2);
    NotBasedRewarder public rewarder;
    NotBasedToken public rewardToken;
    NotBasedToken public depositToken;

    function setUp() public {
        vm.startPrank(owner);
        rewardToken = new NotBasedToken(owner);
        depositToken = new NotBasedToken(owner);
        rewarder = new NotBasedRewarder(rewardToken, depositToken);
        vm.stopPrank();
    }

    function testWithdraw() public {}
}
