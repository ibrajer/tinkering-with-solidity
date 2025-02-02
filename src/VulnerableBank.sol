// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
/**
 * @title Vulnerable Bank
 * @dev This contract allows deposits and withdrawals, but is vulnerable to a reentrancy attack.
 */

contract VulnerableBank {
    mapping(address => uint256) public balances;

    /**
     * @dev Deposit Ether into the bank.
     */
    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    /**
     * @dev Withdraw specified `_amount` of Ether from the bank.
     *      This implementation is vulnerable to reentrancy because it
     *      transfers Ether before updating the user's balance.
     */
    function withdraw(uint256 _amount) external {
        require(balances[msg.sender] >= _amount, "Insufficient balance");

        // 1. Interact (transfer Ether to msg.sender)
        (bool success,) = msg.sender.call{value: _amount}("");
        require(success, "Transfer failed");

        // 2. Effects (update the user's balance)
        // NOTE: I added unchecked{} here to disable overflow/underflow checks
        // they are automatically enabled on Solidity v0.8+, if I don't do this, I can't simulate re-entrancy
        unchecked {
            balances[msg.sender] -= _amount;
        }
    }

    /**
     * @dev Fallback function to accept Ether.
     */
    receive() external payable {}
}
