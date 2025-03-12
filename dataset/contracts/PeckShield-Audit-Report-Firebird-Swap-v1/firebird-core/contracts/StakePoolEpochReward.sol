// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "./interfaces/IEpochController.sol";
import "./interfaces/IStakePoolEpochReward.sol";
import "./interfaces/IStakePoolController.sol";
import "./interfaces/IStakePoolRewardRebaser.sol";
import "./interfaces/IStakePoolRewardMultiplier.sol";
import "./interfaces/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import './libraries/TransferHelper.sol';
import "./interfaces/IStakePoolRewardFund.sol";

// This implements BPool contract, and allows for generalized staking, yield farming (by epoch), and token distribution.
contract StakePoolEpochReward is IStakePoolEpochReward {
    using SafeMath for uint;
    uint public override version;

    /* ========== DATA STRUCTURES ========== */

    struct UserInfo {
        uint256 amount;
        uint256 lastSnapshotIndex;
        uint256 rewardEarned;
        uint256 epochTimerStart;
    }

    struct Snapshot {
        uint256 time;
        uint256 rewardReceived;
        uint256 rewardPerShare;
    }

    /* ========== STATE VARIABLES ========== */

    address public override epochController;
    address public override rewardToken;

    uint256 public withdrawLockupEpochs;
    uint256 public rewardLockupEpochs;

    mapping(address => UserInfo) public userInfo;
    Snapshot[] public snapshotHistory;

    address public override stakeToken;
    address public override rewardFund;
    address public timelock;
    address public controller;

    uint public balance;
    uint private _unlocked = 1;
    bool private _initialized = false;
    uint256 public constant BLOCKS_PER_DAY = 28800;

    constructor(address _controller, uint _version) public {
        controller = _controller;
        timelock = msg.sender;
        version = _version;
        Snapshot memory genesisSnapshot = Snapshot({time : block.number, rewardReceived : 0, rewardPerShare : 0});
        snapshotHistory.push(genesisSnapshot);
    }

    modifier lock() {
        require(_unlocked == 1, 'StakePoolEpochReward: LOCKED');
        _unlocked = 0;
        _;
        _unlocked = 1;
    }

    modifier onlyTimeLock() {
        require(msg.sender == timelock, "StakePoolEpochReward: !timelock");
        _;
    }

    modifier onlyEpochController() {
        require(msg.sender == epochController, "StakePoolEpochReward: !epochController");
        _;
    }

    modifier updateReward(address _account) {
        if (_account != address(0)) {
            UserInfo storage user = userInfo[_account];
            user.rewardEarned = earned(_account);
            user.lastSnapshotIndex = latestSnapshotIndex();
        }
        _;
    }

    // called once by the factory at time of deployment
    function initialize(address _stakeToken, address _rewardFund, address _timelock, address _epochController, address _rewardToken,  uint256 _withdrawLockupEpochs, uint256 _rewardLockupEpochs) external {
        require(_initialized == false, "StakePoolEpochReward: Initialize must be false.");
        stakeToken = _stakeToken;
        rewardToken = _rewardToken;
        rewardFund = _rewardFund;
        setEpochController(_epochController);
        setLockUp(_withdrawLockupEpochs, _rewardLockupEpochs);
        timelock = _timelock;
        _initialized = true;
    }

    /* ========== GOVERNANCE ========== */

    function setEpochController(address _epochController) public override lock onlyTimeLock {
        epochController = _epochController;
        epoch();
        nextEpochPoint();
        nextEpochLength();
        nextEpochAllocatedReward();
    }

    function setLockUp(uint256 _withdrawLockupEpochs, uint256 _rewardLockupEpochs) public override lock onlyTimeLock {
        require(_withdrawLockupEpochs >= _rewardLockupEpochs && _withdrawLockupEpochs <= 56, "_withdrawLockupEpochs: out of range"); // <= 2 week
        withdrawLockupEpochs = _withdrawLockupEpochs;
        rewardLockupEpochs = _rewardLockupEpochs;
    }

    function allocateReward(uint256 _amount) external override lock onlyEpochController {
        require(_amount > 0, "StakePoolEpochReward: Cannot allocate 0");
        uint256 _before = IERC20(rewardToken).balanceOf(address(rewardFund));
        TransferHelper.safeTransferFrom(rewardToken, msg.sender, rewardFund, _amount);
        if (balance > 0) {
            uint256 _after = IERC20(rewardToken).balanceOf(address(rewardFund));
            _amount = _after.sub(_before);

            // Create & add new snapshot
            uint256 _prevRPS = getLatestSnapshot().rewardPerShare;
            uint256 _nextRPS = _prevRPS.add(_amount.mul(1e18).div(balance));

            Snapshot memory _newSnapshot = Snapshot({
                time: block.number,
                rewardReceived: _amount,
                rewardPerShare: _nextRPS
            });
            emit AllocateReward(block.number, _amount);
            snapshotHistory.push(_newSnapshot);
        }
    }

    function allowRecoverRewardToken(address _token) external view override returns (bool) {
        if (rewardToken == _token) {
            // do not allow to drain reward token if less than 1 week after LatestSnapshot
            if (block.number < (getLatestSnapshot().time + (BLOCKS_PER_DAY * 7))) {
                return false;
            }
        }
        return true;
    }

    // =========== Epoch getters

    function epoch() public override view returns (uint256) {
        return IEpochController(epochController).epoch();
    }

    function nextEpochPoint() public override view returns (uint256) {
        return IEpochController(epochController).nextEpochPoint();
    }

    function nextEpochLength() public override view returns (uint256) {
        return IEpochController(epochController).nextEpochLength();
    }

    function nextEpochAllocatedReward() public override view returns (uint256) {
        return IEpochController(epochController).nextEpochAllocatedReward(address(this));
    }

    // =========== Snapshot getters

    function latestSnapshotIndex() public view returns (uint256) {
        return snapshotHistory.length.sub(1);
    }

    function getLatestSnapshot() internal view returns (Snapshot memory) {
        return snapshotHistory[latestSnapshotIndex()];
    }

    function getLastSnapshotIndexOf(address _account) public view returns (uint256) {
        return userInfo[_account].lastSnapshotIndex;
    }

    function getLastSnapshotOf(address _account) internal view returns (Snapshot memory) {
        return snapshotHistory[getLastSnapshotIndexOf(_account)];
    }

    // =========== _account getters

    function rewardPerShare() public view returns (uint256) {
        return getLatestSnapshot().rewardPerShare;
    }

    function earned(address _account) public override view returns (uint256) {
        uint256 latestRPS = getLatestSnapshot().rewardPerShare;
        uint256 storedRPS = getLastSnapshotOf(_account).rewardPerShare;

        UserInfo memory user = userInfo[_account];
        return user.amount.mul(latestRPS.sub(storedRPS)).div(1e18).add(user.rewardEarned);
    }

    function canWithdraw(address _account) external view returns (bool) {
        return userInfo[_account].epochTimerStart.add(withdrawLockupEpochs) <= epoch();
    }

    function canClaimReward(address _account) external view returns (bool) {
        return userInfo[_account].epochTimerStart.add(rewardLockupEpochs) <= epoch();
    }

    function unlockWithdrawEpoch(address _account) public override view returns (uint) {
        return userInfo[_account].epochTimerStart.add(withdrawLockupEpochs);
    }

    function unlockRewardEpoch(address _account) public override view returns (uint) {
        return userInfo[_account].epochTimerStart.add(rewardLockupEpochs);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint _amount) external lock override {
        TransferHelper.safeTransferFrom(stakeToken, msg.sender, address(this), _amount);
        _stakeFor(msg.sender);
    }

    function stakeFor(address _account) external lock override {
        require(IStakePoolController(controller).isWhitelistStakingFor(msg.sender), "StakePoolEpochReward: Invalid sender");
        _stakeFor(_account);
    }

    function _stakeFor(address _account) internal {
        uint _amount = IERC20(stakeToken).balanceOf(address(this)).sub(balance);
        require(_amount > 0, "StakePoolEpochReward: Invalid balance");
        balance = balance.add(_amount);
        UserInfo storage user = userInfo[_account];
        user.epochTimerStart = epoch(); // reset timer
        user.amount = user.amount.add(_amount);
        emit Deposit(_account, _amount);
    }

    function removeStakeInternal(uint _amount) internal {
        UserInfo storage user = userInfo[msg.sender];
        uint256 _epoch = epoch();
        require(user.epochTimerStart.add(withdrawLockupEpochs) <= _epoch, "StakePoolEpochReward: still in withdraw lockup");
        require(user.amount >= _amount, "StakePoolEpochReward: invalid withdraw amount");
        _claimReward(false);
        balance = balance.sub(_amount);
        user.epochTimerStart = _epoch; // reset timer
        user.amount = user.amount.sub(_amount);
    }

    function withdraw(uint _amount) public lock override {
        removeStakeInternal(_amount);
        TransferHelper.safeTransfer(stakeToken, msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }

    function exit() external {
        withdraw(userInfo[msg.sender].amount);
    }

    function _claimReward(bool _lockChecked) internal updateReward(msg.sender) {
        UserInfo storage user = userInfo[msg.sender];
        uint256 _reward = user.rewardEarned;
        if (_reward > 0) {
            if (_lockChecked) {
                uint256 _epoch = epoch();
                require(user.epochTimerStart.add(rewardLockupEpochs) <= _epoch, "StakePoolEpochReward: still in reward lockup");
                user.epochTimerStart = _epoch; // reset timer
            }
            user.rewardEarned = 0;
            // Safe reward transfer, just in case if rounding error causes pool to not have enough reward amount
            uint256 _rewardBalance = IERC20(rewardToken).balanceOf(rewardFund);
            uint256 _paidAmount = _rewardBalance > _reward ? _reward : _rewardBalance;
            IStakePoolRewardFund(rewardFund).safeTransfer(rewardToken, msg.sender, _paidAmount);
            emit PayRewardPool(0, rewardToken, msg.sender, _reward, _reward, _paidAmount);
        }
    }

    function claimReward() public override {
        _claimReward(true);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() external lock override {
        require(IStakePoolController(controller).isAllowEmergencyWithdrawStakePool(address(this)),"StakePoolEpochReward: Not allow emergencyWithdraw");
        UserInfo storage user = userInfo[msg.sender];
        uint amount = user.amount;
        balance = balance.sub(amount);
        user.amount = 0;
        user.rewardEarned = 0;
        TransferHelper.safeTransfer(stakeToken, msg.sender, amount);
    }
}
