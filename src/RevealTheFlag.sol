// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract FlawedVault is ReentrancyGuard {
    ERC20 public sBTC; // Synthetic BTC token (8 decimals)
    address public swapRouter; // Mock swap router for simplicity
    uint256 public constant EXCHANGE_RATE = 1e10; // Intended: ETH (18 decimals) to sBTC (8 decimals)
    string private flag = "CTF{FlawedRatesForTheWin}";
    mapping(address => uint256) public mintedSBTC;

    event Minted(address indexed user, uint256 ethAmount, uint256 sBTCAmount);
    event FlagRevealed(address indexed winner, string flag);

    constructor(address _sBTC, address _swapRouter) {
        sBTC = ERC20(_sBTC);
        swapRouter = _swapRouter;
    }

    // Mint sBTC by depositing ETH
    function mint() external payable nonReentrant {
        require(msg.value > 0, "Must send ETH");

        // Flawed exchange rate: assumes 1 ETH = 1 sBTC in value terms
        uint256 sBTCAmount = msg.value / EXCHANGE_RATE; // ETH (18 decimals) to sBTC (8 decimals)
        require(sBTCAmount > 0, "Amount too small");

        mintedSBTC[msg.sender] += sBTCAmount;
        sBTC.transfer(msg.sender, sBTCAmount);

        emit Minted(msg.sender, msg.value, sBTCAmount);
    }

    // Swap sBTC for ETH via a mock router (simplified for CTF)
    function swap(uint256 sBTCAmount) external nonReentrant {
        require(sBTCAmount > 0, "Amount must be positive");
        require(sBTC.transferFrom(msg.sender, address(this), sBTCAmount), "Transfer failed");

        // Mock swap: 1 sBTC = 30 ETH (simulating real BTC/ETH rate)
        uint256 ethAmount = sBTCAmount * 30 * 1e10; // sBTC (8 decimals) to ETH (18 decimals)
        (bool success,) = msg.sender.call{value: ethAmount}("");
        require(success, "ETH transfer failed");
    }

    // Claim the flag if you've made a profit
    function claimFlag() external {
        uint256 profit = address(this).balance > 10 ether ? address(this).balance - 10 ether : 0;
        require(profit >= 10 ether, "Insufficient profit");
        emit FlagRevealed(msg.sender, flag);
    }

    // Allow funding the contract for swaps
    function fundContract() external payable {}

    receive() external payable {}
}

// Mock sBTC token for the CTF
contract SyntheticBTC is ERC20 {
    address public vault;

    constructor() ERC20("Synthetic BTC", "sBTC") {
        vault = msg.sender;
        _mint(msg.sender, 1000 * 10 ** 8); // 1000 sBTC with 8 decimals
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == vault, "Only vault can mint");
        _mint(to, amount);
    }
}
