// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import {Test, console} from "forge-std/Test.sol";
import {AtomicSwapTimelock} from "../src/AtomicSwapTimelock.sol";

contract SimpleToken is ERC20, Ownable {
    constructor() ERC20("SimpleToken", "STK") Ownable(msg.sender) {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}

contract AtomicSwapTimelockTest is Test {
    address atomicSwapOwner = address(0x1);
    AtomicSwapTimelock public atomicSwapContract;
    // for simplicity, let's say sender and receiver token are owned by the same address
    address simpleTokenOwner = address(0x2);
    SimpleToken public senderToken;
    SimpleToken public receiverToken;

    function setUp() public {
        // deploy ERC20 token
        vm.startPrank(simpleTokenOwner);
        senderToken = new SimpleToken();
        receiverToken = new SimpleToken();
        vm.stopPrank();

        // deploy the atomic swap contract, link sender and receiver tokens to this contract
        vm.startPrank(atomicSwapOwner);
        atomicSwapContract = new AtomicSwapTimelock(address(senderToken), address(receiverToken));
        vm.stopPrank();
    }

    function testHappyPath() public {
        address senderUser = address(0x1000);
        address receiverUser = address(0x2000);

        // from sender and receiver token contracts, send some ERC20 to sender and receiver user
        vm.startPrank(simpleTokenOwner);
        senderToken.transfer(senderUser, 10 * 10 ** senderToken.decimals());
        receiverToken.transfer(receiverUser, 20 * 10 ** receiverToken.decimals());
        vm.stopPrank();

        // sanity check balances for sender and receiver on both ERC20 token contracts
        assertEq(10 * 10 ** senderToken.decimals(), senderToken.balanceOf(senderUser));
        assertEq(0, senderToken.balanceOf(receiverUser));
        assertEq(0, receiverToken.balanceOf(senderUser));
        assertEq(20 * 10 ** receiverToken.decimals(), receiverToken.balanceOf(receiverUser));

        // sender sets allowance of 2 ERC20 token to the atomic swap contract
        // receiver sets allowance of 1 ERC20 token to the atomic swap contract
        uint256 senderAmount = 2 * 10 ** senderToken.decimals();
        uint256 receiverAmount = 1 * 10 ** receiverToken.decimals();
        vm.prank(senderUser);
        senderToken.approve(address(atomicSwapContract), senderAmount);
        vm.prank(receiverUser);
        receiverToken.approve(address(atomicSwapContract), receiverAmount);
        assertEq(senderAmount, senderToken.allowance(senderUser, address(atomicSwapContract)));
        assertEq(receiverAmount, receiverToken.allowance(receiverUser, address(atomicSwapContract)));

        // sender and receiver agree on a secret (secret is transported through a secure communication channel)
        string memory secret = "life is not all peaches and cream when you have re-entrancy";
        bytes32 hashedSecret = keccak256(abi.encode(secret));

        // sender submits the swap request
        vm.warp(1739307166); // set block timestamp
        vm.prank(senderUser);
        atomicSwapContract.submitSwapRequest(senderUser, receiverUser, senderAmount, receiverAmount, hashedSecret);

        // receiver executes the swap after 100 seconds (deadline not reached)
        vm.warp(1739307266); // set block timestamp
        vm.prank(receiverUser);
        atomicSwapContract.executeSwap(secret);

        // check sender and receiver balances on both ERC20 token contracts after atomic swap
        assertEq(8 * 10 ** senderToken.decimals(), senderToken.balanceOf(senderUser));
        assertEq(2 * 10 ** senderToken.decimals(), senderToken.balanceOf(receiverUser));
        assertEq(1 * 10 ** receiverToken.decimals(), receiverToken.balanceOf(senderUser));
        assertEq(19 * 10 ** receiverToken.decimals(), receiverToken.balanceOf(receiverUser));
    }
}
