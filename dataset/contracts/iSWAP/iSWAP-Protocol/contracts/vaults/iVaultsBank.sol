// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/IERC20Burnable.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IPancakeRouter02.sol";
import "hardhat/console.sol";

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract iVaultBank is ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 shares; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        // We do some fancy math here. Basically, any point in time, the amount of GYM
        // entitled to a user but is pending to be distributed is:
        //
        //   amount = user.shares / sharesTotal * wantLockedTotal
        //   pending reward = (amount * pool.accRewardTokenPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws want tokens to a pool. Here's what happens:
        //   1. The pool's `accRewardTokenPerShare` (and `lastRewardTimestamp`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    struct PoolInfo {
        IERC20 want; // Address of the want token.
        uint256 allocPoint; // How many allocation points assigned to this pool. GYM to distribute per block.
        uint256 lastRewardTimestamp; // Last block number that reward distribution occurs.
        uint256 accRewardPerShare; // Accumulated rewardPool per share, times 1e18.
        address strategy; // Strategy address that will auto compound want tokens
    }

    address public rewardToken; // Address of rewardPool token contract.
    uint256 public rewardPerDay; // Reward token amount to distribute per block.
    uint256 public totalPaidRewards;

    uint256 public startTimestamp; // https://bscscan.com/block/countdown/4814500

    PoolInfo[] public poolInfo; // Info of each pool.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo; // Info of each user that stakes LP tokens.
    uint256 public totalAllocPoint; // Total allocation points. Must be the sum of all allocation points in all pools.
    address constant WETH_ADDRESS =
        address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    /* =================== Added variables (need to keep orders for proxy to work) =================== */

    bool public pausePool;

    /* ========== EVENTS ========== */

    event Initialized(address indexed executor, uint256 at);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event RewardPaid(
        address indexed token,
        address indexed user,
        uint256 amount
    );

    function initialize(
        uint256 _startTimestamp,
        address _rewardToken,
        uint256 _rewardRate
    ) public initializer {
        require(block.timestamp < _startTimestamp, "iVaultBank: Late");
        __Ownable_init();
        __ReentrancyGuard_init();
        startTimestamp = _startTimestamp;
        rewardToken = _rewardToken;
        rewardPerDay = _rewardRate;
        emit Initialized(msg.sender, block.timestamp);
    }

    receive() external payable {}

    fallback() external payable {}

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function addPool(
        IERC20 _want,
        uint256 _allocPoint,
        bool _withUpdate,
        address _strategy
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardTimestamp = block.timestamp > startTimestamp
            ? block.timestamp
            : startTimestamp;
        totalAllocPoint = totalAllocPoint + _allocPoint;
        poolInfo.push(
            PoolInfo({
                want: _want,
                allocPoint: _allocPoint,
                lastRewardTimestamp: lastRewardTimestamp,
                accRewardPerShare: 0,
                strategy: _strategy
            })
        );
    }

    // Update the given pool's reward allocation point. Can only be called by the owner.
    function setPool(uint256 _pid, uint256 _allocPoint) external onlyOwner {
        massUpdatePools();
        totalAllocPoint =
            totalAllocPoint -
            poolInfo[_pid].allocPoint +
            _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function updateRewardPerDay(uint256 _rewardPerDay)
        external
        nonReentrant
        onlyOwner
    {
        massUpdatePools();
        rewardPerDay = _rewardPerDay;
    }

    // View function to see pending reward on frontend.
    function pendingReward(uint256 _pid, address _user)
        public
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 _accRewardPerShare = pool.accRewardPerShare;
        uint256 sharesTotal = IStrategy(pool.strategy).sharesTotal();
        if (block.timestamp > pool.lastRewardTimestamp && sharesTotal != 0) {
            uint256 _multiplier = (block.timestamp - pool.lastRewardTimestamp) /
                1 days;
            uint256 _reward = (_multiplier * rewardPerDay * pool.allocPoint) /
                totalAllocPoint;
            _accRewardPerShare =
                _accRewardPerShare +
                ((_reward * 1e18) / sharesTotal);
        }
        return (user.shares * _accRewardPerShare) / 1e18 - user.rewardDebt;
    }

    function pendingRewardTotal(address _user)
        external
        view
        returns (uint256 total)
    {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            total += pendingReward(pid, _user);
        }
    }

    // View function to see staked Want tokens on frontend.
    function stakedWantTokens(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256 sharesTotal = IStrategy(pool.strategy).sharesTotal();
        uint256 wantLockedTotal = IStrategy(poolInfo[_pid].strategy)
            .wantLockedTotal();
        if (sharesTotal == 0) {
            return 0;
        }
        return (user.shares * wantLockedTotal) / sharesTotal;
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
        if (block.timestamp <= pool.lastRewardTimestamp) {
            return;
        }
        uint256 sharesTotal = IStrategy(pool.strategy).sharesTotal();
        if (sharesTotal == 0) {
            pool.lastRewardTimestamp = block.timestamp;
            return;
        }
        uint256 _multiplier = (block.timestamp - pool.lastRewardTimestamp) /
            1 days;
        uint256 _reward = (_multiplier * rewardPerDay * pool.allocPoint) /
            totalAllocPoint;
        pool.accRewardPerShare =
            pool.accRewardPerShare +
            ((_reward * 1e18) / sharesTotal);
        pool.lastRewardTimestamp = block.timestamp;
    }

    function _getReward(uint256 _pid) internal {
        PoolInfo storage _pool = poolInfo[_pid];
        UserInfo storage _user = userInfo[_pid][msg.sender];
        uint256 _pending = (_user.shares * _pool.accRewardPerShare) /
            (1e18) -
            (_user.rewardDebt);
        if (_pending > 0) {
            address _rewardToken = rewardToken;
            safeRewardTransfer(_rewardToken, msg.sender, _pending);
            totalPaidRewards = totalPaidRewards + (_pending);
            emit RewardPaid(_rewardToken, msg.sender, _pending);
        }
    }

    function deposit(uint256 _pid, uint256 _wantAmt)
        external
        payable
        nonReentrant
    {
        PoolInfo storage pool = poolInfo[_pid];
        if (address(pool.want) == WETH_ADDRESS) {
            IWETH(WETH_ADDRESS).deposit{value: msg.value}();
            _wantAmt = msg.value;
        }
        _deposit(_pid, _wantAmt);
    }

    function _deposit(uint256 _pid, uint256 _wantAmt) private {
        require(!pausePool, "iVaultBank: Paused");
        updatePool(_pid);
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        if (user.shares > 0) {
            _getReward(_pid);
        }
        if (_wantAmt > 0) {
            if (address(pool.want) != WETH_ADDRESS) {
                pool.want.safeTransferFrom(
                    address(msg.sender),
                    address(this),
                    _wantAmt
                );
            }

            pool.want.safeIncreaseAllowance(pool.strategy, _wantAmt);
            uint256 sharesAdded = IStrategy(poolInfo[_pid].strategy).deposit(
                msg.sender,
                _wantAmt
            );

            user.shares = user.shares + sharesAdded;
        }
        user.rewardDebt = (user.shares * (pool.accRewardPerShare)) / (1e18);
        emit Deposit(msg.sender, _pid, _wantAmt);
    }

    function withdraw(uint256 _pid, uint256 _wantAmt) external nonReentrant {
        _withdraw(_pid, _wantAmt);
    }

    function _withdraw(uint256 _pid, uint256 _wantAmt) private {
        require(!pausePool, "iVaultBank: Paused");
        updatePool(_pid);

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 wantLockedTotal = IStrategy(poolInfo[_pid].strategy)
            .wantLockedTotal();
        uint256 sharesTotal = IStrategy(poolInfo[_pid].strategy).sharesTotal();

        require(user.shares > 0, "iVaultBank: user.shares is 0");
        require(sharesTotal > 0, "iVaultBank: sharesTotal is 0");

        _getReward(_pid);

        // Withdraw want tokens
        uint256 amount = (user.shares * (wantLockedTotal)) / (sharesTotal);
        if (_wantAmt > amount) {
            _wantAmt = amount;
        }
        if (_wantAmt > 0) {
            uint256 sharesRemoved = IStrategy(poolInfo[_pid].strategy).withdraw(
                msg.sender,
                _wantAmt
            );

            user.shares = user.shares - (sharesRemoved);
            uint256 wantBal = IERC20(pool.want).balanceOf(address(this));
            if (wantBal < _wantAmt) {
                _wantAmt = wantBal;
            }

            if (_wantAmt > 0) {
                if (address(pool.want) == WETH_ADDRESS) {
                    IWETH(WETH_ADDRESS).withdraw(_wantAmt);
                    payable(msg.sender).transfer(_wantAmt);
                } else {
                    pool.want.safeTransfer(address(msg.sender), _wantAmt);
                }
            }
        }
        user.rewardDebt = (user.shares * (pool.accRewardPerShare)) / (1e18);

        emit Withdraw(msg.sender, _pid, _wantAmt);
    }

    // Safe reward token transfer function, just in case if rounding error causes pool to not have enough
    function safeRewardTransfer(
        address _rewardToken,
        address _to,
        uint256 _amount
    ) internal {
        uint256 _bal = IERC20(_rewardToken).balanceOf(address(this));
        if (_amount > _bal) {
            IERC20(_rewardToken).transfer(_to, _bal);
        } else {
            IERC20(_rewardToken).transfer(_to, _amount);
        }
    }

    // Allows owner to pause deposits and withdraws from the pool in case if there is a exploit on the strategy
    function setPausePool(bool _pausePool) external nonReentrant onlyOwner {
        pausePool = _pausePool;
    }
}
