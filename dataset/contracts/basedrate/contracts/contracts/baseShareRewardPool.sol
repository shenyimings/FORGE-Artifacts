// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./aerodrome/interfaces/IGauge.sol";
import "./aerodrome/interfaces/IPool.sol";
import "./aerodrome/interfaces/IVoter.sol";

// import "hardhat/console.sol";

interface IBSHARE is IERC20 {
    function mint(address account, uint256 amount) external;
}

contract BaseShareRewardPool is ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IBSHARE;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 token; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. BaseShare to distribute per block.
        uint256 lastRewardTime; // Last time that baseShare distribution occurs.
        uint16 depositFeeBP; //depositfee
        uint16 withdrawFeeBP; //withdrawfee
        uint256 accTokensPerShare; // Accumulated baseShare per share, times 1e18. See below.
        bool isStarted; // if lastRewardTime has passed
        IGauge gauge; // Gauge associated with the pool.
        uint256 lpBalance;
    }

    struct PoolView {
        uint256 pid;
        address token;
        uint256 allocPoint;
        uint256 lastRewardTime;
        uint16 depositFeeBP;
        uint16 withdrawFeeBP;
        uint256 accTokensPerShare;
        bool isStarted;
        address gauge;
        uint256 lpBalance;
        uint256 rewardsPerSecond;
    }

    struct UserView {
        uint256 pid;
        uint256 stakedAmount;
        uint256 unclaimedRewards;
        uint256 lpBalance;
        uint256 allowance;
    }

    IBSHARE public baseShare;
    IVoter public constant aeroVoter =
        IVoter(0x16613524e02ad97eDfeF371bC883F2F5d6C480A5);

    // Info of each pool.
    PoolInfo[] public poolInfo;
    EnumerableSet.AddressSet private lpTokens;

    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;

    // The time when baseShare mining starts.
    uint256 public poolStartTime;

    address public feeAddress;
    address public devAddress;
    uint256 public feePercent;
    uint256 public devPercent;

    uint256 public sharesPerSecond;

    uint256 public referralRate = 500;
    mapping(address => address) public referral; // referral => referrer
    mapping(address => uint256) public referralEarned; // for stats

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event RewardPaid(address indexed user, uint256 amount);

    constructor(
        IBSHARE _baseShare,
        address _feeAddress,
        address _devAddress,
        uint256 _feePercent,
        uint256 _devPercent,
        uint256 _sharesPerSecond,
        uint256 _poolStartTime
    ) {
        require(block.timestamp < _poolStartTime, "BaseShareRewardPool: late");
        require(
            _feeAddress != address(0) &&
                _devAddress != address(0) &&
                address(_baseShare) != address(0),
            "BaseShareRewardPool: Zero address not allowed"
        );
        require(
            _devPercent <= 2000 && _feePercent <= 2000,
            "BaseShareRewardPool: Invalid percentages"
        );
        baseShare = _baseShare;
        feeAddress = _feeAddress;
        devAddress = _devAddress;
        feePercent = _feePercent;
        devPercent = _devPercent;
        sharesPerSecond = _sharesPerSecond;
        poolStartTime = _poolStartTime;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool
    function add(
        uint256 _allocPoint,
        IERC20 _token,
        bool _withUpdate,
        uint256 _lastRewardTime,
        uint16 _depositFeeBP,
        uint16 _withdrawFeeBP,
        IGauge _gauge
    ) external onlyOwner {
        IPool pool_lp = IPool(address(_token));
        IERC20 token0 = IERC20(pool_lp.token0());
        IERC20 token1 = IERC20(pool_lp.token1());
        require(
            address(token0) != address(0) && address(token1) != address(0),
            "BaseShareRewardPool: Only LP tokens "
        );
        require(
            Address.isContract(address(_token)),
            "BaseShareRewardPool: LP token must be a valid contract"
        );
        if (address(_gauge) != address(0)) {
            require(
                aeroVoter.isGauge(address(_gauge)),
                "BaseShareRewardPool: Gauge is not valid"
            );
            IERC20 stakingToken = IERC20(_gauge.stakingToken());
            require(
                _token == stakingToken,
                "BaseShareRewardPool: Incorrect gauge!"
            );
        }
        require(
            _depositFeeBP <= 400 && _withdrawFeeBP <= 400,
            "BaseShareRewardPool: Invalid deposit or withdraw fee basis points"
        );
        require(
            !lpTokens.contains(address(_token)),
            "BaseShareRewardPool: LP already added"
        );

        if (_withUpdate) {
            massUpdatePools();
        }

        if (block.timestamp < poolStartTime) {
            // chef is sleeping
            if (_lastRewardTime < poolStartTime) {
                _lastRewardTime = poolStartTime;
            }
        } else {
            // chef is cooking
            if (_lastRewardTime < block.timestamp) {
                _lastRewardTime = block.timestamp;
            }
        }
        bool _isStarted = (block.timestamp >= poolStartTime) &&
            (block.timestamp >= _lastRewardTime);
        poolInfo.push(
            PoolInfo({
                token: _token,
                allocPoint: _allocPoint,
                lastRewardTime: _lastRewardTime,
                accTokensPerShare: 0,
                isStarted: _isStarted,
                depositFeeBP: _depositFeeBP,
                withdrawFeeBP: _withdrawFeeBP,
                gauge: _gauge,
                lpBalance: 0
            })
        );
        if (_isStarted) {
            totalAllocPoint = totalAllocPoint.add(_allocPoint);
        }

        lpTokens.add(address(_token));
    }

    // Update the given pool's baseShare allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        uint16 _depositFeeBP,
        uint16 _withdrawFeeBP
    ) external onlyOwner {
        require(
            _depositFeeBP <= 400 && _withdrawFeeBP <= 400,
            "BaseShareRewardPool: Invalid deposit or withdraw fee basis points"
        );
        massUpdatePools();
        PoolInfo storage pool = poolInfo[_pid];
        if (pool.isStarted) {
            totalAllocPoint = totalAllocPoint.sub(pool.allocPoint).add(
                _allocPoint
            );
        }
        pool.allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
        poolInfo[_pid].withdrawFeeBP = _withdrawFeeBP;
    }

    // Return accumulate rewards over the given _from to _to block.
    function getMultiplier(
        uint256 _from,
        uint256 _to
    ) public view returns (uint256) {
        if (_from >= _to) return 0;
        if (_to <= poolStartTime) return 0;
        if (_from >= poolStartTime) {
            return _to.sub(_from);
        } else {
            return _to.sub(poolStartTime);
        }
    }

    // View function to see pending BaseShare on frontend.
    function pendingShare(
        uint256 _pid,
        address _user
    ) public view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accTokensPerShare = pool.accTokensPerShare;
        uint256 tokenSupply = pool.lpBalance;
        if (block.timestamp > pool.lastRewardTime && tokenSupply != 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardTime,
                block.timestamp
            );
            uint256 lpPercent = 10000 - devPercent - feePercent;
            uint256 _generatedReward = multiplier.mul(sharesPerSecond);
            uint256 _baseShareReward = _generatedReward
                .mul(pool.allocPoint)
                .div(totalAllocPoint)
                .mul(lpPercent)
                .div(10000);
            accTokensPerShare = accTokensPerShare.add(
                _baseShareReward.mul(1e18).div(tokenSupply)
            );
        }
        return
            user.amount.mul(accTokensPerShare).div(1e18).sub(user.rewardDebt);
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
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        if (!pool.isStarted) {
            pool.isStarted = true;
            totalAllocPoint = totalAllocPoint.add(pool.allocPoint);
        }
        uint256 tokenSupply = pool.lpBalance;
        if (tokenSupply == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }

        if (totalAllocPoint > 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardTime,
                block.timestamp
            );
            uint256 _generatedReward = multiplier.mul(sharesPerSecond);
            uint256 _baseShareReward = _generatedReward
                .mul(pool.allocPoint)
                .div(totalAllocPoint);
            uint256 lpPercent = 10000 - devPercent - feePercent;
            baseShare.mint(
                devAddress,
                _baseShareReward.mul(devPercent).div(10000)
            );
            baseShare.mint(
                feeAddress,
                _baseShareReward.mul(feePercent).div(10000)
            );
            baseShare.mint(
                address(this),
                _baseShareReward.mul(lpPercent).div(10000)
            );

            pool.accTokensPerShare = pool.accTokensPerShare.add(
                _baseShareReward.mul(1e18).div(tokenSupply).mul(lpPercent).div(
                    10000
                )
            );
        }
        pool.lastRewardTime = block.timestamp;
    }

    function deposit(
        uint256 _pid,
        uint256 _amount,
        address _referrer
    ) external nonReentrant {
        address staker = _msgSender();
        _deposit(_pid, _amount, _referrer, staker);
    }

    function depositOnBehalfOf(
        uint256 _pid,
        uint256 _amount,
        address _referrer,
        address _staker
    ) external nonReentrant {
        _deposit(_pid, _amount, _referrer, _staker);
    }

    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
        _withdraw(_pid, _amount);
    }

    function _deposit(
        uint256 _pid,
        uint256 _amount,
        address _referrer,
        address _staker
    ) private {
        require(
            _referrer != address(0) &&
                _referrer != _staker &&
                _referrer != address(this),
            "BaseShareRewardPool: Invalid referrer"
        );

        if (referral[_staker] == address(0)) {
            referral[_staker] = _referrer;
        } else {
            _referrer = referral[_staker];
        }

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_staker];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 _pending = user
                .amount
                .mul(pool.accTokensPerShare)
                .div(1e18)
                .sub(user.rewardDebt);
            if (_pending > 0) {
                uint256 referralAmount = ((_pending) * referralRate) / 10000;
                if (referralAmount > 0) {
                    referralEarned[_referrer] =
                        referralEarned[_referrer] +
                        referralAmount;
                    safeBaseShareTransfer(_referrer, referralAmount);
                }
                safeBaseShareTransfer(_staker, _pending);
                emit RewardPaid(_staker, _pending);
            }
        }
        if (_amount > 0) {
            pool.token.safeTransferFrom(_msgSender(), address(this), _amount);
        }
        if (pool.depositFeeBP > 0) {
            uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);
            pool.token.safeTransfer(feeAddress, depositFee);
            user.amount = user.amount.add(_amount).sub(depositFee);
            pool.lpBalance = pool.lpBalance.add(_amount).sub(depositFee);
        } else {
            user.amount = user.amount.add(_amount);
            pool.lpBalance = pool.lpBalance.add(_amount);
        }

        user.rewardDebt = user.amount.mul(pool.accTokensPerShare).div(1e18);
        if (address(pool.gauge) != address(0)) {
            uint256 toDeposit = pool.token.balanceOf(address(this));
            address _gauge = address(pool.gauge);
            pool.token.approve(_gauge, toDeposit);
            pool.gauge.deposit(toDeposit);
        }
        emit Deposit(_staker, _pid, _amount);
    }

    function _withdraw(uint256 _pid, uint256 _amount) private {
        address _sender = _msgSender();
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_sender];
        require(
            user.amount >= _amount,
            "BaseShareRewardPool: User amount too low"
        );
        updatePool(_pid);
        address referrer = referral[_sender];
        uint256 _pending = user
            .amount
            .mul(pool.accTokensPerShare)
            .div(1e18)
            .sub(user.rewardDebt);

        if (_pending > 0) {
            uint256 referralAmount = ((_pending) * referralRate) / 10000;
            if (referralAmount > 0) {
                referralEarned[referrer] =
                    referralEarned[referrer] +
                    referralAmount;
                safeBaseShareTransfer(referrer, referralAmount);
            }

            safeBaseShareTransfer(_sender, _pending);
            emit RewardPaid(_sender, _pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            if (address(pool.gauge) != address(0)) {
                pool.gauge.withdraw(_amount);
            }
            if (pool.withdrawFeeBP > 0) {
                uint256 withdrawFee = _amount.mul(pool.withdrawFeeBP).div(
                    10000
                );
                pool.token.safeTransfer(feeAddress, withdrawFee);
                pool.token.safeTransfer(_sender, _amount.sub(withdrawFee));
            } else {
                pool.token.safeTransfer(_sender, _amount);
            }
        }
        user.rewardDebt = user.amount.mul(pool.accTokensPerShare).div(1e18);
        pool.lpBalance -= _amount;
        emit Withdraw(_sender, _pid, _amount);
    }

    function setGauge(uint256 _pid, IGauge _gauge) external onlyOwner {
        // this will set a gauge and deposit in it
        PoolInfo storage pool = poolInfo[_pid];
        require(
            address(pool.gauge) == address(0),
            "BaseShareRewardPool: Gauge is already set"
        );
        require(
            aeroVoter.isGauge(address(_gauge)),
            "BaseShareRewardPool: Gauge is not valid"
        );
        IERC20 stakingToken = IERC20(_gauge.stakingToken());
        require(
            pool.token == stakingToken,
            "BaseShareRewardPool: Incorrect gauge!"
        );
        pool.gauge = _gauge;
        uint256 _amount = pool.token.balanceOf(address(this));
        pool.token.approve(address(pool.gauge), _amount);
        _gauge.deposit(_amount);
    }

    function removeGauge(uint256 _pid) external onlyOwner {
        // this will remove the gauge and withdraw LP to shareRewardPool contract
        PoolInfo storage pool = poolInfo[_pid];
        bool isGauge = address(pool.gauge) != address(0);
        require(isGauge, "BaseShareRewardPool: No gauge set");
        uint256 _amount = pool.gauge.balanceOf(address(this));
        pool.gauge.withdraw(_amount);
        pool.gauge = IGauge(address(0));
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];
        bool isGauge = address(pool.gauge) != address(0);
        uint256 _amount = user.amount;
        require(_amount > 0, "BaseShareRewardPool: User has no amount");
        user.amount = 0;
        user.rewardDebt = 0;
        if (isGauge) {
            pool.gauge.withdraw(_amount);
        }
        if (pool.withdrawFeeBP > 0) {
            uint256 withdrawFee = _amount.mul(pool.withdrawFeeBP).div(10000);
            pool.token.safeTransfer(feeAddress, withdrawFee);
            pool.token.safeTransfer(_msgSender(), _amount.sub(withdrawFee));
        } else {
            pool.token.safeTransfer(_msgSender(), _amount);
        }
        pool.lpBalance -= _amount;
        emit EmergencyWithdraw(_msgSender(), _pid, _amount);
    }

    // Safe baseShare transfer function, just in case if rounding error causes pool to not have enough baseShare.
    function safeBaseShareTransfer(address _to, uint256 _amount) internal {
        uint256 _baseShareBal = baseShare.balanceOf(address(this));
        if (_baseShareBal > 0) {
            if (_amount > _baseShareBal) {
                baseShare.safeTransfer(_to, _baseShareBal);
            } else {
                baseShare.safeTransfer(_to, _amount);
            }
        }
    }

    function getExternalReward(uint256 _pid) external onlyOwner {
        PoolInfo storage pool = poolInfo[_pid];
        bool isGauge = address(pool.gauge) != address(0);
        require(isGauge, "BaseShareRewardPool: No gauge set");
        IERC20 rewardToken = IERC20(pool.gauge.rewardToken());
        pool.gauge.getReward(address(this));
        uint256 amountToSend = rewardToken.balanceOf(address(this));
        rewardToken.safeTransfer(feeAddress, amountToSend);
    }

    function getExternalSwapFees(
        uint256 _pid,
        bool withClaim
    ) external onlyOwner {
        PoolInfo storage pool = poolInfo[_pid];
        IPool pool_lp = IPool(address(pool.token));
        IERC20 token0 = IERC20(pool_lp.token0());
        IERC20 token1 = IERC20(pool_lp.token1());
        require(
            token0 != pool.token && token1 != pool.token,
            "BaseShareRewardPool: Wrong pool.token"
        );
        if (withClaim) {
            pool_lp.claimFees();
        }
        uint256 balanceToken0 = token0.balanceOf(address(this));
        uint256 balanceToken1 = token1.balanceOf(address(this));
        token0.safeTransfer(feeAddress, balanceToken0);
        token1.safeTransfer(feeAddress, balanceToken1);
    }

    function setFeeAddress(address _feeAddress) external onlyOwner {
        require(
            _feeAddress != address(0),
            "BaseShareRewardPool: Zero address not allowed"
        );
        feeAddress = _feeAddress;
    }

    function setFeePercent(uint256 _feePercent) external onlyOwner {
        require(
            _feePercent <= 2000,
            "BaseShareRewardPool: Zero address not allowed"
        );
        feePercent = _feePercent;
    }

    function setDevAddress(address _devAddress) external onlyOwner {
        require(
            _devAddress != address(0),
            "BaseShareRewardPool: Invalid percentages"
        );
        devAddress = _devAddress;
    }

    function setDevPercent(uint256 _devPercent) external onlyOwner {
        require(
            _devPercent <= 2000,
            "BaseShareRewardPool: Zero address not allowed"
        );
        devPercent = _devPercent;
    }

    function setReferralRate(uint256 _referralRate) external onlyOwner {
        require(_referralRate <= 500, "BaseShareRewardPool: Too high");
        referralRate = _referralRate;
    }

    function updateEmissionRate(uint256 _sharesPerSecond) public onlyOwner {
        massUpdatePools();
        sharesPerSecond = _sharesPerSecond;
    }

    function getPoolView(uint256 pid) public view returns (PoolView memory) {
        require(pid < poolInfo.length, "BaseShareRewardPool: pid out of range");
        PoolInfo memory pool = poolInfo[pid];
        uint256 lpPercent = 10000 - devPercent - feePercent;
        uint256 rewardsPerSecond = pool
            .allocPoint
            .mul(sharesPerSecond)
            .div(totalAllocPoint)
            .mul(lpPercent)
            .div(10000);
        return
            PoolView({
                pid: pid,
                token: address(pool.token),
                allocPoint: pool.allocPoint,
                lastRewardTime: pool.lastRewardTime,
                depositFeeBP: pool.depositFeeBP,
                withdrawFeeBP: pool.withdrawFeeBP,
                accTokensPerShare: pool.accTokensPerShare,
                isStarted: pool.isStarted,
                gauge: address(pool.gauge),
                lpBalance: pool.lpBalance,
                rewardsPerSecond: rewardsPerSecond
            });
    }

    function getAllPoolViews() external view returns (PoolView[] memory) {
        PoolView[] memory views = new PoolView[](poolInfo.length);
        for (uint256 i = 0; i < poolInfo.length; i++) {
            views[i] = getPoolView(i);
        }
        return views;
    }

    function getUserView(
        uint256 pid,
        address account
    ) public view returns (UserView memory) {
        PoolInfo memory pool = poolInfo[pid];
        UserInfo memory user = userInfo[pid][account];
        uint256 unclaimedRewards = pendingShare(pid, account);
        uint256 lpBalance = pool.token.balanceOf(account);
        return
            UserView({
                pid: pid,
                stakedAmount: user.amount,
                unclaimedRewards: unclaimedRewards,
                lpBalance: lpBalance,
                allowance: pool.token.allowance(account, address(this))
            });
    }

    function getUserViews(
        address account
    ) external view returns (UserView[] memory) {
        UserView[] memory views = new UserView[](poolInfo.length);
        for (uint256 i = 0; i < poolInfo.length; i++) {
            views[i] = getUserView(i, account);
        }
        return views;
    }
}
