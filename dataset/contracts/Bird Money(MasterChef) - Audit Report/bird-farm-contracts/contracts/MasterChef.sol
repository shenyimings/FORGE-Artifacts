// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity 0.6.12;

// MasterChef is the master of RewardToken. He can make RewardToken and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once REWARD_TOKEN is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable {
    using SafeMath for uint256;

    //user can get reward and unstake after this time only.
    uint256 public unstakeFrozenTime = 0; // No froze time initially, if needed it can be added and informed to community.

    uint256 public rewardFrozenTime = 0; // No froze time initially, if needed it can be added and informed to community.

    // The block number when REWARD_TOKEN distribution starts.
    uint256 public startRewardBlock = 0;

    // The block number when REWARD_TOKEN distribution stops.
    uint256 public endRewardBlock = MAX_UINT; // MAX UINT

    // REWARD_TOKEN tokens created per block.
    uint256 public rewardTokenPerBlock = 100;

    // The REWARD_TOKEN TOKEN!
    IERC20 public rewardToken;

    // Info of each pool.
    PoolInfo[] public poolInfo;

    // To prevent a token to added in multiple pools
    mapping(IERC20 => bool) public uniqueTokenInPool;

    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // save pending rewards with respect to each pool id
    //  user_address  =>  ( pool_id => pendingReward)
    mapping(address => mapping(uint256 => uint256)) public pendingRewardOf;

    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;

    uint256 public constant MAX_UINT = type(uint256).max;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(IERC20 _rewardToken) public {
        rewardToken = _rewardToken;
    }

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 unstakeTime; // user can unstake LP tokens at this time to get reward
        //
        // We do some fancy math here. Basically, any point in time, the amount of REWARD_TOKENs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accRewardTokenPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accRewardTokenPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. REWARD_TOKENs to distribute per block.
        uint256 lastRewardBlock; // Last block number that REWARD_TOKENs distribution occurs.
        uint256 accRewardTokenPerShare; // Accumulated REWARD_TOKENs per share, times 1e12. See below.
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        require(!uniqueTokenInPool[_lpToken], "LP Token already added");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            block.number > startRewardBlock ? block.number : startRewardBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accRewardTokenPerShare: 0
            })
        );
        uniqueTokenInPool[_lpToken] = true;
    }

    // Update the given pool's REWARD_TOKEN allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        internal
        view
        returns (uint256)
    {
        _from = _from < startRewardBlock ? startRewardBlock : _from;
        _to = _to > endRewardBlock ? endRewardBlock : _to;
        return _to.sub(_from);
    }

    /// @author Mary A. Botanist
    /// @notice Calculate tree age in years, rounded up, for live trees
    /// @dev The Alexandr N. Tetearing algorithm could increase precision
    /// @param rings The number of rings from dendrochronological sample
    /// @return age in years, rounded up for partial years
    // View function to see pending REWARD_TOKENs on frontend.
    function pendingRewardToken(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardTokenPerShare = pool.accRewardTokenPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));

        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 rewardTokenReward =
            multiplier
                .mul(rewardTokenPerBlock)
                .mul(pool.allocPoint)
                .mul(1e12)
                .div(totalAllocPoint);
        accRewardTokenPerShare = accRewardTokenPerShare.add(
            rewardTokenReward.div(lpSupply)
        );

        return
            user.amount.mul(accRewardTokenPerShare).div(1e12).sub(
                user.rewardDebt
            );
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() internal {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];

        if (block.number < startRewardBlock || block.number > endRewardBlock) {
            return;
        }

        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 rewardTokenReward =
            multiplier
                .mul(rewardTokenPerBlock)
                .mul(pool.allocPoint)
                .mul(1e12)
                .div(totalAllocPoint);
        pool.accRewardTokenPerShare = pool.accRewardTokenPerShare.add(
            rewardTokenReward.div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for REWARD_TOKEN allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        require(_amount > 0, "Must deposit amount more than ZERO");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(
            pool.lpToken.balanceOf(msg.sender) >= _amount,
            "Must deposit amount more than ZERO"
        );
        updatePool(_pid);

        uint256 pending =
            user.amount.mul(pool.accRewardTokenPerShare).div(1e12).sub(
                user.rewardDebt
            );
        savePendingReward(msg.sender, _pid, pending);
        if (user.amount == 0) user.unstakeTime = now + unstakeFrozenTime;
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accRewardTokenPerShare).div(
            1e12
        );
        pool.lpToken.transferFrom(address(msg.sender), address(this), _amount);
        // emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        require(_amount > 0, "Must withdraw amount more than ZERO");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        require(now > user.unstakeTime, "Can not unstake at this time.");

        updatePool(_pid);
        uint256 pending =
            user.amount.mul(pool.accRewardTokenPerShare).div(1e12).sub(
                user.rewardDebt
            );
        savePendingReward(msg.sender, _pid, pending);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accRewardTokenPerShare).div(
            1e12
        );
        pool.lpToken.transfer(address(msg.sender), _amount);
        // emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.transfer(address(msg.sender), user.amount);
        // emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    }

    function savePendingReward(
        address _user,
        uint256 _pid,
        uint256 _amount
    ) internal {
        pendingRewardOf[_user][_pid] = pendingRewardOf[_user][_pid] + _amount;
    }

    function harvestPendingReward(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount > 0, "You have to stake tokens to get reward.");
        require(now > rewardFrozenTime, "Can not collect reward at this time.");

        updatePool(_pid);
        uint256 pending =
            user.amount.mul(pool.accRewardTokenPerShare).div(1e12).sub(
                user.rewardDebt
            );
        savePendingReward(msg.sender, _pid, pending);

        rewardToken.transfer(msg.sender, getReward(_pid));
    }

    // only for Owner
    function addRewardTokensToContract(uint256 _amount) public onlyOwner {
        rewardToken.transferFrom(msg.sender, address(this), _amount);
    }

    function getRewardTokensFromContract(uint256 _amount) public onlyOwner {
        rewardToken.transfer(msg.sender, _amount);
    }

    // getters
    function getReward(uint256 _pid) public view returns (uint256) {
        return pendingRewardOf[msg.sender][_pid];
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // setters
    function setAll(
        IERC20 _rewardToken,
        uint256 _rewardTokenPerBlock,
        uint256 _startRewardBlock,
        uint256 _endRewardBlock,
        uint256 _unstakeFrozenTime
    ) public onlyOwner {
        rewardToken = _rewardToken;
        rewardTokenPerBlock = _rewardTokenPerBlock;
        startRewardBlock = _startRewardBlock;
        endRewardBlock = _endRewardBlock;
        unstakeFrozenTime = _unstakeFrozenTime;
    }

    function setRewardToken(IERC20 _rewardToken) public onlyOwner {
        rewardToken = _rewardToken;
    }

    function setUnstakeFrozenTime(uint256 _unstakeFrozenTime) public onlyOwner {
        unstakeFrozenTime = _unstakeFrozenTime;
    }

    function setRewardFrozenTime(uint256 _rewardFrozenTime) public onlyOwner {
        rewardFrozenTime = _rewardFrozenTime;
    }

    function setRewardTokenPerBlock(uint256 _rewardTokenPerBlock)
        public
        onlyOwner
    {
        rewardTokenPerBlock = _rewardTokenPerBlock;
    }

    function setStartRewardBlock(uint256 _startRewardBlock) public onlyOwner {
        require(
            _startRewardBlock <= endRewardBlock,
            "Start block must be less or equal to end reward block."
        );
        startRewardBlock = _startRewardBlock;
    }

    function setEndRewardBlock(uint256 _endRewardBlock) public onlyOwner {
        require(
            startRewardBlock <= _endRewardBlock,
            "End reward block must be greater or equal to start reward block."
        );
        endRewardBlock = _endRewardBlock;
    }

    // migrator
    IMigratorChef public migrator;

    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }
}

interface IMigratorChef {
    function migrate(IERC20 token) external returns (IERC20);
}

// Mazdoori / Labor work at end
// adding comments nat spec https://docs.soliditylang.org/en/develop/natspec-format.html
// making EVENTS
// set external view to some functions
// use return values i.e   require(rewardToken.transfer(), "Error occured during transfer")

// variable function names mashwra sir, youtube video or main contracts insdustry
