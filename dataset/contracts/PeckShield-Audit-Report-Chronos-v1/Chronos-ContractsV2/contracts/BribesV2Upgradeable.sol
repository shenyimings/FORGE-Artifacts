// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IMinter.sol";
import "./interfaces/IVoter.sol";
import "./interfaces/IVotingEscrow.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

interface IBribeFactoryImpl {
    function bribeOwner() external view returns (address owner);
}

contract BribesV2Upgradeable is ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    uint256 public constant WEEK = 7 days; // rewards are released over 7 days
    uint256 public firstBribeTimestamp;

    /* ========== STATE VARIABLES ========== */

    struct Reward {
        uint256 periodFinish;
        uint256 rewardsPerEpoch;
        uint256 lastUpdateTime; 
    }

    mapping(address => mapping(uint256 => Reward)) public rewardData;  // token -> startTimestamp -> Reward
    mapping(address => bool) public isRewardToken;
    address[] public rewardTokens;
    address public voter;
    address public bribeFactory;
    address public minter;
    address public ve;
    bool public _internal;

    string public TYPE;

    // owner -> reward token -> lastTime
    mapping(address => mapping(address => uint256)) public userRewardPerTokenPaid;
    mapping(address => mapping(address => uint256)) public userTimestamp;

    //uint256 private _totalSupply;
    mapping(uint256 => uint256) private _totalSupply;
    mapping(address => mapping(uint256 => uint256)) private _balances; //owner -> timestamp -> amount


    /* ========== CONSTRUCTOR ========== */


    constructor() {
        _disableInitializers();
    }

    function initialize(address _voter,address _bribeFactory, string memory _type, bool __internal) public initializer {
        __ReentrancyGuard_init();

        require(_bribeFactory != address(0) && _voter != address(0));
        voter = _voter;
        bribeFactory = _bribeFactory;
        firstBribeTimestamp = 0;
        ve = IVoter(_voter)._ve();
        minter = IVoter(_voter).minter();
        require(minter != address(0));
        TYPE = _type;
        _internal = __internal;
    }

    /// @notice get the current epoch 
    function getEpochStart() public view returns(uint256){
        return IMinter(minter).active_period();
    }

    /// @notice get next epoch (where bribes are saved)
    function getNextEpochStart() public view returns(uint256){
        return getEpochStart() + WEEK;
    }


    /* ========== VIEWS ========== */

    /// @notice get the length of the reward tokens
    function rewardsListLength() external view returns(uint256) {
        return rewardTokens.length;
    }
    
    /// @notice get the reward tokens list
    function rewardsList() external view returns(address[] memory) {
        return rewardTokens;
    }

    /// @notice get the last totalSupply (total votes for a pool)
    function totalSupply() external view returns (uint256) {
        uint256 _currentEpochStart = IMinter(minter).active_period(); // claim until current epoch
        return _totalSupply[_currentEpochStart];
    }

    /// @notice get a totalSupply given a timestamp
    function totalSupplyAt(uint256 _timestamp) external view returns (uint256) {
        return _totalSupply[_timestamp];
    }

    /// @notice read the balanceOf the tokenId at a given timestamp
    function balanceOfAt(uint256 tokenId, uint256 _timestamp) public view returns (uint256) {
        address _owner = IVotingEscrow(ve).ownerOf(tokenId);
        return _balances[_owner][_timestamp];
    }


    /// @notice get last deposit available given a tokenID
    function balanceOf(uint256 tokenId) public view returns (uint256) {
        uint256 _timestamp = getNextEpochStart();
        address _owner = IVotingEscrow(ve).ownerOf(tokenId);
        return _balances[_owner][_timestamp];
    }

    /// @notice get the balance of an owner in the current epoch
    function balanceOfOwner(address _owner) public view returns (uint256) {
        uint256 _timestamp = getNextEpochStart();
        return _balances[_owner][_timestamp];
    }

    /// @notice get the balance of an owner given a timestamp
    function balanceOfOwnerAt(address _owner, uint256 _timestamp) public view returns (uint256) {
        return _balances[_owner][_timestamp];
    }


    /// @notice Read earned amount given a tokenID and _rewardToken
    function earned(uint256 tokenId, address _rewardToken) public view returns(uint256){
        uint256 k = 0;
        uint256 reward = 0;
        uint256 _endTimestamp = IMinter(minter).active_period(); // claim until current epoch
        address _owner = IVotingEscrow(ve).ownerOf(tokenId);
        uint256 _userLastTime = userTimestamp[_owner][_rewardToken];
        
        if(_endTimestamp == _userLastTime){
            return 0;
        }

        // if user first time then set it to first bribe - week to avoid any timestamp problem
        if(_userLastTime < firstBribeTimestamp){
            _userLastTime = firstBribeTimestamp - WEEK;
        }

        for(k; k < 50; k++){
            if(_userLastTime == _endTimestamp){
                // if we reach the current epoch, exit
                break;
            }
            reward += _earned(_owner, _rewardToken, _userLastTime);
            _userLastTime += WEEK;   
                     
        }  
        return reward;  
    }

    /// @notice read earned amounts given an address and the reward token
    function earned(address _owner, address _rewardToken) public view returns(uint256){
        uint256 k = 0;
        uint256 reward = 0;
        uint256 _endTimestamp = IMinter(minter).active_period(); // claim until current epoch
        uint256 _userLastTime = userTimestamp[_owner][_rewardToken];
        
        if(_endTimestamp == _userLastTime){
            return 0;
        }

        // if user first time then set it to first bribe - week to avoid any timestamp problem
        if(_userLastTime < firstBribeTimestamp){
            _userLastTime = firstBribeTimestamp - WEEK;
        }

        for(k; k < 50; k++){
            if(_userLastTime == _endTimestamp){
                // if we reach the current epoch, exit
                break;
            }
            reward += _earned(_owner, _rewardToken, _userLastTime);
            _userLastTime += WEEK;   
                     
        }  
        return reward;  
    }

    /// @notice Read earned amount given address and reward token, returns the rewards and the last user timestamp (used in case user do not claim since 50+epochs)
    function earnedWithTimestamp(address _owner, address _rewardToken) private view returns(uint256,uint256){
        uint256 k = 0;
        uint256 reward = 0;
        uint256 _endTimestamp = IMinter(minter).active_period(); // claim until current epoch
        uint256 _userLastTime = userTimestamp[_owner][_rewardToken];
        
        
        // if user first time then set it to first bribe - week to avoid any timestamp problem
        if(_userLastTime < firstBribeTimestamp){
            _userLastTime = firstBribeTimestamp - WEEK;
        }

        for(k; k < 50; k++){
            if(_userLastTime == _endTimestamp){
                // if we reach the current epoch, exit
                break;
            }
            reward += _earned(_owner, _rewardToken, _userLastTime);
            _userLastTime += WEEK;   
                     
        }  
        return (reward, _userLastTime);  
    }

    /// @notice get the earned rewards
    function _earned(address _owner, address _rewardToken, uint256 _timestamp) internal view returns (uint256) {
        uint256 _balance = balanceOfOwnerAt(_owner, _timestamp);
        if(_balance == 0){
            return 0;
        } else {
            uint256 _rewardPerToken = rewardPerToken(_rewardToken, _timestamp);
            uint256 _rewards = _rewardPerToken * _balance / 1e18;
            return _rewards;
        }
    }

    /// @notice get the rewards for token
    function rewardPerToken(address _rewardsToken, uint256 _timestamp) public view returns (uint256) {
        if (_totalSupply[_timestamp] == 0) {
            return rewardData[_rewardsToken][_timestamp].rewardsPerEpoch;
        }
        return rewardData[_rewardsToken][_timestamp].rewardsPerEpoch * 1e18 / _totalSupply[_timestamp];
    }

 
    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice User votes deposit
    /// @dev    called on voter.vote() or voter.poke()
    ///         we save into owner "address" and not "tokenID". 
    ///         Owner must reset before transferring token
    function deposit(uint256 amount, uint256 tokenId) external nonReentrant {
        require(amount > 0, "Cannot stake 0");
        require(msg.sender == voter);
        uint256 _startTimestamp = IMinter(minter).active_period();
        uint256 _oldSupply = _totalSupply[_startTimestamp]; 
        address _owner = IVotingEscrow(ve).ownerOf(tokenId);
        uint256 _lastBalance = _balances[_owner][_startTimestamp]; 

        _totalSupply[_startTimestamp] =  _oldSupply + amount;
        _balances[_owner][_startTimestamp] = _lastBalance + amount;

        emit Staked(tokenId, amount);
    }

    /// @notice User votes withdrawal 
    /// @dev    called on voter.reset()
    function withdraw(uint256 amount, uint256 tokenId) external nonReentrant {
        require(amount > 0, "Cannot withdraw 0");
        require(msg.sender == voter);
        uint256 _startTimestamp = IMinter(minter).active_period(); 
        address _owner = IVotingEscrow(ve).ownerOf(tokenId);

        // incase of bribe contract reset in gauge proxy
        if (amount <= _balances[_owner][_startTimestamp]) {
            uint256 _oldSupply = _totalSupply[_startTimestamp]; 
            uint256 _oldBalance = _balances[_owner][_startTimestamp];
            _totalSupply[_startTimestamp] =  _oldSupply - amount;
            _balances[_owner][_startTimestamp] =  _oldBalance - amount;
            emit Withdrawn(tokenId, amount);
        }

    }

    /// @notice Claim the TOKENID rewards
    function getReward(uint256 tokenId, address[] memory tokens) external nonReentrant  {
        require(IVotingEscrow(ve).isApprovedOrOwner(msg.sender, tokenId));
        uint256 _userLastTime;
        uint256 reward = 0;
        address _owner = IVotingEscrow(ve).ownerOf(tokenId);
        
        for (uint256 i = 0; i < tokens.length; i++) {
            address _rewardToken = tokens[i];
            (reward, _userLastTime) = earnedWithTimestamp(_owner, _rewardToken);          
            if (reward > 0) {
                IERC20(_rewardToken).safeTransfer(_owner, reward);
                emit RewardPaid(_owner, _rewardToken, reward);
            }
            userTimestamp[_owner][_rewardToken] = _userLastTime;
        }
    }

    /// @notice Claim the rewards given msg.sender
    function getReward(address[] memory tokens) external nonReentrant  {
        uint256 _userLastTime;
        uint256 reward = 0;
        address _owner = msg.sender;
        
        for (uint256 i = 0; i < tokens.length; i++) {
            address _rewardToken = tokens[i];
            (reward, _userLastTime) = earnedWithTimestamp(_owner, _rewardToken);          
            if (reward > 0) {
                IERC20(_rewardToken).safeTransfer(_owner, reward);
                emit RewardPaid(_owner, _rewardToken, reward);
            }
            userTimestamp[_owner][_rewardToken] = _userLastTime;
        }
    }

    /// @notice Claim rewards from voter
    function getRewardForOwner(uint256 tokenId, address[] memory tokens) public nonReentrant  {
        require(msg.sender == voter);
        uint256 _userLastTime;
        uint256 reward = 0;
        address _owner = IVotingEscrow(ve).ownerOf(tokenId);

        for (uint256 i = 0; i < tokens.length; i++) {
            address _rewardToken = tokens[i];
            (reward, _userLastTime) = earnedWithTimestamp(_owner, _rewardToken);    
            if (reward > 0) {
                IERC20(_rewardToken).safeTransfer(_owner, reward);
                emit RewardPaid(_owner, _rewardToken, reward);
            }
            userTimestamp[_owner][_rewardToken] = _userLastTime;
        }
    }

    /// @notice Claim rewards from voter
    function getRewardForAddress(address _owner, address[] memory tokens) public nonReentrant  {
        require(msg.sender == voter);
        uint256 _userLastTime;
        uint256 reward = 0;

        for (uint256 i = 0; i < tokens.length; i++) {
            address _rewardToken = tokens[i];
            (reward, _userLastTime) = earnedWithTimestamp(_owner, _rewardToken);    
            if (reward > 0) {
                IERC20(_rewardToken).safeTransfer(_owner, reward);
                emit RewardPaid(_owner, _rewardToken, reward);
            }
            userTimestamp[_owner][_rewardToken] = _userLastTime;
        }
    }

    /// @notice Notify a bribe amount
    /// @dev    Rewards are saved into NEXT EPOCH mapping. 
    function notifyRewardAmount(address _rewardsToken, uint256 reward) external nonReentrant {
        /*if (__internal) {
            require( (msg.sender == owner || msg.sender == voter || IVoter(voter).isGauge(msg.sender) ), "permission is denied!" );
        }*/
        require(isRewardToken[_rewardsToken], "reward token not verified");
        IERC20(_rewardsToken).safeTransferFrom(msg.sender,address(this),reward);

        uint256 _startTimestamp = IMinter(minter).active_period(); //period points to the current thursday. Bribes are distributed from next epoch (thursday)
        if(firstBribeTimestamp == 0){
            firstBribeTimestamp = _startTimestamp;
        }

        uint256 _lastReward = rewardData[_rewardsToken][_startTimestamp].rewardsPerEpoch;
        
        rewardData[_rewardsToken][_startTimestamp].rewardsPerEpoch = _lastReward + reward;
        rewardData[_rewardsToken][_startTimestamp].lastUpdateTime = block.timestamp;
        rewardData[_rewardsToken][_startTimestamp].periodFinish = _startTimestamp + WEEK;

        emit RewardAdded(_rewardsToken, reward, _startTimestamp);
    }



    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice add rewards tokens
    function addRewardTokens(address[] memory _rewardsToken) public onlyAllowed {
        uint256 i = 0;
        for(i; i < _rewardsToken.length; i++){
           _addRewardToken(_rewardsToken[i]);
        }
    }

    /// @notice add a single reward token
    function addRewardToken(address _rewardsToken) public onlyAllowed {
        _addRewardToken(_rewardsToken);
    }
    function _addRewardToken(address _rewardsToken) internal {
        if(!isRewardToken[_rewardsToken]){
            isRewardToken[_rewardsToken] = true;
            rewardTokens.push(_rewardsToken);
        }
    }

    /// @notice Recover some ERC20 from the contract and updated given bribe
    function recoverERC20AndUpdateData(address tokenAddress, uint256 tokenAmount) external onlyAllowed {
        require(tokenAmount <= IERC20(tokenAddress).balanceOf(address(this)));
        
        uint256 _startTimestamp = IMinter(minter).active_period();
        uint256 _lastReward = rewardData[tokenAddress][_startTimestamp].rewardsPerEpoch;
        rewardData[tokenAddress][_startTimestamp].rewardsPerEpoch = _lastReward - tokenAmount;
        rewardData[tokenAddress][_startTimestamp].lastUpdateTime = block.timestamp;


        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    /// @notice Recover some ERC20 from the contract.
    /// @dev    Be careful --> if called then getReward() at last epoch will fail because some reward are missing! 
    ///         Think about calling recoverERC20AndUpdateData()
    function emergencyRecoverERC20(address tokenAddress, uint256 tokenAmount) external onlyAllowed {
        require(tokenAmount <= IERC20(tokenAddress).balanceOf(address(this)));
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    /// @notice Set a new voter
    function setVoter(address _Voter) external onlyAllowed {
        require(_Voter != address(0));
        voter = _Voter;
    }

    /// @notice Set a new minter
    function setMinter(address _minter) external onlyAllowed {
        require(_minter != address(0));
        minter = _minter;
    }

    /// @notice Get the current BribeOwner
    function owner() public view returns (address) {
        return IBribeFactoryImpl(bribeFactory).bribeOwner();
    }



    /* ========== MODIFIERS ========== */

    modifier onlyAllowed() {
        require( (msg.sender == owner() || msg.sender == bribeFactory), "permission is denied!" );
        _;
    }


    /* ========== EVENTS ========== */

    event RewardAdded(address indexed rewardToken, uint256 reward, uint256 startTimestamp);
    event Staked(uint256 indexed tokenId, uint256 amount);
    event Withdrawn(uint256 indexed tokenId, uint256 amount);
    event RewardPaid(address indexed user,address indexed rewardsToken,uint256 reward);
    event Recovered(address indexed token, uint256 amount);
}