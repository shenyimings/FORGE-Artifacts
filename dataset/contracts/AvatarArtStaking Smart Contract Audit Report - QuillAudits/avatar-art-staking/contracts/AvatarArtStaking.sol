// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IAvatarArtStaking.sol";
import "./interfaces/IERC20.sol";
import "./core/Runnable.sol";

contract AvatarArtStaking is IAvatarArtStaking, Runnable{
    struct LockStage{
        uint duration;
        uint minAmount;
        uint annualProfit;
        bool isActive;
    }
    
    struct TransactionHistory{
        uint time;
        uint amount;
    }
    
    address internal _bnuTokenAddress;
    uint internal _stopTime;
    
    //Store all BNU token amount that is staked in contract
    uint internal _totalStakedAmount;
    uint public constant MULTIPLIER = 1000;
    uint public constant ONE_YEAR = 365 days;
    
    //Store all BNU token amount that is staked by user
    //Mapping LockStage index => user account => token amount
    mapping(uint => mapping(address => uint)) internal _userStakeds;
    
    //Store all earned BNU token amount that will be reward for user when he stakes
    //Mapping user account => token amount
    mapping(address => uint) internal _userEarneds;
    
    //Store the last time user received reward
    //Mapping stage index => user account => time
    mapping(uint => mapping(address => uint)) internal _userLastEarnedTimes;
    
    //Store the last time user staked
    //Mapping stage index => user account => time
    mapping(uint => mapping(address => uint)) internal _userLastStakingTimes;
    
    //Store user's staking histories
    //Mapping nft stage index =>  user account => Staking history
    mapping(uint => mapping(address => TransactionHistory[])) internal _stakingHistories;
    
    //Store user's withdrawal histories
    //Mapping nft stage index => user account => withdrawal history
    mapping(uint => mapping(address => TransactionHistory[])) internal _withdrawHistories;
    
    //List of staking users from staking LockStage
    //Mapping: _lockStages index => user address
    mapping(uint => address[]) internal _stakingUsers;
    
    //NFT
    //Store to check whether NFT is running or not
    LockStage[] internal _lockStages;
    
    constructor(address bnuTokenAddress){
        _bnuTokenAddress = bnuTokenAddress;
    }
    
    /**
     * @dev Create new Lock stage
    */ 
    function createLockStage(uint duration, uint minAmount, uint annualProfit) external onlyOwner{
        require(duration > 0, "Duration is zero");
        _lockStages.push(LockStage(duration, minAmount, annualProfit, true));
    }
    
    /**
     * @dev Get annual profit of `lockStage` by index
    */
    function getAnnualProfit(uint lockStageIndex) external override view returns(uint){
        require(lockStageIndex < _lockStages.length, "Out of length");
        return _lockStages[lockStageIndex].annualProfit;
    }
    
    /**
     * @dev Get BNU token address
    */
    function getBnuTokenAddress() external view returns(address){
        return _bnuTokenAddress;
    }

    /**
    * @dev Get lock stage information by index
    */
    function getLockStage(uint lockStageIndex) external view returns(LockStage memory){
        require(lockStageIndex < _lockStages.length, "Out of length");
        return _lockStages[lockStageIndex];
    }
    
    function getLockStages() external view returns(LockStage[] memory){
        return _lockStages;
    }
    
    function getStopTime() external view returns(uint){
        return _stopTime;
    }
    
    /**
     * @dev Get total BNU token amount staked in contract
     */ 
    function getTotalStaked() external override view returns(uint){
        return _totalStakedAmount;
    }
    
    /**
     * @dev Get user's BNU earned
     * It includes stored interest and pending interest
     */ 
    function getUserEarnedAmount(address account) external override view returns(uint){
        uint earnedAmount = _userEarneds[account];
        
        //Calculate pending amount
        for(uint lockStageIndex = 0; lockStageIndex < _lockStages.length; lockStageIndex ++){
            LockStage memory lockStage = _lockStages[lockStageIndex];
            if(lockStage.isActive){
                uint userStakedAmount = _userStakeds[lockStageIndex][account];
                if(userStakedAmount > 0){
                    earnedAmount += _calculatePendingEarned(lockStageIndex, userStakedAmount, _getUserRewardPendingTime(lockStageIndex, account));
                }
            }
        }
        
        return earnedAmount;
    }
    
    /**
     * @dev Get list of users who are staking
     */ 
    function getStakingUsers(uint lockStageIndex) external override view returns(address[] memory){
        return _stakingUsers[lockStageIndex];
    }
    
    /**
     * @dev Get staking histories of `account`
     */ 
    function getStakingHistories(uint lockStageIndex, address account) external view returns(TransactionHistory[] memory){
        return _stakingHistories[lockStageIndex][account];
    }
    
    function getUserLastEarnedTime(uint lockStageIndex, address account) external view returns(uint){
        return _getUserLastEarnedTime(lockStageIndex, account);
    }
    
    function getUserLastStakingTime(uint lockStageIndex, address account) external view returns(uint){
        return _getUserLastStakingTime(lockStageIndex, account);
    }
    
    function getUserRewardPendingTime(uint lockStageIndex, address account) external view returns(uint){
        return _getUserRewardPendingTime(lockStageIndex, account);
    }
    
    /**
     * @dev Get total BNU token amount staked by `account`
     */ 
    function getUserStakedAmount(uint lockStageIndex, address account) external override view returns(uint){
        return _getUserStakedAmount(lockStageIndex, account);
    }
    
    /**
     * @dev Get withdrawal histories of `account`
     */ 
    function getWithdrawalHistories(uint lockStageIndex, address account) external view returns(TransactionHistory[] memory){
        return _withdrawHistories[lockStageIndex][account];
    }
    
    /**
     * @dev Remove Lock stage from data
     */ 
    function setLockStage(uint index, uint duration, uint minAmount) external onlyOwner returns(bool){
        uint lockStageLength = _lockStages.length;
        require(index < lockStageLength, "Index is invalid");
        
        _lockStages[index].duration = duration;
        _lockStages[index].minAmount = minAmount;
        
        return true;
    }
    
    /**
     * @dev Remove Lock stage from data
     */ 
    function setLockStageActiveStatus(uint lockStageIndex, bool isActive) external onlyOwner returns(bool){
        require(lockStageIndex < _lockStages.length, "Index is invalid");
        require(_lockStages[lockStageIndex].isActive != isActive, "Status is the same");
        
        if(!isActive){
            for(uint userIndex = 0; userIndex < _stakingUsers[lockStageIndex].length; userIndex++){
                _calculateInterest(_stakingUsers[lockStageIndex][userIndex]);
            }
        }else{
            for(uint userIndex = 0; userIndex < _stakingUsers[lockStageIndex].length; userIndex++){
                _userLastEarnedTimes[lockStageIndex][_stakingUsers[lockStageIndex][userIndex]] = _now();
            }
        }
        
        _lockStages[lockStageIndex].isActive = isActive;
        
        return true;
    }
    
    /**
     * @dev Set BNU token address
    */
    function setBnuTokenAddress(address tokenAddress) external onlyOwner{
        require(tokenAddress != address(0), "Zero address");
        _bnuTokenAddress = tokenAddress;
    }
    
    /**
     * @dev Set APR
     * Before set APR with new value, contract should process to calculate all current users' profit 
     * to reset interest
    */
    function setAnnualProfit(uint lockStageIndex, uint annualProfit) external onlyOwner{
        require(lockStageIndex < _lockStages.length, "Out of length");
        for(uint userIndex = 0; userIndex < _stakingUsers[lockStageIndex].length; userIndex++){
            _calculateInterest(_stakingUsers[lockStageIndex][userIndex]);
        }
        _lockStages[lockStageIndex].annualProfit = annualProfit;
    }
    
    /**
     * @dev See IAvatarArtStaking
     */ 
    function stake(uint lockStageIndex, uint amount) external override isRunning returns(bool){
        //CHECK REQUIREMENTS
        require(lockStageIndex < _lockStages.length, "Out of length");
        require(amount > 0, "Amount should be greater than zero");
        
        //Check for minimum staking amount
        LockStage memory lockStage = _lockStages[lockStageIndex];
        require(lockStage.isActive, "This staking stage is inactive");
        if(lockStage.minAmount > 0){
            require(_userStakeds[lockStageIndex][_msgSender()] + amount >= lockStage.minAmount, "Not enough mininum amount to stake");
        }
        
        //Transfer token from user address to contract
        require(IERC20(_bnuTokenAddress).transferFrom(_msgSender(), address(this), amount), "Can not transfer token to contract");
        
        //Calculate interest and store with extra interest
        _calculateInterest(_msgSender());
        
        //Create staking history
        TransactionHistory[] storage stakingHistories = _stakingHistories[lockStageIndex][_msgSender()];
        stakingHistories.push(TransactionHistory(_now(), amount));
        
        //Update user staked amount and contract staked amount
        _userStakeds[lockStageIndex][_msgSender()] += amount;
        _totalStakedAmount += amount;
        
        if(!_isUserStaked(lockStageIndex, _msgSender()))
            _stakingUsers[lockStageIndex].push(_msgSender());
        
        //Store the last time user staked
        _userLastStakingTimes[lockStageIndex][_msgSender()] = _now();
        
        //Emit events
        emit Staked(lockStageIndex, _msgSender(), amount);
        
        return true;
    }
    
    /**
     * @dev Stop staking program
     */ 
    function stop() external onlyOwner{
        _isRunning = false;
        _stopTime = _now();

        IERC20 bnuTokenContract = IERC20(_bnuTokenAddress);
        if(bnuTokenContract.balanceOf(address(this)) > _totalStakedAmount)
            bnuTokenContract.transfer(_owner, bnuTokenContract.balanceOf(address(this)) - _totalStakedAmount);
        
        emit Stopped(_now());
    }
    
    /**
     * @dev Withdraw staked amount in lockStage by index and pay earned token
     * If withdraw amount = 0; only pay earned token
     */ 
    function withdraw(uint lockStageIndex, uint amount) external override returns(bool){
        require(lockStageIndex < _lockStages.length, "Out of length");
        if(amount > 0){
            require(amount <= _getUserStakedAmount(lockStageIndex, _msgSender()), "Amount is invalid");
        }
        //Calculate interest and store with extra interest
        _calculateInterest(_msgSender());
        
        IERC20 bnuTokenContract = IERC20(_bnuTokenAddress);
        
        //Calculate to withdraw staked amount
        if(amount > 0){
            uint lastStakingTime = _getUserLastStakingTime(lockStageIndex, _msgSender());
            if(lastStakingTime + _lockStages[lockStageIndex].duration < _now()){
                _userStakeds[lockStageIndex][_msgSender()] -= amount;    //Do not need to check `amount` <= user staked
                _totalStakedAmount -= amount;
                
                require(bnuTokenContract.transfer(_msgSender(), amount), "Can not pay staked amount for user");
            }
        }
        
        uint eanedAmount = _userEarneds[_msgSender()];
        
        //Pay all interest
        if(eanedAmount > 0){
            //Make sure that user can withdraw all their staked amount
            if(bnuTokenContract.balanceOf(address(this)) - _totalStakedAmount >= eanedAmount){
                require(bnuTokenContract.transfer(_msgSender(), eanedAmount), "Can not pay interest for user");
                _userEarneds[_msgSender()] = 0;
            }
        }
        
        if(amount > 0)
            _withdrawHistories[lockStageIndex][_msgSender()].push(TransactionHistory(_now(), amount));
        
        //Emit events 
        emit Withdrawn(lockStageIndex, _msgSender(), amount);
        
        return true;
    }
    
    /**
     * @dev Calculate and update user pending interest
     */ 
    function _calculateInterest(address account) internal{
        for(uint lockStageIndex = 0; lockStageIndex < _lockStages.length; lockStageIndex++){
            LockStage memory lockStage = _lockStages[lockStageIndex];
            if(lockStage.isActive){
                uint userStakedAmount = _userStakeds[lockStageIndex][account];
                if(userStakedAmount > 0){
                    uint earnedAmount = _calculatePendingEarned(lockStageIndex, userStakedAmount, _getUserRewardPendingTime(lockStageIndex, account));
                    _userEarneds[account] += earnedAmount;
                }
                _userLastEarnedTimes[lockStageIndex][account] = _now();
            }
        }
    }
    
    /**
     * @dev Calculate interest for user from `lastStakingTime` to  `now`
     * based on user staked amount and annualProfit
     */ 
    function _calculatePendingEarned(uint lockStageIndex, uint userStakedAmount, uint pendingTime) internal view returns(uint){
        return userStakedAmount * pendingTime * _lockStages[lockStageIndex].annualProfit / MULTIPLIER / ONE_YEAR / 100;
    }
    
    /**
     * @dev Check user has staked or not
     */
    function _isUserStaked(uint lockStageIndex, address account) internal view returns(bool){
        for(uint index = 0; index < _stakingUsers[lockStageIndex].length; index++){
            if(_stakingUsers[lockStageIndex][index] == account)
                return true;
        }
        
        return false;
    }
    
    function _getUserLastEarnedTime(uint lockStageIndex, address account) internal view returns(uint){
        return _userLastEarnedTimes[lockStageIndex][account];
    }
    
    function _getUserLastStakingTime(uint lockStageIndex, address account) internal view returns(uint){
        return _userLastStakingTimes[lockStageIndex][account];
    }
    
    function _getUserRewardPendingTime(uint lockStageIndex, address account) internal view returns(uint){
        if(!_isRunning && _stopTime > 0)
            return _stopTime - _getUserLastEarnedTime(lockStageIndex, account);
        return _now() - _getUserLastEarnedTime(lockStageIndex, account);
    }

    function _getUserStakedAmount(uint lockStageIndex, address account) internal view returns(uint){
        return _userStakeds[lockStageIndex][account];
    }
    
    event Staked(uint lockStageIndex, address account, uint amount);
    event Withdrawn(uint lockStageIndex, address account, uint amount);
    event Stopped(uint time);
}