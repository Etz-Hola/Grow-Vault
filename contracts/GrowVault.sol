// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract GrowVault {
    address public owner;              // The person who created this piggy bank
    string public savingPurpose;       // Purpose of this piggy bank
    uint256 public savingDuration;     // Duration in seconds (e.g., 30 days = 30 * 24 * 60 * 60)
    uint256 public startTime;          // When the piggy bank was created
    address public developer;          // Address to receive penalty fees
    bool public isWithdrawn;           // Tracks if funds have been withdrawn
    mapping(address => uint256) public balances;  // Balances for each token (USDT, USDC, DAI)

    // Hardcoded token addresses (replace with actual mainnet addresses if deploying)
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    // Events for tracking actions
    event Deposited(address indexed token, uint256 amount);
    event Withdrawn(address indexed token, uint256 amount, bool early);

    // Modifier to check if the contract is still active
    modifier onlyActive() {
        require(!isWithdrawn, "Vault is already withdrawn");
        _;
    }

    // Modifier to restrict to owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    // Constructor: Set up the vault
    constructor(string memory _savingPurpose, uint256 _duration, address _developer) {
        owner = msg.sender;
        savingPurpose = _savingPurpose;
        savingDuration = _duration;
        startTime = block.timestamp;
        developer = _developer;
        isWithdrawn = false;
    }

    // Deposit tokens (USDT, USDC, DAI only)
    function deposit(address token, uint256 amount) external onlyActive {
        require(
            token == USDT || token == USDC || token == DAI,
            "Only USDT, USDC, or DAI allowed"
        );
        require(amount > 0, "Amount must be greater than 0");

        // Transfer tokens from sender to this contract
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        balances[token] += amount;

        emit Deposited(token, amount);
    }

    // Withdraw tokens (after duration or early with penalty)
    function withdraw(address token) external onlyOwner onlyActive {
        require(balances[token] > 0, "No balance to withdraw");
        uint256 amount = balances[token];
        balances[token] = 0;  // Reset balance before transfer (security practice)
        isWithdrawn = true;   // Halt functionalities after withdrawal

        bool isEarly = block.timestamp < startTime + savingDuration;
        if (isEarly) {
            // Early withdrawal: 15% penalty to developer
            uint256 penalty = (amount * 15) / 100;
            uint256 amountToOwner = amount - penalty;

            IERC20(token).transfer(developer, penalty);
            IERC20(token).transfer(owner, amountToOwner);
        } else {
            // Full withdrawal after duration
            IERC20(token).transfer(owner, amount);
        }

        emit Withdrawn(token, amount, isEarly);
    }

    // Check balance of a specific token
    function getBalance(address token) external view returns (uint256) {
        return balances[token];
    }

    // Check if duration has been reached
    function isDurationReached() external view returns (bool) {
        return block.timestamp >= startTime + savingDuration;
    }
}