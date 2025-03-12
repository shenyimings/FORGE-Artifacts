// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./core/Ownable.sol";
import "./interfaces/IMigratorFarming.sol";

contract AvatarArtFarming is Ownable {
    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. BNUs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that BNUs distribution occurs.
        uint256 accBnuPerShare; // Accumulated BNUs per share, times 1e12. See below.
        uint256 stakedTotal;
    }

    // The BNU TOKEN!
    IERC20 public bnu;
    
    // BNU tokens created per block.
    uint256 public bnuPerBlock;
    // Bonus muliplier for early bnu makers.
    uint256 public BONUS_MULTIPLIER = 1;
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorFarming public migrator;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when BNU mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        address bnuAddress,
        uint256 _bnuPerBlock,
        uint256 _startBlock
    ) {
        bnu = IERC20(bnuAddress);
        bnuPerBlock = _bnuPerBlock;
        startBlock = _startBlock;

        // staking pool
        poolInfo.push(PoolInfo({
            lpToken: bnu,
            allocPoint: 1000,
            lastRewardBlock: startBlock,
            accBnuPerShare: 0,
            stakedTotal: 0
        }));

        totalAllocPoint = 1000;
    }

    function updateMultiplier(uint256 multiplierNumber) external onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint += _allocPoint;
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accBnuPerShare: 0,
            stakedTotal: 0
        }));
        _updateStakingPool();
    }

    // Update the given pool's BNU allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        if (prevAllocPoint != _allocPoint) {
            _updateStakingPool();
        }
    }

    function _updateStakingPool() internal {
        uint256 length = poolInfo.length;
        uint256 points = 0;
        for (uint256 pid = 1; pid < length; ++pid) {
            points = points + poolInfo[pid].allocPoint;
        }
        if (points != 0) {
            points = points/3;
            totalAllocPoint = totalAllocPoint - poolInfo[0].allocPoint + points;
            poolInfo[0].allocPoint = points;
        }
    }

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorFarming _migrator) public onlyOwner {
        migrator = _migrator;
    }

    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    function migrate(uint256 _pid) public {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IERC20 lpToken = pool.lpToken;
        uint256 bal = lpToken.balanceOf(address(this));
        lpToken.approve(address(migrator), bal);
        IERC20 newLpToken = migrator.migrate(lpToken);
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.lpToken = newLpToken;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return (_to - _from) * BONUS_MULTIPLIER;
    }

    // View function to see pending BNUs on frontend.
    function pendingBnu(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accBnuPerShare = pool.accBnuPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 bnuReward = multiplier * bnuPerBlock * pool.allocPoint / totalAllocPoint;
            accBnuPerShare = accBnuPerShare + (bnuReward * 1e12 / lpSupply);
        }
        return user.amount * accBnuPerShare / 1e12 - user.rewardDebt;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 bnuReward = multiplier * bnuPerBlock * pool.allocPoint / totalAllocPoint;
        pool.accBnuPerShare = pool.accBnuPerShare + (bnuReward * 1e12 / lpSupply);
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for BNU allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        require (_pid != 0, 'deposit BNU by staking');

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount * pool.accBnuPerShare / 1e12 - user.rewardDebt;
            if(pending > 0) {
                safeRewardBnu(_msgSender(), pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.transferFrom(address(_msgSender()), address(this), _amount);
            user.amount = user.amount + _amount;
        }
        user.rewardDebt = user.amount * pool.accBnuPerShare / 1e12;
        pool.stakedTotal += _amount;
        emit Deposit(_msgSender(), _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        require (_pid != 0, 'withdraw BNU by unstaking');

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount * pool.accBnuPerShare / 1e12 - user.rewardDebt;
        if(pending > 0) {
            safeRewardBnu(_msgSender(), pending);
        }
        if(_amount > 0) {
            user.amount = user.amount - _amount;
            pool.lpToken.transfer(_msgSender(), _amount);
        }
        user.rewardDebt = user.amount * pool.accBnuPerShare / 1e12;
        pool.stakedTotal -= _amount;
        emit Withdraw(_msgSender(), _pid, _amount);
    }

    // Stake BNU tokens to MasterChef
    function enterStaking(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][_msgSender()];
        updatePool(0);
        if (user.amount > 0) {
            uint256 pending = user.amount * pool.accBnuPerShare / 1e12 - user.rewardDebt;
            if(pending > 0) {
                safeRewardBnu(_msgSender(), pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.transferFrom(address(_msgSender()), address(this), _amount);
            user.amount = user.amount + _amount;
        }
        user.rewardDebt = user.amount * pool.accBnuPerShare / 1e12;
        pool.stakedTotal += _amount;
        emit Deposit(_msgSender(), 0, _amount);
    }

    // Withdraw BNU tokens from STAKING.
    function leaveStaking(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][_msgSender()];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(0);
        uint256 pending = user.amount * pool.accBnuPerShare / 1e12 - user.rewardDebt;
        if(pending > 0) {
            safeRewardBnu(_msgSender(), pending);
        }
        if(_amount > 0) {
            user.amount = user.amount - _amount;
            pool.lpToken.transfer(address(_msgSender()), _amount);
        }
        user.rewardDebt = user.amount * pool.accBnuPerShare / 1e12;
        pool.stakedTotal -= _amount;
        emit Withdraw(_msgSender(), 0, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];
        pool.lpToken.transfer(address(_msgSender()), user.amount);
        emit EmergencyWithdraw(_msgSender(), _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    //Make sure enough BNU to reward
    //If not enough, reward the remained BNU amount
    function safeRewardBnu(address _to, uint256 _amount) internal {
        PoolInfo memory pool = poolInfo[0];
        uint bnuBalance = bnu.balanceOf(address(this));
        if(bnuBalance - pool.stakedTotal >= _amount){
            bnu.transfer(_to, _amount);
        }
    }
}