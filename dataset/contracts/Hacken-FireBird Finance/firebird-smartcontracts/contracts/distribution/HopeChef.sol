// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";

import "../interfaces/ICappedMintableBurnableERC20.sol";
import "../interfaces/IReferral.sol";
import "../interfaces/IRewarder.sol";

contract HopeChef is OwnableUpgradeSafe {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // flags
    uint256 private _locked = 0;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of HOPEs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accHopePerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accHopePerShare` (and `lastRewardTime`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. HOPEs to distribute per block.
        uint256 lastRewardTime; // Last timestamp that HOPEs distribution occurs.
        uint256 accHopePerShare; // Accumulated HOPEs per share, times 1e18. See below.
        bool isStarted; // if lastRewardTime has passed
        uint256 startTime;
    }

    address public hope = address(0x7A5dc8A09c831251026302C93A778748dd48b4DF);

    // HOPE tokens created per second.
    uint256 public totalRewardPerSecond;
    uint256 public rewardPerSecond;

    uint256 public reservePercent;
    address public reserveFund;

    uint256 public devPercent;
    address public devFund;

    // Info of each pool.
    PoolInfo[] public poolInfo;

    IRewarder[] public rewarder;

    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;

    // The timestamp when HOPE mining starts.
    uint256 public startTime;

    address public rewardReferral;
    uint256 public commissionPercent;

    uint256 public nextHalvingTime;
    uint256 public rewardHalvingRate;
    bool public halvingChecked;

    mapping(uint256 => mapping(address => uint256)) public userLastDepositTime;
    mapping(uint256 => uint256) public poolLockedTime;
    mapping(uint256 => uint256) public poolEarlyWithdrawFee;

    /* =================== Added variables (need to keep orders for proxy to work) =================== */
    // ...

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event WithdrawFee(address indexed user, uint256 indexed pid, uint256 amount, uint256 fee);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount);
    event Commission(address indexed user, address indexed referrer, uint256 amount);

    event LogPoolAddition(uint256 indexed pid, uint256 allocPoint, IERC20 indexed lpToken, IRewarder indexed rewarder);
    event LogSetPool(uint256 indexed pid, uint256 allocPoint, IRewarder indexed rewarder);
    event LogUpdatePool(uint256 indexed pid, uint256 lastRewardTime, uint256 lpSupply, uint256 accHopePerShare);
    event LogRewardPerSecond(uint256 rewardPerSecond);

    modifier lock() {
        require(_locked == 0, "LOCKED");
        _locked = 1;
        _;
        _locked = 0;
    }

    modifier onlyDev() {
        require(devFund == msg.sender || owner() == msg.sender, "!dev");
        _;
    }

    modifier checkHalving() {
        if (halvingChecked) {
            halvingChecked = false;
            if (now >= nextHalvingTime) {
                massUpdatePools();
                uint256 _totalRewardPerSecond = totalRewardPerSecond.mul(rewardHalvingRate).div(10000); // x96% (4% decreased every 4-weeks)
                totalRewardPerSecond = _totalRewardPerSecond;
                rewardPerSecond = _totalRewardPerSecond.sub(_totalRewardPerSecond.mul(reservePercent.add(devPercent)).div(10000));
                nextHalvingTime = nextHalvingTime.add(4 weeks);
                emit LogRewardPerSecond(rewardPerSecond);
            }
            halvingChecked = true;
        }
        _;
    }

    function initialize(address _hope, uint256 _totalRewardPerSecond, uint256 _startTime) public initializer {
        OwnableUpgradeSafe.__Ownable_init();

        hope = _hope;

        reservePercent = 1500; // 15%
        devPercent = 1500; // 15%
        reserveFund = _msgSender();
        devFund = _msgSender();

        totalRewardPerSecond = _totalRewardPerSecond;
        rewardPerSecond = _totalRewardPerSecond.sub(_totalRewardPerSecond.mul(reservePercent.add(devPercent)).div(10000));
        startTime = _startTime;
        nextHalvingTime = _startTime.add(4 weeks);

        commissionPercent = 100; // 1%
        rewardHalvingRate = 9600; // 96%
        halvingChecked = true;

        // staking pool
        poolInfo.push(
            PoolInfo({
            lpToken : IERC20(_hope),
            allocPoint : 0,
            lastRewardTime : _startTime,
            accHopePerShare : 0,
            isStarted : false,
            startTime : _startTime
            })
        );

        rewarder.push(IRewarder(address(0x0)));

        emit LogRewardPerSecond(rewardPerSecond);
    }

    function resetStartTime(uint256 _startTime) external onlyOwner {
        require(startTime > now && _startTime > now, "late");
        startTime = _startTime;
        nextHalvingTime = _startTime.add(4 weeks);
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function setTotalRewardPerSecond(uint256 _totalRewardPerSecond) external onlyOwner {
        require(_totalRewardPerSecond <= 10 ether, "insane high rate");
        massUpdatePools();
        totalRewardPerSecond = _totalRewardPerSecond;
        rewardPerSecond = _totalRewardPerSecond.sub(_totalRewardPerSecond.mul(reservePercent.add(devPercent)).div(10000));
        emit LogRewardPerSecond(rewardPerSecond);
    }

    function setHalvingChecked(bool _halvingChecked) external onlyOwner {
        halvingChecked = _halvingChecked;
    }

    function setRewardReferral(address _rewardReferral) external onlyOwner {
        rewardReferral = _rewardReferral;
    }

    function setRewardHalvingRate(uint256 _rewardHalvingRate) external onlyOwner {
        require(_rewardHalvingRate >= 9000, "below 90%");
        massUpdatePools();
        rewardHalvingRate = _rewardHalvingRate;
    }

    function setCommissionPercent(uint256 _commissionPercent) external onlyOwner {
        require(_commissionPercent <= 500, "exceed 5%");
        commissionPercent = _commissionPercent;
    }

    function checkPoolDuplicate(IERC20 _lpToken) internal view {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            require(poolInfo[pid].lpToken != _lpToken, "add: existing pool?");
        }
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, IERC20 _lpToken, IRewarder _rewarder, uint256 _lastRewardTime) public onlyOwner {
        checkPoolDuplicate(_lpToken);
        massUpdatePools();
        if (now < startTime) {
            // chef is sleeping
            if (_lastRewardTime == 0) {
                _lastRewardTime = startTime;
            } else {
                if (_lastRewardTime < startTime) {
                    _lastRewardTime = startTime;
                }
            }
        } else {
            // chef is cooking
            if (_lastRewardTime == 0 || _lastRewardTime < now) {
                _lastRewardTime = now;
            }
        }
        bool _isStarted = (_lastRewardTime <= startTime) || (_lastRewardTime <= now);
        poolInfo.push(
            PoolInfo({
            lpToken : _lpToken,
            allocPoint : _allocPoint,
            lastRewardTime : _lastRewardTime,
            accHopePerShare : 0,
            isStarted : _isStarted,
            startTime : _lastRewardTime
            })
        );
        rewarder.push(_rewarder);
        if (_isStarted) {
            totalAllocPoint = totalAllocPoint.add(_allocPoint);
        }
        emit LogPoolAddition(poolInfo.length.sub(1), _allocPoint, _lpToken, _rewarder);
    }

    // Update the given pool's HOPE allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, IRewarder _rewarder) public onlyOwner {
        massUpdatePools();
        PoolInfo storage pool = poolInfo[_pid];
        if (pool.isStarted) {
            totalAllocPoint = totalAllocPoint.sub(pool.allocPoint).add(
                _allocPoint
            );
        }
        pool.allocPoint = _allocPoint;
        if (address(_rewarder) != address(0)) {
            rewarder[_pid] = _rewarder;
        }
        emit LogSetPool(_pid, _allocPoint, _rewarder);
    }

    function setReservePercent(uint256 _reservePercent) public onlyOwner {
        require(_reservePercent <= 2500, "_reservePercent is too high"); // <= 25%
        massUpdatePools();
        reservePercent = _reservePercent;
        rewardPerSecond = totalRewardPerSecond.sub(totalRewardPerSecond.mul(_reservePercent.add(devPercent)).div(10000));
    }

    function setReserveFund(address _reserveFund) public onlyOwner {
        require(_reserveFund != address(0), "zero");
        reserveFund = _reserveFund;
    }

    function setDevPercent(uint256 _devPercent) public onlyOwner {
        require(_devPercent <= 2500, "_devPercent is too high"); // <= 25%
        massUpdatePools();
        devPercent = _devPercent;
        rewardPerSecond = totalRewardPerSecond.sub(totalRewardPerSecond.mul(reservePercent.add(_devPercent)).div(10000));
    }

    function setDevFund(address _devFund) public onlyDev {
        require(_devFund != address(0), "zero");
        devFund = _devFund;
    }

    function setPoolLockedTimeAndFee(uint256 _pid, uint256 _lockedTime, uint256 _earlyWithdrawFee) public onlyOwner {
        require(_lockedTime <= 30 days, "locked time is too long");
        require(_earlyWithdrawFee <= 1000, "early withdraw fee is too high"); // <=10%
        poolLockedTime[_pid] = _lockedTime;
        poolEarlyWithdrawFee[_pid] = _earlyWithdrawFee;
    }

    // View function to see pending HOPEs on frontend.
    function pendingReward(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accHopePerShare = pool.accHopePerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (now > pool.lastRewardTime && lpSupply != 0) {
            uint256 _time = now.sub(pool.lastRewardTime);
            if (totalAllocPoint > 0) {
                uint256 _hopeReward = _time.mul(rewardPerSecond).mul(pool.allocPoint).div(totalAllocPoint);
                accHopePerShare = accHopePerShare.add(_hopeReward.mul(1e18).div(lpSupply));
            }
        }
        return user.amount.mul(accHopePerShare).div(1e18).sub(user.rewardDebt);
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
        if (now <= pool.lastRewardTime) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardTime = now;
            return;
        }
        if (!pool.isStarted) {
            pool.isStarted = true;
            totalAllocPoint = totalAllocPoint.add(pool.allocPoint);
        }
        if (totalAllocPoint > 0) {
            uint256 _time = now.sub(pool.lastRewardTime);
            uint256 _hopeReward = _time.mul(rewardPerSecond).mul(pool.allocPoint).div(totalAllocPoint);
            pool.accHopePerShare = pool.accHopePerShare.add(_hopeReward.mul(1e18).div(lpSupply));
        }
        pool.lastRewardTime = now;
        emit LogUpdatePool(_pid, pool.lastRewardTime, lpSupply, pool.accHopePerShare);
    }

    function _harvestReward(uint256 _pid, address _account) internal {
        UserInfo storage user = userInfo[_pid][_account];
        uint256 _claimableAmount = 0;
        if (user.amount > 0) {
            PoolInfo storage pool = poolInfo[_pid];
            _claimableAmount = user.amount.mul(pool.accHopePerShare).div(1e18).sub(user.rewardDebt);
            if (_claimableAmount > 0) {
                _topupReserveAndDevFund(_claimableAmount);

                _safeHopeMint(address(this), _claimableAmount);
                emit Harvest(_account, _pid, _claimableAmount);

                uint256 _commission = _claimableAmount.mul(commissionPercent).div(10000); // 1%
                _sendCommission(msg.sender, _commission);
                _claimableAmount = _claimableAmount.sub(_commission);

                _safeHopeTransfer(_account, _claimableAmount);
            }
        }
        IRewarder _rewarder = rewarder[_pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onHopeReward(_pid, msg.sender, _account, _claimableAmount, user.amount);
        }
    }

    function _sendCommission(address _account, uint256 _commission) internal {
        address _referrer = address(0);
        if (rewardReferral != address(0)) {
            _referrer = IReferral(rewardReferral).refOf(_account);
        }
        if (_referrer != address(0)) {
            // send commission to referrer
            _safeHopeTransfer(_referrer, _commission);
            emit Commission(_account, _referrer, _commission);
        } else {
            // or burn
            _safeHopeBurn(_commission);
            emit Commission(_account, address(0), _commission);
        }
        IReferral(rewardReferral).onHopeCommission(_referrer, _account, _commission);
    }

    function deposit(uint256 _pid, uint256 _amount) public {
        depositWithRef(_pid, _amount, address(0));
    }

    function depositWithRef(uint256 _pid, uint256 _amount, address _referrer) public lock checkHalving {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (rewardReferral != address(0) && _referrer != address(0)) {
            IReferral(rewardReferral).set(_referrer, msg.sender);
        }
        _harvestReward(_pid, msg.sender);
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(msg.sender, address(this), _amount);
            user.amount = user.amount.add(_amount);
            userLastDepositTime[_pid][msg.sender] = now;
        }
        user.rewardDebt = user.amount.mul(pool.accHopePerShare).div(1e18);
        emit Deposit(msg.sender, _pid, _amount);
    }

    function unfrozenDepositTime(uint256 _pid, address _account) public view returns (uint256) {
        return userLastDepositTime[_pid][_account].add(poolLockedTime[_pid]);
    }

    function withdraw(uint256 _pid, uint256 _amount) public lock checkHalving {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        _harvestReward(_pid, msg.sender);
        if (_amount > 0) {
            uint256 _sentAmount = _amount;
            if (reserveFund != address(0) && now < unfrozenDepositTime(_pid, msg.sender)) {
                uint256 _earlyWithdrawFee = poolEarlyWithdrawFee[_pid];
                if (_earlyWithdrawFee > 0) {
                    _earlyWithdrawFee = _amount.mul(_earlyWithdrawFee).div(10000);
                    _sentAmount = _sentAmount.sub(_earlyWithdrawFee);
                    pool.lpToken.safeTransfer(reserveFund, _earlyWithdrawFee);
                    emit WithdrawFee(msg.sender, _pid, _amount, _earlyWithdrawFee);
                }
            }

            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(msg.sender, _sentAmount);
        }
        user.rewardDebt = user.amount.mul(pool.accHopePerShare).div(1e18);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    function withdrawAll(uint256 _pid) external {
        withdraw(_pid, userInfo[_pid][msg.sender].amount);
    }

    function harvestAllRewards() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            if (userInfo[pid][msg.sender].amount > 0) {
                withdraw(pid, 0);
            }
        }
    }

    function harvestAndRestake() external {
        harvestAllRewards();
        uint256 _hopeBal = IERC20(hope).balanceOf(msg.sender);
        if (_hopeBal > 0) {
            enterStaking(_hopeBal);
        }
    }

    function enterStaking(uint256 _amount) public {
        deposit(0, _amount);
    }

    function enterStakingWithRef(uint256 _amount, address _referrer) external {
        depositWithRef(0, _amount, _referrer);
    }

    function leaveStaking(uint256 _amount) external {
        withdraw(0, _amount);
    }

    function _safeHopeTransfer(address _to, uint256 _amount) internal {
        uint256 _hopeBal = IERC20(hope).balanceOf(address(this));
        if (_hopeBal > 0) {
            if (_amount > _hopeBal) {
                IERC20(hope).safeTransfer(_to, _hopeBal);
            } else {
                IERC20(hope).safeTransfer(_to, _amount);
            }
        }
    }

    function _safeHopeMint(address _to, uint256 _amount) internal {
        address _hope = hope;
        if (ICappedMintableBurnableERC20(_hope).minterCap(address(this)) >= _amount && _to != address(0)) {
            uint256 _totalSupply = IERC20(_hope).totalSupply();
            uint256 _cap = ICappedMintableBurnableERC20(_hope).cap();
            uint256 _mintAmount = (_totalSupply.add(_amount) <= _cap) ? _amount : _cap.sub(_totalSupply);
            if (_mintAmount > 0) {
                ICappedMintableBurnableERC20(_hope).mint(_to, _mintAmount);
            }
        }
    }

    function _safeHopeBurn(uint256 _amount) internal {
        uint256 _hopeBal = IERC20(hope).balanceOf(address(this));
        if (_hopeBal > 0) {
            if (_amount > _hopeBal) {
                ICappedMintableBurnableERC20(hope).burn(_hopeBal);
            } else {
                ICappedMintableBurnableERC20(hope).burn(_amount);
            }
        }
    }

    function _topupReserveAndDevFund(uint256 _claimableAmount) internal {
        address _hope = hope;
        uint256 _totalAmount = _claimableAmount.mul(totalRewardPerSecond).div(rewardPerSecond);
        uint256 _reserveFundAmount = _totalAmount.mul(reservePercent).div(10000);
        uint256 _devFundAmount = _totalAmount.mul(devPercent).div(10000);
        uint256 _totalMintAmount = _reserveFundAmount.add(_devFundAmount);
        if (IERC20(_hope).totalSupply().add(_totalMintAmount) <= ICappedMintableBurnableERC20(_hope).cap()
        && ICappedMintableBurnableERC20(_hope).minterCap(address(this)) >= _totalMintAmount) {
            ICappedMintableBurnableERC20(_hope).mint(reserveFund, _reserveFundAmount);
            ICappedMintableBurnableERC20(_hope).mint(devFund, _devFundAmount);
        }
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external lock checkHalving {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 _amount = user.amount;
        uint256 _sentAmount = _amount;
        user.amount = 0;
        user.rewardDebt = 0;
        IRewarder _rewarder = rewarder[_pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onHopeReward(_pid, msg.sender, msg.sender, 0, 0);
        }
        if (reserveFund != address(0) && now < unfrozenDepositTime(_pid, msg.sender)) {
            uint256 _earlyWithdrawFee = poolEarlyWithdrawFee[_pid];
            if (_earlyWithdrawFee > 0) {
                _earlyWithdrawFee = _amount.mul(_earlyWithdrawFee).div(10000);
                _sentAmount = _sentAmount.sub(_earlyWithdrawFee);
                pool.lpToken.safeTransfer(reserveFund, _earlyWithdrawFee);
                emit WithdrawFee(msg.sender, _pid, _amount, _earlyWithdrawFee);
            }
        }
        pool.lpToken.safeTransfer(address(msg.sender), _sentAmount);
        emit EmergencyWithdraw(msg.sender, _pid, _amount);
    }

    // This function allows governance to take unsupported tokens out of the contract. This is in an effort to make someone whole, should they seriously mess up.
    // There is no guarantee governance will vote to return these. It also allows for removal of airdropped tokens.
    function governanceRecoverUnsupported(IERC20 _token, uint256 _amount, address _to) external onlyOwner {
        // do not allow to drain lpToken
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo storage pool = poolInfo[pid];
            require(_token != pool.lpToken, "pool.lpToken");
        }
        _token.safeTransfer(_to, _amount);
    }
}
