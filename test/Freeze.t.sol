// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {StableCoin} from "../src/Freeze.sol";

contract FreezeTest is Test {
    address owner = address(0x1);
    address frozenAccount = address(0x2);
    address unfrozenAccount = address(0x3);
    address receiver = address(0x4);
    StableCoin public coin;

    function setUp() public {
        vm.startPrank(owner);
        coin = new StableCoin();

        // owner mints some tokens to the account, then freezes it
        coin.mint(frozenAccount, 1000);
        coin.freeze(frozenAccount);
        vm.stopPrank();
    }

    function testFrozenAccount() public {
        // confirm that account is indeed frozen
        bool isFrozen = coin.isFrozen(frozenAccount);
        assert(isFrozen);

        // not able to transfer anything
        vm.startPrank(frozenAccount);
        vm.expectRevert("account frozen");
        coin.transfer(receiver, 10);

        // use a different unfrozen account and set allowance
        vm.startPrank(frozenAccount);
        coin.approve(unfrozenAccount, 10);

        // bypass the frozen account through a different account's allowance
        vm.startPrank(unfrozenAccount);
        bool success = coin.transferFrom(frozenAccount, receiver, 10);
        assert(success);
    }
}

// EXTREME VULNERABILITY on StableCoin contract is this function:
// function burn(address from, uint256 amount) public {
//     _burn(from, amount);
// }
// there is no onlyOwner modifier set on it! anyone can burn tokens on this contract
