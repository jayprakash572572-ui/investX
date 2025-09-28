// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title investX
 * @dev A decentralized investment platform allowing users to create investment pools,
 * contribute funds, and receive proportional returns
 */
contract investX {
    
    // State variables
    address public owner;
    uint256 public totalPools;
    uint256 public platformFeePercentage = 2; // 2% platform fee
    
    // Structs
    struct InvestmentPool {
        uint256 id;
        string name;
        address creator;
        uint256 targetAmount;
        uint256 currentAmount;
        uint256 minContribution;
        uint256 deadline;
        bool isActive;
        bool isCompleted;
        mapping(address => uint256) contributions;
        address[] contributors;
    }
    
    // Mappings
    mapping(uint256 => InvestmentPool) public investmentPools;
    mapping(address => uint256[]) public userPools;
    mapping(address => uint256) public userTotalInvestments;
    
    // Events
    event PoolCreated(uint256 indexed poolId, string name, address creator, uint256 targetAmount);
    event ContributionMade(uint256 indexed poolId, address contributor, uint256 amount);
    event PoolCompleted(uint256 indexed poolId, uint256 totalRaised);
    event FundsWithdrawn(uint256 indexed poolId, address creator, uint256 amount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier poolExists(uint256 _poolId) {
        require(_poolId > 0 && _poolId <= totalPools, "Pool does not exist");
        _;
    }
    
    modifier poolActive(uint256 _poolId) {
        require(investmentPools[_poolId].isActive, "Pool is not active");
        require(block.timestamp < investmentPools[_poolId].deadline, "Pool deadline passed");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        totalPools = 0;
    }
    
    /**
     * @dev Core Function 1: Create Investment Pool
     * @param _name Name of the investment pool
     * @param _targetAmount Target amount to raise (in wei)
     * @param _minContribution Minimum contribution amount
     * @param _durationInDays Duration of the pool in days
     */
    function createInvestmentPool(
        string memory _name,
        uint256 _targetAmount,
        uint256 _minContribution,
        uint256 _durationInDays
    ) external {
        require(_targetAmount > 0, "Target amount must be greater than 0");
        require(_minContribution > 0, "Minimum contribution must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        require(bytes(_name).length > 0, "Pool name cannot be empty");
        
        totalPools++;
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);
        
        InvestmentPool storage newPool = investmentPools[totalPools];
        newPool.id = totalPools;
        newPool.name = _name;
        newPool.creator = msg.sender;
        newPool.targetAmount = _targetAmount;
        newPool.currentAmount = 0;
        newPool.minContribution = _minContribution;
        newPool.deadline = deadline;
        newPool.isActive = true;
        newPool.isCompleted = false;
        
        userPools[msg.sender].push(totalPools);
        
        emit PoolCreated(totalPools, _name, msg.sender, _targetAmount);
    }
    
    /**
     * @dev Core Function 2: Contribute to Investment Pool
     * @param _poolId ID of the pool to contribute to
     */
    function contributeToPool(uint256 _poolId) 
        external 
        payable 
        poolExists(_poolId) 
        poolActive(_poolId) 
    {
        InvestmentPool storage pool = investmentPools[_poolId];
        
        require(msg.value >= pool.minContribution, "Contribution below minimum amount");
        require(pool.currentAmount + msg.value <= pool.targetAmount, "Contribution exceeds target");
        require(msg.sender != pool.creator, "Pool creator cannot contribute to own pool");
        
        // If this is the first contribution from this address, add to contributors array
        if (pool.contributions[msg.sender] == 0) {
            pool.contributors.push(msg.sender);
        }
        
        pool.contributions[msg.sender] += msg.value;
        pool.currentAmount += msg.value;
        userTotalInvestments[msg.sender] += msg.value;
        
        // Check if pool target is reached
        if (pool.currentAmount >= pool.targetAmount) {
            pool.isCompleted = true;
            pool.isActive = false;
            emit PoolCompleted(_poolId, pool.currentAmount);
        }
        
        emit ContributionMade(_poolId, msg.sender, msg.value);
    }
    
    /**
     * @dev Core Function 3: Withdraw Funds (for pool creators)
     * @param _poolId ID of the pool to withdraw from
     */
    function withdrawFunds(uint256 _poolId) 
        external 
        poolExists(_poolId) 
    {
        InvestmentPool storage pool = investmentPools[_poolId];
        
        require(msg.sender == pool.creator, "Only pool creator can withdraw");
        require(pool.isCompleted || block.timestamp >= pool.deadline, "Pool not ready for withdrawal");
        require(pool.currentAmount > 0, "No funds to withdraw");
        
        uint256 totalAmount = pool.currentAmount;
        uint256 platformFee = (totalAmount * platformFeePercentage) / 100;
        uint256 creatorAmount = totalAmount - platformFee;
        
        // Reset pool amount to prevent re-entrancy
        pool.currentAmount = 0;
        pool.isActive = false;
        
        // Transfer platform fee to owner
        if (platformFee > 0) {
            payable(owner).transfer(platformFee);
        }
        
        // Transfer remaining amount to pool creator
        payable(pool.creator).transfer(creatorAmount);
        
        emit FundsWithdrawn(_poolId, pool.creator, creatorAmount);
    }
    
    // View functions
    function getPoolDetails(uint256 _poolId) 
        external 
        view 
        poolExists(_poolId) 
        returns (
            string memory name,
            address creator,
            uint256 targetAmount,
            uint256 currentAmount,
            uint256 minContribution,
            uint256 deadline,
            bool isActive,
            bool isCompleted
        ) 
    {
        InvestmentPool storage pool = investmentPools[_poolId];
        return (
            pool.name,
            pool.creator,
            pool.targetAmount,
            pool.currentAmount,
            pool.minContribution,
            pool.deadline,
            pool.isActive,
            pool.isCompleted
        );
    }
    
    function getUserContribution(uint256 _poolId, address _user) 
        external 
        view 
        poolExists(_poolId) 
        returns (uint256) 
    {
        return investmentPools[_poolId].contributions[_user];
    }
    
    function getPoolContributors(uint256 _poolId) 
        external 
        view 
        poolExists(_poolId) 
        returns (address[] memory) 
    {
        return investmentPools[_poolId].contributors;
    }
    
    function getUserPools(address _user) external view returns (uint256[] memory) {
        return userPools[_user];
    }
    
    // Owner functions
    function updatePlatformFee(uint256 _newFeePercentage) external onlyOwner {
        require(_newFeePercentage <= 10, "Fee cannot exceed 10%");
        platformFeePercentage = _newFeePercentage;
    }
    
    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
