// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenDistributor is Ownable {
    IERC20 private token;

    constructor(IERC20 _token) Ownable(msg.sender) {
        require(_token != address(0), "token address can't be zero");
        token = _token;
    }

    function distributeTokens(address[] calldata recipients, uint256 amount) external onlyOwner {
        uint256 distributedAmount = recipients.length * amount;
        uint256 currentBalance = token.allowance(address(token), address(this));
        require(currentBalance >= distributedAmount, "not enough balance");

        for (uint256 i = 0; i < recipients.length; i++) {
            require(address(recipients[i]) != address(0), "recepient must not be zero address");
            SafeERC20.safeTransferFrom(token, address(this), recipients[i], amount);
        }
    }
}
