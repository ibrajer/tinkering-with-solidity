// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import {Test, console} from "forge-std/Test.sol";
import {StakingContract} from "../src/StakingContract.sol";

contract SimpleToken is ERC20, Ownable {
    constructor() ERC20("SimpleToken", "STK") Ownable(msg.sender) {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}

contract SimpleNFT is ERC721, Ownable {
    uint256 public nextTokenId;

    constructor() ERC721("SimpleNFT", "SNFT") Ownable(msg.sender) {}

    function mint(address recipient) external onlyOwner returns (uint256) {
        uint256 tokenId = nextTokenId++;
        _mint(recipient, tokenId);
        return tokenId;
    }

    function burn(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "You are not the owner");
        _burn(tokenId);
    }
}

contract StakingContractTest is Test {
    address stakingContractOwner = address(0x1);
    StakingContract public stakingContract;
    address simpleTokenOwner = address(0x2);
    SimpleToken public simpleTokenContract;
    address simpleNFTOwner = address(0x3);
    SimpleNFT public simpleNFTContract;

    uint256 public constant TIME_WINDOW_UNIT_SECS = 7200;
    uint256 public constant TIME_WINDOW_MAX_REWARD = 0.1 ether;

    function setUp() public {
        // deploy ERC20 token for rewards
        vm.prank(simpleTokenOwner);
        simpleTokenContract = new SimpleToken();

        // deploy ERC721 token for NFTs
        vm.prank(simpleNFTOwner);
        simpleNFTContract = new SimpleNFT();

        // deploy the staking contract and set up staking time window
        vm.startPrank(stakingContractOwner);
        stakingContract = new StakingContract(address(simpleTokenContract), address(simpleNFTContract));
        stakingContract.setConfig(TIME_WINDOW_UNIT_SECS, TIME_WINDOW_MAX_REWARD);
        vm.stopPrank();

        // transfer 1000 ERC20 tokens to the staking contract to be able to distribute rewards
        vm.startPrank(simpleTokenOwner);
        simpleTokenContract.transfer(address(stakingContract), 1000 * 10 ** simpleTokenContract.decimals());
        vm.stopPrank();
    }

    function testStakingHappyPath() public {
        address user = address(0x1000);

        // mint one NFT for the user
        vm.prank(simpleNFTOwner);
        uint256 firstTokenId = simpleNFTContract.mint(user);
        assertEq(0, firstTokenId);
        assertEq(user, simpleNFTContract.ownerOf(firstTokenId));

        vm.startPrank(user);

        // user has to approve the staking contract to operate on the NFT
        simpleNFTContract.approve(address(stakingContract), firstTokenId);
        assertEq(address(stakingContract), simpleNFTContract.getApproved(firstTokenId));

        // user stakes the first NFT
        vm.warp(1738700218); // set block timestamp
        stakingContract.stake(firstTokenId);
        assertEq(address(stakingContract), simpleNFTContract.ownerOf(firstTokenId));

        // check that transfering NFT token is not possible because it has been approved to the staking contract
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("ERC721InsufficientApproval(address,uint256)")), user, firstTokenId)
        );
        address newUser = address(0x22222);
        simpleNFTContract.safeTransferFrom(user, newUser, firstTokenId);

        // warp forward and then ask to unlock the NFT and distribute rewards for the user
        vm.warp(1738701218); // set new block timestamp, after 1000s
        // reward time window to get max reward = 7200s
        // total rewards = 0.1 ether * (1000 / 7200) = 10^17 wei * (1000 / 7200)
        stakingContract.getReward(firstTokenId);
        assertEq(user, simpleNFTContract.ownerOf(firstTokenId));

        // checking that user has received ERC20 reward tokens
        assertEq(13888888888888888, simpleTokenContract.balanceOf(user)); // 0.0138 ether

        // checking that balance of ERC20 tokens for staking contract has correctly updated
        uint256 initialBalance = 1000 * 10 ** simpleTokenContract.decimals();
        assertEq(initialBalance - uint256(13888888888888888), simpleTokenContract.balanceOf(address(stakingContract)));

        // checking that staking contract is no longer able to transfer ownership of user's NFT
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("ERC721IncorrectOwner(address,uint256,address)")),
                address(stakingContract),
                firstTokenId,
                user
            )
        );
        simpleNFTContract.safeTransferFrom(address(stakingContract), newUser, firstTokenId);

        vm.stopPrank();
    }
}
