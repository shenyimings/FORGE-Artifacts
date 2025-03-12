// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/ILiquidityProvider.sol";

contract iSwapFarming is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    /**
     * @notice Info of each user
     * @param amount: How many LP tokens the user has provided
     * @param rewardDebt: Reward debt. See explanation below
     */
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    /**
     * @notice Info of each pool
     * @param lpToken: Address of LP token contract
     * @param allocPoint: How many allocation points assigned to this pool. rewards to distribute per block
     * @param lastRewardTimestamp: Last block number that rewards distribution occurs
     * @param accRewardPerShare: Accumulated rewards per share, times 1e12. See below
     */
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. rewards to distribute per block.
        uint256 lastRewardTimestamp; // Last block number that rewards distribution occurs.
        uint256 accRewardPerShare; // Accumulated rewards per share, times 1e12. See below.
    }

    /// The reward token
    IERC20 public rewardToken;
    uint256 public rewardPerDay;

    /// Info of each pool.
    PoolInfo[] public poolInfo;
    /// Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    mapping(address => bool) public isPoolExist;

    /// Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;
    /// The block number when reward mining starts.
    uint256 public startTimestamp;

    /// The Liquidity Provider
    ILiquidityProvider public liquidityProvider;
    uint256 public liquidityProviderApiId;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Provider(
        address oldProvider,
        uint256 oldApi,
        address newProvider,
        uint256 newApi
    );
    event Migrator(address migratorAddress);

    modifier poolExists(uint256 _pid) {
        require(_pid < poolInfo.length, "iSwapFarming::UNKNOWN_POOL");
        _;
    }

    function initialize(
        IERC20 _rewardToken,
        uint256 _rewardPerDay,
        uint256 _startTimestamp
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        require(
            address(_rewardToken) != address(0x0),
            "iSwapFarming::SET_ZERO_ADDRESS"
        );

        rewardToken = _rewardToken;
        rewardPerDay = _rewardPerDay;
        startTimestamp = _startTimestamp;
    }

    /// @return All pools amount
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    /**
     * @notice Add a new lp to the pool. Can only be called by the owner
     * @param _allocPoint: allocPoint for new pool
     * @param _lpToken: address of lpToken for new pool
     * @param _withUpdate: if true, update all pools
     */
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        require(
            !isPoolExist[address(_lpToken)],
            "iSwapFarming::DUPLICATE_POOL"
        );
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardTimestamp = block.timestamp > startTimestamp
            ? block.timestamp
            : startTimestamp;
        totalAllocPoint += _allocPoint;
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardTimestamp: lastRewardTimestamp,
                accRewardPerShare: 0
            })
        );
        isPoolExist[address(_lpToken)] = true;
    }

    /**
     * @notice Update the given pool's reward allocation point. Can only be called by the owner
     */
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner poolExists(_pid) {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint =
            totalAllocPoint -
            poolInfo[_pid].allocPoint +
            _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function setProviderConfigs(ILiquidityProvider _provider, uint256 _api)
        external
        onlyOwner
    {
        emit Provider(address(liquidityProvider), liquidityProviderApiId, address(_provider), _api);
        liquidityProvider = _provider;
        liquidityProviderApiId = _api;
    }

    function setRewardToken(IERC20 _rewardToken) external onlyOwner {
        rewardToken = _rewardToken;
    }

    function setrewardPerDay(uint256 _rewardPerDay) external onlyOwner {
        massUpdatePools();
        rewardPerDay = _rewardPerDay;
    }

    /**
     * @param _from: block timestamp from which the reward is calculated
     * @param _to: block timestamp before which the reward is calculated
     * @return Return reward multiplier over the given _from to _to block
     */
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        return (rewardPerDay * (_to - _from)) / 1 days;
    }

    /**
     * @notice View function to see pending rewards on frontend
     * @param _pid: pool ID for which reward must be calculated
     * @param _user: user address for which reward must be calculated
     * @return Return reward for user
     */
    function pendingReward(uint256 _pid, address _user)
        public
        view
        poolExists(_pid)
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));

        if (block.number > pool.lastRewardTimestamp && lpSupply != 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardTimestamp,
                block.number
            );
            uint256 reward = (multiplier * pool.allocPoint) / totalAllocPoint;
            accRewardPerShare =
                accRewardPerShare +
                ((reward * 1e12) / lpSupply);
        }
        return (user.amount * accRewardPerShare) / 1e12 - user.rewardDebt;
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

    /**
     * @notice Update reward vairables for all pools
     */
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    /**
     * @notice Update reward variables of the given pool to be up-to-date
     * @param _pid: pool ID for which the reward variables should be updated
     */
    function updatePool(uint256 _pid) public poolExists(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardTimestamp) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardTimestamp = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(
            pool.lastRewardTimestamp,
            block.number
        );
        uint256 reward = (multiplier * pool.allocPoint) / totalAllocPoint;
        pool.accRewardPerShare =
            pool.accRewardPerShare +
            ((reward * 1e12) / lpSupply);
        pool.lastRewardTimestamp = block.number;
    }

    /**
     * @notice Function for updating user info
     */
    function _deposit(uint256 _pid, uint256 _amount) private {
        UserInfo storage user = userInfo[_pid][msg.sender];
        harvest(_pid);
        user.amount += _amount;
        user.rewardDebt =
            (user.amount * poolInfo[_pid].accRewardPerShare) /
            1e12;
        emit Deposit(msg.sender, _pid, _amount);
    }

    /**
     * @notice Deposit LP tokens to iSwapFarming for reward allocation
     * @param _pid: pool ID on which LP tokens should be deposited
     * @param _amount: the amount of LP tokens that should be deposited
     */
    function deposit(uint256 _pid, uint256 _amount) public poolExists(_pid) {
        updatePool(_pid);
        poolInfo[_pid].lpToken.safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        _deposit(_pid, _amount);
    }

    /**
     * @notice Function which send accumulated reward tokens to messege sender
     * @param _pid: pool ID from which the accumulated reward tokens should be received
     */
    function harvest(uint256 _pid) public poolExists(_pid) {
        UserInfo storage user = userInfo[_pid][msg.sender];
        if (user.amount > 0) {
            updatePool(_pid);
            uint256 accRewardPerShare = poolInfo[_pid].accRewardPerShare;
            uint256 pending = (user.amount * accRewardPerShare) /
                1e12 -
                user.rewardDebt;

            safeRewardTransfer(msg.sender, pending);

            user.rewardDebt = (user.amount * accRewardPerShare) / 1e12;
            emit Harvest(msg.sender, _pid, pending);
        }
    }

    /**
     * @notice Function which send accumulated reward tokens to messege sender from all pools
     */
    function harvestAll() public {
        uint256 length = poolInfo.length;
        for (uint256 i = 0; i < length; i++) {
            if (poolInfo[i].allocPoint > 0) {
                harvest(i);
            }
        }
    }

    /**
     * @notice Function which withdraw LP tokens to messege sender with the given amount
     * @param _pid: pool ID from which the LP tokens should be withdrawn
     * @param _amount: the amount of LP tokens that should be withdrawn
     */
    function withdraw(uint256 _pid, uint256 _amount) public poolExists(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = (user.amount * pool.accRewardPerShare) /
            1e12 -
            user.rewardDebt;
        safeRewardTransfer(msg.sender, pending);
        emit Harvest(msg.sender, _pid, pending);
        user.amount -= _amount;
        user.rewardDebt = (user.amount * pool.accRewardPerShare) / 1e12;
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    /**
     * @notice Function which transfer reward tokens to _to with the given amount
     * @param _to: transfer reciver address
     * @param _amount: amount of reward token which should be transfer
     */
    function safeRewardTransfer(address _to, uint256 _amount) internal {
        if (_amount > 0) {
            uint256 rewardTokenBal = rewardToken.balanceOf(address(this));
            if (_amount > rewardTokenBal) {
                rewardToken.transfer(_to, rewardTokenBal);
            } else {
                rewardToken.transfer(_to, _amount);
            }
        }
    }

    /**
     * @notice Function which take ETH, add liquidity with provider and deposit given LP's
     * @param _pid: pool ID where we want deposit
     * @param _amountAMin: bounds the extent to which the B/A price can go up before the transaction reverts.
        Must be <= amountADesired.
     * @param _amountBMin: bounds the extent to which the A/B price can go up before the transaction reverts.
        Must be <= amountBDesired
     * @param _minAmountOutA: the minimum amount of output A tokens that must be received
        for the transaction not to revert
     * @param _minAmountOutB: the minimum amount of output B tokens that must be received
        for the transaction not to revert
     */
    function speedStake(
        uint256 _pid,
        uint256 _amountAMin,
        uint256 _amountBMin,
        uint256 _minAmountOutA,
        uint256 _minAmountOutB,
        uint256 _deadline
    ) public payable poolExists(_pid) {
        (address routerAddr, , ) = liquidityProvider.apis(liquidityProviderApiId);

        require(routerAddr != address(0), "Exchange does not set yet");

        IiSwapRouter router = IiSwapRouter(routerAddr);

        delete routerAddr;

        PoolInfo storage pool = poolInfo[_pid];

        updatePool(_pid);

        IiSwapPair lpToken = IiSwapPair(address(pool.lpToken));
        uint256 lp;
        if (
            (lpToken.token0() == router.WETH()) ||
            ((lpToken.token1() == router.WETH()))
        ) {
            lp = liquidityProvider.addLiquidityETHByPair{value: msg.value}(
                lpToken,
                address(this),
                _amountAMin,
                _amountBMin,
                _minAmountOutA,
                _deadline,
                liquidityProviderApiId
            );
        } else {
            lp = liquidityProvider.addLiquidityByPair{value: msg.value}(
                lpToken,
                _amountAMin,
                _amountBMin,
                _minAmountOutA,
                _minAmountOutB,
                address(this),
                _deadline,
                liquidityProviderApiId
            );
        }

        _deposit(_pid, lp);
    }
}
