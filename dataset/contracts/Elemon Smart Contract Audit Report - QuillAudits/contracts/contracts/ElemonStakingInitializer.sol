// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/Address.sol";
import "./utils/Ownable.sol";
import "./utils/ReentrancyGuard.sol";
import "./interfaces/IERC20Metadata.sol";
import "./interfaces/IERC721.sol";
import "./interfaces/IElemonInfo.sol";
import "./interfaces/IERC721Receiver.sol";

contract ElemonStakingInitializer is Ownable, ReentrancyGuard, IERC721Receiver {
    // The address of the smart chef factory
    address public SMART_CHEF_FACTORY;

    // Whether a limit is set for users
    bool public hasUserLimit;

    // Whether it is initialized
    bool public isInitialized;

    // Accrued token per share
    uint256 public accTokenPerShare;

    // The block number when CAKE mining ends.
    uint256 public bonusEndBlock;

    // The block number when CAKE mining starts.
    uint256 public startBlock;

    // The block number of the last pool update
    uint256 public lastRewardBlock;

    // The pool limit (0 if none)
    uint256 public poolLimitPerUser;

    // CAKE tokens created per block.
    uint256 public rewardPerBlock;

    // The precision factor
    uint256 public PRECISION_FACTOR;

    // The reward token
    IERC20Metadata public rewardToken;

    // The staked token
    IERC20Metadata public stakedToken;

    uint256 public _totalStaked;
    uint256 public _totalAllocation;

    // Info of each user that stakes tokens (stakedToken)
    mapping(address => UserInfo) public userInfo;

    IERC721 public _elemonNFT;
    IElemonInfo public _elemonInfo;

    mapping(uint256 => uint256) public _boostBonusPercents;     //Multipled by 1000

    struct UserInfo {
        uint256 stakedAmount;  // How many staked tokens the user has provided
        uint256 allocation;     //User allocation with boost included
        uint256 rewardDebt; // Reward debt,
        uint256 boostTokenId;
        uint256 boostPercent;
    }

    event AdminTokenRecovery(address tokenRecovered, uint256 amount);
    event Deposit(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event NewStartAndEndBlocks(uint256 startBlock, uint256 endBlock);
    event NewRewardPerBlock(uint256 rewardPerBlock);
    event NewPoolLimit(uint256 poolLimitPerUser);
    event RewardsStop(uint256 blockNumber);
    event Withdraw(address indexed user, uint256 amount);
    event Boosted(address indexed user, uint256 tokenId);
    event Unboosted(address indexed user);

    constructor(address elemonNftAddress, address elemonInfoAddress) {
        SMART_CHEF_FACTORY = _msgSender();
        _elemonNFT = IERC721(elemonNftAddress);
        _elemonInfo = IElemonInfo(elemonInfoAddress);
        _boostBonusPercents[1] = 2000;
        _boostBonusPercents[2] = 2500;
        _boostBonusPercents[3] = 3000;
        _boostBonusPercents[4] = 3500;
        _boostBonusPercents[5] = 4000;
    }

    function initialize(
        IERC20Metadata _stakedToken,
        IERC20Metadata _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock,
        uint256 _poolLimitPerUser,
        address _admin
    ) external {
        require(!isInitialized, "Already initialized");
        require(_msgSender() == SMART_CHEF_FACTORY, "Not factory");

        // Make this contract initialized
        isInitialized = true;

        stakedToken = _stakedToken;
        rewardToken = _rewardToken;
        rewardPerBlock = _rewardPerBlock;
        startBlock = _startBlock;
        bonusEndBlock = _bonusEndBlock;

        if (_poolLimitPerUser > 0) {
            hasUserLimit = true;
            poolLimitPerUser = _poolLimitPerUser;
        }

        uint256 decimalsRewardToken = uint256(rewardToken.decimals());
        require(decimalsRewardToken < 30, "Must be inferior to 30");

        PRECISION_FACTOR = uint256(10**(uint256(30) - decimalsRewardToken));

        // Set the lastRewardBlock as the startBlock
        lastRewardBlock = startBlock;

        // Transfer ownership to the admin address who becomes owner of the contract
        transferOwnership(_admin);
    }

    function deposit(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[_msgSender()];

        if (hasUserLimit) {
            require(_amount + user.stakedAmount <= poolLimitPerUser, "User amount above limit");
        }

        _updatePool();

        if (user.allocation > 0) {
            uint256 pending = _totalStaked * (user.allocation * accTokenPerShare / PRECISION_FACTOR - user.rewardDebt) / _totalAllocation;
            if (pending > 0) {
                rewardToken.transfer(address(_msgSender()), pending);
            }
        }

        if (_amount > 0) {
            user.stakedAmount += _amount;
            _totalAllocation -= user.allocation;
            user.allocation = user.stakedAmount + _getBonusAmount(user.stakedAmount, user.boostPercent);
            stakedToken.transferFrom(address(_msgSender()), address(this), _amount);
            _totalAllocation += user.allocation;
            _totalStaked += _amount;
        }

        user.rewardDebt = user.allocation * accTokenPerShare / PRECISION_FACTOR;

        emit Deposit(_msgSender(), _amount);
    }

    function boost(uint256 tokenId) external nonReentrant{
        UserInfo storage user = userInfo[_msgSender()];
        require(user.boostPercent == 0, "Have used boost before");
        uint256 rarity = _elemonInfo.getRarity(tokenId);
        require(rarity > 0, "Invalid rarity");

        //Transfer NFT to contract
        _elemonNFT.safeTransferFrom(_msgSender(), address(this), tokenId);

        _updatePool();

        _totalAllocation -= user.allocation;

        user.boostPercent = _boostBonusPercents[rarity];
        user.allocation = user.stakedAmount + _getBonusAmount(user.stakedAmount, user.boostPercent);
        user.boostTokenId = tokenId;

        _totalAllocation += user.allocation;

        emit Boosted(_msgSender(), tokenId);
    }

    function unboost() external nonReentrant{
        UserInfo storage user = userInfo[_msgSender()];
        require(user.boostPercent > 0, "Have used boost before");

        _updatePool();

        //Transfer NFT to user
        _elemonNFT.safeTransferFrom(address(this), _msgSender(), user.boostTokenId);

        _totalAllocation -= user.allocation;
        user.allocation = user.stakedAmount;
        user.boostPercent = 0;
        user.boostTokenId = 0;
        _totalAllocation += user.allocation;

        emit Unboosted(_msgSender());
    }

    function withdraw(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[_msgSender()];
        require(user.allocation >= _amount, "Amount to withdraw too high");

        _updatePool();

        uint256 pending = _totalStaked * (user.allocation * accTokenPerShare / PRECISION_FACTOR - user.rewardDebt) / _totalAllocation;

        if (_amount > 0) {
            user.stakedAmount -= _amount;
            _totalAllocation -= user.allocation;
            user.allocation = user.stakedAmount + _getBonusAmount(user.stakedAmount, user.boostPercent);
            stakedToken.transfer(address(_msgSender()), _amount);
            _totalAllocation += user.allocation;
            _totalStaked -= _amount;
        }

        if (pending > 0) {
            rewardToken.transfer(address(_msgSender()), pending);
        }

        user.rewardDebt = user.allocation * accTokenPerShare / PRECISION_FACTOR;

        emit Withdraw(_msgSender(), _amount);
    }

    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = userInfo[_msgSender()];

        _totalAllocation -= user.allocation;
        _totalStaked -= user.stakedAmount;

        uint256 amountToTransfer = user.stakedAmount;

        user.stakedAmount = 0;
        user.allocation = 0;
        user.rewardDebt = 0;
        user.boostPercent = 0;

        if (amountToTransfer > 0) {
            stakedToken.transfer(address(_msgSender()), amountToTransfer);
        }

        if(user.boostTokenId > 0){
            _elemonNFT.safeTransferFrom(address(this), _msgSender(), user.boostTokenId);
        }

        user.boostTokenId = 0;

        emit EmergencyWithdraw(_msgSender(), user.allocation);
    }

    function emergencyRewardWithdraw(uint256 _amount) external onlyOwner {
        rewardToken.transfer(address(_msgSender()), _amount);
    }

    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        require(_tokenAddress != address(stakedToken), "Cannot be staked token");
        require(_tokenAddress != address(rewardToken), "Cannot be reward token");

        IERC20(_tokenAddress).transfer(address(_msgSender()), _tokenAmount);

        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    function stopReward() external onlyOwner {
        bonusEndBlock = block.number;
    }

    function setElemonNFT(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Zero address");
        _elemonNFT = IERC721(newAddress);
    }

    function setElemonInfo(address newAddress) external onlyOwner{
        require(newAddress != address(0), "Zero address");
        _elemonInfo = IElemonInfo(newAddress);
    }

    function setBoostBonusPercents(uint256 level, uint256 percent) external onlyOwner{
        require(level > 0 && percent > 0, "Zero input");
        _boostBonusPercents[level] = percent;
    }

    function updatePoolLimitPerUser(bool _hasUserLimit, uint256 _poolLimitPerUser) external onlyOwner {
        require(hasUserLimit, "Must be set");
        if (_hasUserLimit) {
            require(_poolLimitPerUser > poolLimitPerUser, "New limit must be higher");
            poolLimitPerUser = _poolLimitPerUser;
        } else {
            hasUserLimit = _hasUserLimit;
            poolLimitPerUser = 0;
        }
        emit NewPoolLimit(poolLimitPerUser);
    }

    function updateRewardPerBlock(uint256 _rewardPerBlock) external onlyOwner {
        require(block.number < startBlock, "Pool has started");
        rewardPerBlock = _rewardPerBlock;
        emit NewRewardPerBlock(_rewardPerBlock);
    }

    function updateStartAndEndBlocks(uint256 _startBlock, uint256 _bonusEndBlock) external onlyOwner {
        require(block.number < startBlock, "Pool has started");
        require(_startBlock < _bonusEndBlock, "New startBlock must be lower than new endBlock");
        require(block.number < _startBlock, "New startBlock must be higher than current block");

        startBlock = _startBlock;
        bonusEndBlock = _bonusEndBlock;

        // Set the lastRewardBlock as the startBlock
        lastRewardBlock = startBlock;

        emit NewStartAndEndBlocks(_startBlock, _bonusEndBlock);
    }

    function pendingReward(address _user) external view returns (uint256) {
        if(_totalAllocation == 0)
            return 0;
        UserInfo storage user = userInfo[_user];
        if (block.number > lastRewardBlock && _totalStaked != 0) {
            uint256 multiplier = _getMultiplier(lastRewardBlock, block.number);
            uint256 earnedTokenReward = multiplier * rewardPerBlock;
            uint256 adjustedTokenPerShare =
                accTokenPerShare + (earnedTokenReward * PRECISION_FACTOR / _totalAllocation);
            return _totalStaked *  (user.allocation * adjustedTokenPerShare / PRECISION_FACTOR - user.rewardDebt) / _totalAllocation;
        } else {
            return _totalStaked * (user.allocation * accTokenPerShare / PRECISION_FACTOR - user.rewardDebt) / _totalAllocation;
        }
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external view override returns (bytes4){
        return bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }

    /*
     * @notice Update reward variables of the given pool to be up-to-date.
     */
    function _updatePool() internal {
        if (block.number <= lastRewardBlock) {
            return;
        }

        if (_totalAllocation == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = _getMultiplier(lastRewardBlock, block.number);
        uint256 earnedTokenReward = multiplier * rewardPerBlock;
        accTokenPerShare = accTokenPerShare + earnedTokenReward * PRECISION_FACTOR / _totalAllocation;
        lastRewardBlock = block.number;
    }

    function _getMultiplier(uint256 _from, uint256 _to) internal view returns (uint256) {
        if (_to <= bonusEndBlock) {
            return _to - _from;
        } else if (_from >= bonusEndBlock) {
            return 0;
        } else {
            return bonusEndBlock - _from;
        }
    }

    function _getBonusAmount(uint256 amount, uint256 percent) internal pure returns(uint256){
        return amount * percent / 100 / 1000;
    }
}