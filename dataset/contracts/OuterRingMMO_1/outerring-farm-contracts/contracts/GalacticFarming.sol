// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./interfaces/IResource.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract GalacticFarming is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IResource;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of Resources
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accResourcePerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accResourcePerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    struct PoolInfo {
        IERC20Upgradeable lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. Resources to distribute per block.
        uint256 lastRewardBlock; // Last block number that Resources distribution occurs.
        uint256 accResourcePerShare; // Accumulated Resources per share, times 1e12. See below.
    }

    // Interface for resource token
    IResource public resource;
    // Reward per block in resource token
    uint256 public resourcePerBlock;
    // Bonus multiplier 
    uint256 BONUS_MULTIPLIER;

    // Pool data
    PoolInfo[] public poolInfo;

    // User info by stake
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // LP tokens added to the pool
    mapping(address => bool) public addedPools;
    // LP tokens position by address
    mapping(address => uint256) public positionPoolsByLP;

    // Number that determines the total allocation points
    uint256 public totalAllocPoint;
    // Block to set the reward start block
    uint256 public startBlock;

    /***************************
     * Events
     ***************************/
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    /// @notice Constructor of the contract
    constructor() initializer {}

    /// @notice Initialize function for the proxy contract
    /// @param _resource Token to reward users
    /// @param _resourcePerBlock Number of tokens to reward per block
    /// @param _startBlock Block number to start reward
    function initialize(IResource _resource, uint256 _resourcePerBlock, uint256 _startBlock)
        public
        initializer
    {
        __Ownable_init();
        resource = _resource;
        resourcePerBlock = _resourcePerBlock;
        startBlock = _startBlock;
        BONUS_MULTIPLIER = 1;
    }

    /// @notice Updates bonus multiplier
    /// @param _newBonusMultiplier the new bonus multiplier
    function updateBonusMultiplier(uint256 _newBonusMultiplier) external onlyOwner {
        BONUS_MULTIPLIER = _newBonusMultiplier;
    }

    /// @notice Gets the length for the pool info array
    /// @return poolInfo length
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    /// @notice Add a new LP token to the pool.
    /// @dev Duplicate LP tokens not allowed
    /// @param _allocPoint allocation points assigned to this new pool
    /// @param _lpToken the lp token added to the pool
    function add(uint256 _allocPoint, IERC20Upgradeable _lpToken) external onlyOwner {
        massUpdatePools();
        require(!addedPools[address(_lpToken)], "add: Duplicate pool");
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accResourcePerShare: 0
        }));
        addedPools[address(_lpToken)] = true;
        positionPoolsByLP[address(_lpToken)] = poolInfo.length - 1;
    }

    /// @notice Update alloc points for the given pool
    /// @param _pid The pool identifier
    /// @param _allocPoint The new alloc point quantity
    function set(uint256 _pid, uint256 _allocPoint) external onlyOwner {
        massUpdatePools();
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    /// @notice Return reward multiplier over the given _from to _to block
    /// @param _from From block
    /// @param _to To block
    /// @return Multiplier value
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    /// @notice Function to see pending tokens
    /// @param _pid Identifier of the pool in which we consult the pending rewards
    /// @param _user User that consult the rewards 
    function pendingResource(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accResourcePerShare = pool.accResourcePerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 resourceReward = multiplier.mul(resourcePerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accResourcePerShare = accResourcePerShare.add(resourceReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accResourcePerShare).div(1e12).sub(user.rewardDebt);
    }

    /// @notice Update reward variables for all pools
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    /// @notice Update reward variables
    /// @param _pid The pool identifier to update
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if(block.number <= pool.lastRewardBlock) return;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if(lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 resourceReward = multiplier.mul(resourcePerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        resource.mint(address(this), resourceReward);
        pool.accResourcePerShare = pool.accResourcePerShare.add(resourceReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    /// @notice Deposit LP tokens to the contract to receive rewards
    /// @param _pid The pool identifier where user deposit LP tokens
    /// @param _amount The amount to deposit
    function deposit(uint256 _pid, uint256 _amount) public nonReentrant {
        require ( _pid < poolInfo.length , "deposit: pool exists?");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if(user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accResourcePerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeResourceTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accResourcePerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    /// @notice Withdraw LP tokens from the contract
    /// @param _pid The pool identifier where user withdraw LP tokens
    /// @param _amount The amount to withdraw
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
        require ( _pid < poolInfo.length , "withdraw: pool exists?");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good amount");

        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accResourcePerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeResourceTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accResourcePerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    /// @notice Withdraw without caring about rewards. EMERGENCY ONLY.
    /// @param _pid The pool identifier where user withdraws
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    /// @notice Safe resource transfer function, just in case if rounding error causes pool to not have enough Resource tokens
    /// @param _to address for token receiver
    /// @param _amount Tokens that receiver will receive
    function safeResourceTransfer(address _to, uint256 _amount) internal {
        uint256 resourceBal = resource.balanceOf(address(this));
        if (_amount > resourceBal) {
            resource.safeTransfer(_to, resourceBal);
        } else {
            resource.safeTransfer(_to, _amount);
        }
    }

}
