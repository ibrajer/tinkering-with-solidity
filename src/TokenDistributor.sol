// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenDistributor is Ownable {
    event TokensDistributed(address recepient, uint256 amount);

    address private tokenAddress;
    address private tokenOwner;

    constructor(address _tokenAddress, address _tokenOwner) Ownable(msg.sender) {
        require(_tokenAddress != address(0), "token address can't be zero");
        require(_tokenOwner == msg.sender, "must be owned by the token owner");
        tokenAddress = _tokenAddress;
        tokenOwner = _tokenOwner;
    }

    function distributeTokens(address[] calldata recipients, uint256 amountPerRecepient) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        uint256 totalAmountToDistribute = recipients.length * amountPerRecepient;
        uint256 balanceBefore = token.balanceOf(tokenOwner);
        require(balanceBefore >= totalAmountToDistribute, "not enough balance");
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "recepient must not be zero address");
            SafeERC20.safeTransfer(token, recipients[i], amountPerRecepient);
            emit TokensDistributed(recipients[i], amountPerRecepient);
        }
        uint256 balanceAfter = token.balanceOf(tokenOwner);
        require(balanceBefore - balanceAfter == totalAmountToDistribute, "invalid amount distributed");
    }
}
