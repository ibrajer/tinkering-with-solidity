// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Build a simple and secure NFT staking system that lets users "lock up" their NFTs
// for a specified duration and distributes ERC20 token rewards dependent on length of duration.
contract StakingContract is Ownable, IERC721Receiver {
    event ConfigSet(uint256 timeWindow, uint256 timeWindowMaxReward);
    event StakedNFT(address indexed sender, uint256 indexed tokenId);
    event RewardDistributed(address indexed sender, uint256 indexed tokenId, uint256 rewardTokens);

    uint256 internal constant MIN_TIME_WINDOW_UNIT_SECS = 3600;
    uint256 internal constant MAX_TIME_WINDOW_REWARD = 1 ether;
    uint256 private timeWindowSecs;
    uint256 private timeWindowMaxReward;
    address private rewardTokenContractAddress;
    address private nftTokenContractAddress;
    mapping(uint256 tokenId => address owner) stakedTokens;
    mapping(uint256 tokenId => uint256 timestamp) stakedTimestamps;

    constructor(address _rewardTokenContractAddress, address _nftTokenContractAddress) Ownable(msg.sender) {
        require(_rewardTokenContractAddress != address(0), "reward token contract must not be zero address");
        require(_nftTokenContractAddress != address(0), "nft contract must not be zero address");
        rewardTokenContractAddress = _rewardTokenContractAddress;
        nftTokenContractAddress = _nftTokenContractAddress;

        // TODO ideally we want to check if these really are ERC-20 and ERC-721, maybe via ERC165 (supportsInterface)
    }

    function setConfig(uint256 _timeWindowSecs, uint256 _timeWindowMaxReward) external onlyOwner {
        require(_timeWindowSecs >= MIN_TIME_WINDOW_UNIT_SECS, "must stake for at least an hour");
        require(_timeWindowMaxReward > 0, "reward can't be zero");
        require(_timeWindowMaxReward <= MAX_TIME_WINDOW_REWARD, "time window reward must be less than 1 ether");
        timeWindowSecs = _timeWindowSecs;
        timeWindowMaxReward = _timeWindowMaxReward;

        emit ConfigSet(timeWindowSecs, timeWindowMaxReward);
    }

    function stake(uint256 tokenId) external {
        IERC721 nftTokenContract = IERC721(nftTokenContractAddress);
        require(msg.sender == nftTokenContract.ownerOf(tokenId), "sender does not own this token");

        stakedTokens[tokenId] = msg.sender;
        stakedTimestamps[tokenId] = block.timestamp;
        // lock token by sending it to the staking contract
        nftTokenContract.safeTransferFrom(msg.sender, address(this), tokenId);

        emit StakedNFT(msg.sender, tokenId);
    }

    function getReward(uint256 tokenId) external {
        address tokenOwner = stakedTokens[tokenId];
        require(tokenOwner != address(0), "token not staked or reward already distributed");
        require(msg.sender == tokenOwner, "sender does not match owner of the token");

        uint8 decimals = ERC20(rewardTokenContractAddress).decimals();
        uint256 timeDiff = block.timestamp - stakedTimestamps[tokenId];
        uint256 percentage = (timeDiff * 10 ** decimals) / timeWindowSecs;
        uint256 totalRewards = (timeWindowMaxReward * percentage) / (10 ** decimals);

        stakedTokens[tokenId] = address(0);
        stakedTimestamps[tokenId] = 0;

        IERC20 rewardToken = IERC20(rewardTokenContractAddress);
        SafeERC20.safeTransfer(rewardToken, tokenOwner, totalRewards);

        IERC721 nftTokenContract = IERC721(nftTokenContractAddress);
        nftTokenContract.safeTransferFrom(address(this), tokenOwner, tokenId);

        emit RewardDistributed(msg.sender, tokenId, totalRewards);
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4)
    {
        require(operator == address(this), "must come from this contract");
        return IERC721Receiver.onERC721Received.selector;
    }
}
