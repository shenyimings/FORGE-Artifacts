// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.16;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

// import 'hardhat/console.sol';

import './ArkenSmithyPool.sol';

/// @notice This contract holds Arken's LPs staking functionality.
///     The ARKEN reward that this contract will be distributed to stakers will be withdraw from SMITHY.
contract ArkenStaker is ArkenSmithyPool {
    // Modified from PancakeSwap code:
    // MasterChef: https://github.com/pancakeswap/pancake-smart-contracts/blob/master/projects/farms-pools/contracts/MasterChef.sol
    // MasterChefV2: https://bscscan.com/address/0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652#code

    using SafeERC20 for IERC20;

    /// @notice Info of each Staking pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    ///     Also known as the amount of "multipliers". Combined with `totalXAllocPoint`, it defines the % of
    ///     ARKEN rewards each pool gets. (% of Staker's pool in the SMITHY)
    /// `accPerShare` Accumulated ARKEN per share, times 1e12.
    /// `lastRewardBlock` Last block number that pool update action is executed.
    /// `totalShare` The total amount of user shares in each pool. After considering the share boosts.
    struct PoolInfo {
        uint256 allocPoint;
        uint256 accPerShare;
        uint256 lastRewardBlock;
        uint256 totalShare;
    }

    /// @notice Info of each ArkenStaker user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` Used to calculate the correct amount of rewards.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 rewardPending;
    }

    /// @notice Stake pools for LPs
    PoolInfo[] public poolInfos;

    /// @notice LP Tokens
    IERC20[] public lpTokens;

    /// @notice Info of each pool user
    mapping(uint256 => mapping(address => UserInfo)) public userInfos;

    /// @notice Allowance for each pool to each spender
    /// pid -> owner -> spender -> allowance
    mapping(uint256 => mapping(address => mapping(address => uint256)))
        public allowances;

    /// @notice Mapping lp address to pool id
    mapping(address => uint256) private poolIds;

    /// @notice Total allocation points for distributing ARKEN
    uint256 public totalAllocPoint = 0;

    uint256 public constant ACC_ARKEN_PRECISION = 1e18;

    event AddPool(
        uint256 indexed pid,
        uint256 allocPoint,
        IERC20 indexed lpToken
    );
    event SetPool(uint256 indexed pid, uint256 allocPoint);
    event UpdatePool(
        uint256 indexed pid,
        uint256 lastRewardBlock,
        uint256 lpSupply,
        uint256 accPerShare
    );
    event Deposit(
        uint256 indexed pid,
        address indexed user,
        address indexed by,
        uint256 amount
    );
    event Withdraw(
        uint256 indexed pid,
        address indexed user,
        address indexed by,
        address to,
        uint256 amount
    );
    event EmergencyWithdraw(
        uint256 indexed pid,
        address indexed user,
        uint256 amount
    );

    constructor(
        IArkenSmithy _ARKEN_SMITHY,
        IERC20 _ARKEN,
        uint256 _SMITHY_PID
    ) ArkenSmithyPool(_ARKEN_SMITHY, _ARKEN, _SMITHY_PID) {
        lpTokens.push(IERC20(address(0)));
        poolIds[address(0)] = poolInfos.length;
        poolInfos.push(
            PoolInfo({
                allocPoint: 0,
                lastRewardBlock: 0,
                accPerShare: 0,
                totalShare: 0
            })
        );
    }

    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) external onlyOwner {
        require(
            _lpToken.balanceOf(address(this)) >= 0,
            'ArkenStaker: REQUIRE_LP_TOKEN_BALANCE'
        );
        require(_lpToken != ARKEN, 'ArkenStaker: REQUIRE_LP_TOKEN');
        if (_withUpdate) {
            massUpdatePools();
        }
        require(
            poolIds[address(_lpToken)] == 0,
            'ArkenStaker: LP_TOKEN_EXISTS'
        );
        totalAllocPoint = totalAllocPoint + _allocPoint;
        lpTokens.push(_lpToken);
        poolIds[address(_lpToken)] = poolInfos.length;
        poolInfos.push(
            PoolInfo({
                allocPoint: _allocPoint,
                lastRewardBlock: block.number,
                accPerShare: 0,
                totalShare: 0
            })
        );
        emit AddPool(lpTokens.length - 1, _allocPoint, _lpToken);
    }

    function massSet(
        uint256[] calldata _pids,
        uint256[] calldata _allocPoints,
        bool _withUpdate
    ) external onlyOwner {
        require(
            _pids.length == _allocPoints.length,
            'ArkenSmithy: LENGTH_MISMATCH'
        );
        for (uint256 i = 0; i < _pids.length; i++) {
            // No matter _withUpdate is true or false, we need to execute updatePool once before setting the pool parameters.
            updatePool(_pids[i]);
        }
        uint256 newTotalAllocPoint = totalAllocPoint;
        for (uint256 i = 0; i < _pids.length; i++) {
            uint256 pid = _pids[i];
            uint256 allocPoint = _allocPoints[i];
            newTotalAllocPoint =
                newTotalAllocPoint -
                poolInfos[pid].allocPoint +
                allocPoint;
            poolInfos[pid].allocPoint = allocPoint;
            emit SetPool(pid, allocPoint);
        }
        totalAllocPoint = newTotalAllocPoint;
        if (_withUpdate) {
            massUpdatePools();
        }
    }

    /// @notice Update ARKEN reward for all the active pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfos.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo memory pool = poolInfos[pid];
            if (pool.allocPoint != 0) {
                updatePool(pid);
            }
        }
    }

    /// @notice Update reward variables for the given pool.
    /// @param _pid The id of the pool. See `poolInfos`.
    /// @return pool Returns the pool that was updated.
    function updatePool(uint256 _pid) public returns (PoolInfo memory pool) {
        pool = poolInfos[_pid];
        if (block.number > pool.lastRewardBlock) {
            uint256 lpSupply = pool.totalShare;
            if (lpSupply > 0 && totalAllocPoint > 0) {
                uint256 rewardInPeriod = getReward(
                    pool.lastRewardBlock,
                    block.number
                );
                uint256 arkenReward = ((rewardInPeriod * pool.allocPoint) *
                    ACC_ARKEN_PRECISION) / totalAllocPoint;
                pool.accPerShare = pool.accPerShare + (arkenReward / lpSupply);
            }
            pool.lastRewardBlock = block.number;
            poolInfos[_pid] = pool;
            emit UpdatePool(
                _pid,
                pool.lastRewardBlock,
                lpSupply,
                pool.accPerShare
            );
        }
    }

    function _deposit(
        uint256 _pid,
        address _from,
        address _user,
        uint256 _amount
    ) internal {
        PoolInfo memory pool = updatePool(_pid);
        UserInfo memory userInfo = userInfos[_pid][_user];
        userInfo.rewardPending = _updatePendingArken(_pid, _user);
        if (_amount > 0) {
            IERC20 lpToken = lpTokens[_pid];
            uint256 before = lpToken.balanceOf(address(this));
            lpToken.safeTransferFrom(_from, address(this), _amount);
            _amount = lpToken.balanceOf(address(this)) - before;
            userInfo.amount = userInfo.amount + _amount;
            pool.totalShare = pool.totalShare + _amount;
        }
        userInfo.rewardDebt =
            (userInfo.amount * pool.accPerShare) /
            ACC_ARKEN_PRECISION;

        userInfos[_pid][_user] = userInfo;
        poolInfos[_pid] = pool;
    }

    /// @notice Deposit LP tokens to pool.
    /// @param _pid The id of the pool.
    /// @param _amount Amount of LP tokens to deposit.
    function deposit(uint256 _pid, uint256 _amount) external nonReentrant {
        _deposit(_pid, msg.sender, msg.sender, _amount);
        emit Deposit(_pid, msg.sender, msg.sender, _amount);
    }

    /// @notice Deposit LP tokens to pool for other address.
    /// @param _pid The id of the pool.
    /// @param _for The address to deposit for.
    /// @param _amount Amount of LP tokens to deposit.
    function depositFor(
        uint256 _pid,
        address _for,
        uint256 _amount
    ) external nonReentrant {
        _deposit(_pid, msg.sender, _for, _amount);
        _increaseAllowance(_pid, _for, msg.sender, _amount);
        emit Deposit(_pid, _for, msg.sender, _amount);
    }

    function _withdraw(
        uint256 _pid,
        address _user,
        address _to,
        uint256 _amount
    ) internal {
        PoolInfo memory pool = updatePool(_pid);
        UserInfo memory userInfo = userInfos[_pid][_user];
        require(
            _amount <= userInfo.amount,
            'ArkenStaker: INSUFFICIENT_STAKED_AMOUNT'
        );
        userInfo.rewardPending = _updatePendingArken(_pid, _user);
        if (_amount > 0) {
            userInfo.amount = userInfo.amount - _amount;
            lpTokens[_pid].safeTransfer(_to, _amount);
        }
        userInfo.rewardDebt =
            (userInfo.amount * pool.accPerShare) /
            ACC_ARKEN_PRECISION;
        pool.totalShare = pool.totalShare - _amount;

        userInfos[_pid][_user] = userInfo;
        poolInfos[_pid] = pool;
    }

    /// @notice Withdraw LP tokens from pool.
    /// @param _pid The id of the pool.
    /// @param _to The address to send lp token to.
    /// @param _amount Amount of LP tokens to withdraw.
    function withdraw(
        uint256 _pid,
        address _to,
        uint256 _amount
    ) external nonReentrant {
        _withdraw(_pid, msg.sender, _to, _amount);
        emit Withdraw(_pid, msg.sender, msg.sender, _to, _amount);
    }

    /// @notice Withdraw LP tokens from pool.
    /// @param _pid The id of the pool.
    /// @param _user The address to claim lp from.
    /// @param _to The address to send lp token to.
    /// @param _amount Amount of LP tokens to withdraw.
    function withdrawFor(
        uint256 _pid,
        address _user,
        address _to,
        uint256 _amount
    ) external nonReentrant {
        _decreaseAllowance(_pid, _user, msg.sender, _amount);
        _withdraw(_pid, _user, _to, _amount);
        emit Withdraw(_pid, _user, msg.sender, _to, _amount);
    }

    /// @notice Update pending ARKEN
    /// @param _pid The id of the pool.
    /// @param _user The user address.
    function _updatePendingArken(uint256 _pid, address _user)
        internal
        view
        returns (uint256 pending)
    {
        return
            userInfos[_pid][_user].rewardPending +
            _pendingFromLastUpdate(_pid, _user);
    }

    /// @notice Settles and distribute pending ARKEN
    /// @param _pid The id of the pool.
    /// @param _user The user address.
    /// @param _amount Amount of reward to settle.
    function _settlePendingArken(
        uint256 _pid,
        address _user,
        uint256 _amount
    ) internal {
        UserInfo memory userInfo = userInfos[_pid][_user];
        userInfo.rewardPending = _updatePendingArken(_pid, _user);
        require(
            _amount <= userInfo.rewardPending,
            'ArkenStaker: SETTLE_AMOUNT_EXCEEDS_PENDING'
        );
        _withdrawFromSmithy(_user, _amount);
        userInfo.rewardPending -= _amount;
        userInfos[_pid][_user] = userInfo;
    }

    /// @notice Settles and distribute pending ARKEN
    /// @param _pid The id of the pool.
    /// @param _user The user address.
    /// @param _amount Amount of reward to settle.
    /// @param _settleForBalance true = if balance is below amount, settles for balance || false = if balance is below amount, revert
    function settleReward(
        uint256 _pid,
        address _user,
        uint256 _amount,
        bool _settleForBalance
    ) external {
        uint256 amount = _amount;
        uint256 smithyRewardBal = ARKEN.balanceOf(address(ARKEN_SMITHY));
        if (_settleForBalance) {
            if (smithyRewardBal < amount) {
                amount = smithyRewardBal;
            }
        } else {
            require(
                _amount <= smithyRewardBal,
                'ArkenStaker: SMITHY_NOT_ENOUGH_ARKEN'
            );
        }
        _settlePendingArken(_pid, _user, _amount);
    }

    function _pendingFromLastUpdate(uint256 _pid, address _user)
        internal
        view
        returns (uint256 pending)
    {
        PoolInfo memory pool = poolInfos[_pid];

        if (block.number > pool.lastRewardBlock) {
            uint256 lpSupply = pool.totalShare;
            if (lpSupply > 0 && totalAllocPoint > 0) {
                uint256 rewardInPeriod = getReward(
                    pool.lastRewardBlock,
                    block.number
                );
                uint256 arkenReward = ((rewardInPeriod * pool.allocPoint) *
                    ACC_ARKEN_PRECISION) / totalAllocPoint;
                pool.accPerShare = pool.accPerShare + (arkenReward / lpSupply);
            }
        }

        UserInfo memory userInfo = userInfos[_pid][_user];
        uint256 accArken = (userInfo.amount * pool.accPerShare) /
            ACC_ARKEN_PRECISION;
        return accArken - userInfo.rewardDebt;
    }

    function pendingArken(uint256 _pid, address _user)
        public
        view
        returns (uint256 pending)
    {
        uint256 pendingFromLastUpdate = _pendingFromLastUpdate(_pid, _user);
        UserInfo memory userInfo = userInfos[_pid][_user];
        return userInfo.rewardPending + pendingFromLastUpdate;
    }

    /// @notice Withdraw without caring about the rewards. EMERGENCY ONLY.
    /// @param _pid The id of the pool. See `poolInfo`.
    function emergencyWithdraw(uint256 _pid) external nonReentrant {
        PoolInfo storage pool = poolInfos[_pid];
        UserInfo storage user = userInfos[_pid][msg.sender];

        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;

        pool.totalShare = pool.totalShare - amount;

        // Note: transfer can fail or succeed if `amount` is zero.
        lpTokens[_pid].safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(_pid, msg.sender, amount);
    }

    function getPoolId(address _lp) public view returns (uint256 pid) {
        pid = poolIds[_lp];
    }

    function getRewardPerBlock(address _lp)
        public
        view
        returns (uint256 rewardPerBlock)
    {
        uint256 pid = getPoolId(_lp);
        PoolInfo memory pool = poolInfos[pid];
        rewardPerBlock = (arkenPerBlock() * pool.allocPoint) / totalAllocPoint;
    }

    function allowance(
        uint256 _pid,
        address _owner,
        address _spender
    ) public view returns (uint256 amount) {
        amount = allowances[_pid][_owner][_spender];
    }

    function approve(
        uint256 _pid,
        address _spender,
        uint256 _amount
    ) external {
        _approve(_pid, msg.sender, _spender, _amount);
    }

    function _increaseAllowance(
        uint256 _pid,
        address _owner,
        address _spender,
        uint256 _amount
    ) internal {
        _approve(
            _pid,
            _owner,
            _spender,
            allowances[_pid][_owner][_spender] + _amount
        );
    }

    function _decreaseAllowance(
        uint256 _pid,
        address _owner,
        address _spender,
        uint256 _amount
    ) internal {
        require(
            _amount <= allowances[_pid][_owner][_spender],
            'ArkenStaker: INSUFFICIENT_ALLOWANCE'
        );
        _approve(
            _pid,
            _owner,
            _spender,
            allowances[_pid][_owner][_spender] - _amount
        );
    }

    function _approve(
        uint256 _pid,
        address _owner,
        address _spender,
        uint256 _amount
    ) internal {
        require(_owner != address(0), 'ArkenStaker: APPROVE_FROM_ZERO_ADDRESS');
        require(_spender != address(0), 'ArkenStaker: APPROVE_TO_ZERO_ADDRESS');
        allowances[_pid][_owner][_spender] = _amount;
    }
}
