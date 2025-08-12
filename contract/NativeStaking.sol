// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract NativeStaking {
    struct Stake {
        uint256 amount; 
        uint256 startTime; 
        uint256 lastClaimTime; 
        uint256 totalReward; 
        uint256 pendingReward; 
    }

    mapping(address => Stake) public stakes;
    
    // New mapping to track if an address has ever staked
    mapping(address => bool) public hasStaked;
    
    // New variable to count unique stakers
    uint256 public totalUniqueStakers;

    address public owner;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);

    //Default 4730 (4.73%)
    uint256 public rewardRate = 4730;
    uint256 public constant SCALE = 1e5; 

    uint256 public totalStaking; 

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    function setRewardRate(uint256 newRewardRate) external onlyOwner {
        require(newRewardRate >= 0, "Reward rate must be non-negative");
        rewardRate = newRewardRate;
    }

    function stake() external payable {
        require(msg.value > 0, "Amount should be greater than 0");

        Stake storage userStake = stakes[msg.sender];

        // Track new unique staker
        if (!hasStaked[msg.sender]) {
            hasStaked[msg.sender] = true;
            totalUniqueStakers++;
        }

        if (userStake.amount > 0) {
            uint256 reward = calculateReward(msg.sender);
            userStake.pendingReward += reward;
        }

        userStake.amount += msg.value;
        userStake.lastClaimTime = block.timestamp;

        if (userStake.startTime == 0) {
            userStake.startTime = block.timestamp;
        }

        totalStaking += msg.value;

        emit Staked(msg.sender, msg.value);
    }

    function unstake() external {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No active stake found");

        uint256 reward = calculateReward(msg.sender);
        userStake.pendingReward += reward;

        totalStaking -= userStake.amount;

        uint256 stakedAmount = userStake.amount;
        userStake.amount = 0;
        userStake.lastClaimTime = block.timestamp;

        (bool success, ) = msg.sender.call{value: stakedAmount}("");
        require(success, "Transfer failed");

        emit Unstaked(msg.sender, stakedAmount);
    }

    function unstakePartial(uint256 amount) external {
        require(amount > 0, "Amount should be greater than 0");
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount >= amount, "Insufficient staked amount");

        uint256 reward = calculateReward(msg.sender);
        userStake.pendingReward += reward;

        userStake.amount -= amount;
        userStake.lastClaimTime = block.timestamp;

        totalStaking -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit Unstaked(msg.sender, amount);
    }

    function claimReward() external {
        Stake storage userStake = stakes[msg.sender];

        uint256 reward = calculateReward(msg.sender);
        uint256 totalReward = userStake.pendingReward + reward;
        require(totalReward > 0, "No reward available");

        userStake.pendingReward = 0;
        userStake.lastClaimTime = block.timestamp;
        userStake.totalReward += totalReward;

        (bool success, ) = msg.sender.call{value: totalReward}("");
        require(success, "Transfer failed");

        emit RewardClaimed(msg.sender, totalReward);
    }

    function calculateReward(address user) public view returns (uint256) {
        Stake storage userStake = stakes[user];

        if (userStake.amount == 0) {
            return 0;
        }

        uint256 stakingTime = block.timestamp - userStake.lastClaimTime;
        uint256 reward = (userStake.amount * stakingTime * rewardRate) /
            (100 * (1 days) * SCALE); 

        return reward;
    }

    function getStakedAmount(address user) external view returns (uint256) {
        return stakes[user].amount;
    }

    function getTotalReward(address user) external view returns (uint256) {
        return stakes[user].totalReward;
    }

    function getPendingReward(address user) external view returns (uint256) {
        Stake storage userStake = stakes[user];
        uint256 reward = calculateReward(user);
        return userStake.pendingReward + reward;
    }

    function getTotalStaking() external view returns (uint256) {
        return totalStaking;
    }
    
    // New function to get total unique stakers
    function getTotalUniqueStakers() external view returns (uint256) {
        return totalUniqueStakers;
    }

    receive() external payable {}
}
