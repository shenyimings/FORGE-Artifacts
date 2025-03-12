// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

import "./library/PauseGuardian.sol";

import "./interface/IdETH.sol";

/**
 * @title Aspida's vault token for staked dETH
 * @dev sdETH is a contract that represents a token for staked dETH.
 * It inherits from Ownable2StepUpgradeable, PauseGuardian, ERC20PermitUpgradeable, and ERC4626Upgradeable.
 * It has several internal variables and events that are used to keep track of the contract's state.
 * It also has several internal functions that are used to update the contract's state.
 */
contract sdETH is Ownable2StepUpgradeable, PauseGuardian, ERC20PermitUpgradeable, ERC4626Upgradeable {
    uint256 internal duration_;
    uint256 internal rewardRate_;
    uint256 internal periodFinish_;
    uint256 internal lastUpdateTime_;

    uint256 internal totalAssets_;

    event SetDuration(uint256 duration);

    event UpdateRewardRate(uint256 rewardRate);
    event UpdatePeriodFinish(uint256 periodFinish);

    event UpdateTotalAssets(uint256 totalAssets);
    event UpdateLastUpdateTime(uint256 lastUpdateTime);

    /**
     * @dev Modifier that updates the reward and checks if a new reward is needed.
     */
    modifier sync() {
        uint256 _timestamp = block.timestamp;
        _updateReward(_timestamp);
        if (_timestamp > periodFinish_) _newReward();
        _;
    }

    /**
     * @notice Only for the implementation contract, as for the proxy pattern,
     *            should call `initialize()` separately.
     * @param _dETH The address of the dETH contract.
     */
    constructor(IERC20Upgradeable _dETH) {
        initialize(_dETH);
    }

    /**
     * @notice Expects to call only once to initialize sdETH.
     * @param _dETH The address of the dETH contract.
     */
    function initialize(IERC20Upgradeable _dETH) public initializer {
        string memory _tokenName = "Aspida Stake Ether";
        string memory _tokenSymbol = "sdETH";
        __Ownable2Step_init();
        __Pausable_init();
        __ERC20_init(_tokenName, _tokenSymbol);
        __ERC20Permit_init(_tokenName);
        __ERC4626_init(_dETH);
        _setDurationInternal(1 weeks);
        _updateReward(block.timestamp);
        _updatePeriodFinish(1 weeks);
    }

    /**
     * @dev Unpause when sdETH is paused.
     */
    function _open() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Pause sdETH.
     */
    function _close() external onlyPauseGuardian {
        _pause();
    }

    /**
     * @dev Adds a pause guardian.
     * @param _pauseGuardian The address of the pause guardian to add.
     */
    function _addPauseGuardian(address _pauseGuardian) external onlyOwner {
        _addPauseGuardianInternal(_pauseGuardian);
    }

    /**
     * @dev Removes a pause guardian.
     * @param _pauseGuardian The address of the pause guardian to remove.
     */
    function _removePauseGuardian(address _pauseGuardian) external onlyOwner {
        _removePauseGuardianInternal(_pauseGuardian);
    }

    /**
     * @dev Sets the duration of the next reward period.
     * @param _duration The duration of the reward period.
     */
    function _setDuration(uint256 _duration) external onlyOwner {
        _setDurationInternal(_duration);
    }

    /**
     * @dev Speeds up the reward distribution over a given duration.
     * @param _reward The amount of the reward to distribute.
     * @param _duration The duration over which to distribute the reward.
     */
    function _speedUpReward(uint256 _reward, uint256 _duration) external onlyOwner sync {
        require(_duration > 0, "_speedUpReward: Invalid duration");
        require(_reward <= _availableReward(), "_speedUpReward: Invalid reward");
        _updateRewardRate(_reward, _duration);
        _updatePeriodFinish(_duration);
    }

    /**
     * @dev Sets the duration of the reward period.
     * @param _duration The duration of the reward period.
     */
    function _setDurationInternal(uint256 _duration) internal {
        require(_duration != duration_ && _duration > 0, "_setDurationInternal: Invalid duration");
        duration_ = _duration;
        emit SetDuration(_duration);
    }

    /**
     * @dev Updates the reward rate.
     * @param _rewardAmount The amount of the reward.
     * @param _duration The duration of the reward period.
     */
    function _updateRewardRate(uint256 _rewardAmount, uint256 _duration) internal {
        uint256 _rewardRate = _rewardAmount / _duration;
        rewardRate_ = _rewardRate;
        emit UpdateRewardRate(_rewardRate);
    }

    /**
     * @dev Updates the period finish time.
     * @param _duration The duration of the reward period.
     */
    function _updatePeriodFinish(uint256 _duration) internal {
        uint256 _periodFinish = block.timestamp + _duration;
        periodFinish_ = _periodFinish;
        emit UpdatePeriodFinish(_periodFinish);
    }

    /**
     * @dev Updates the reward.
     * @param _timestamp The current timestamp.
     */
    function _updateReward(uint256 _timestamp) internal {
        uint256 _totalAssets = _currentTotalAssets(_timestamp);
        totalAssets_ = _totalAssets;
        emit UpdateTotalAssets(_totalAssets);

        lastUpdateTime_ = _timestamp;
        emit UpdateLastUpdateTime(_timestamp);
    }

    /**
     * @dev Starts a new reward period.
     */
    function _newReward() internal {
        uint256 _duration = duration_;
        _updateRewardRate(_availableReward(), _duration);
        _updatePeriodFinish(_duration);
    }

    /**
     * @dev Returns the available reward.
     * @return The amount of available reward.
     */
    function _availableReward() internal view returns (uint256) {
        return IERC20Upgradeable(asset()).balanceOf(address(this)) - totalAssets_;
    }

    /**
     * @dev Calculates the current total assets.
     * @param _timestamp The current timestamp.
     * @return The current total assets.
     */
    function _currentTotalAssets(uint256 _timestamp) internal view returns (uint256) {
        // If the total supply is 0, return 0
        if (totalSupply() == 0) return 0;
        // Otherwise, return the sum of total assets and the reward amount by time
        return totalAssets_ + _rewardAmountByTime(_timestamp);
    }

    /**
     * @dev Returns the update time.
     * @param _timestamp The current timestamp.
     */
    function _getUpdateTime(uint256 _timestamp) internal view returns (uint256) {
        return _timestamp < periodFinish_ ? _timestamp : periodFinish_;
    }

    /**
     * @dev Returns the reward amount by time.
     * @param _timestamp The current timestamp.
     */
    function _rewardAmountByTime(uint256 _timestamp) internal view returns (uint256 _rewardAmount) {
        uint256 _updateTime = _getUpdateTime(_timestamp);
        if (_updateTime > lastUpdateTime_) _rewardAmount = (_updateTime - lastUpdateTime_) * rewardRate_;
    }

    /**
     * @dev Hook that is called before any token transfer.
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param amount The amount to transfer.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        require(!paused(), "_beforeTokenTransfer: token transfer while paused");
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev Deposits assets and mints shares.
     * @param _assets The amount of assets to deposit.
     * @param _receiver The address to receive the shares.
     */
    function _deposit(address _caller, address _receiver, uint256 _assets, uint256 _shares) internal override {
        super._deposit(_caller, _receiver, _assets, _shares);
        totalAssets_ += _assets;
    }

    /**
     * @dev Withdraws assets and burns shares.
     * @param _assets The amount of assets to withdraw.
     * @param _receiver The address to receive the assets.
     * @param _owner The owner of the shares.
     */
    function _withdraw(
        address _caller,
        address _receiver,
        address _owner,
        uint256 _assets,
        uint256 _shares
    ) internal override {
        totalAssets_ -= _assets;
        super._withdraw(_caller, _receiver, _owner, _assets, _shares);
    }

    /**
     * @dev Deposits assets and mints shares.
     * @param _assets The amount of assets to deposit.
     * @param _receiver The address to receive the shares.
     */
    function deposit(uint256 _assets, address _receiver) public override sync returns (uint256 _shares) {
        return super.deposit(_assets, _receiver);
    }

    /**
     * @dev Deposits assets and mints shares with permit.
     * @param _assets The amount of assets to deposit.
     * @param _receiver The address to receive the shares.
     * @param _deadline The deadline for the permit.
     * @param _approveMax Whether to approve the maximum amount.
     * @param _v The v value of the permit signature.
     * @param _r The r value of the permit signature.
     * @param _s The s value of the permit signature.
     */
    function depositWithPermit(
        uint256 _assets,
        address _receiver,
        uint256 _deadline,
        bool _approveMax,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external returns (uint256) {
        uint256 _amount = _approveMax ? type(uint256).max : _assets;
        IdETH(asset()).permit(msg.sender, address(this), _amount, _deadline, _v, _r, _s);
        return deposit(_assets, _receiver);
    }

    /**
     * @dev Mints shares and deposits assets.
     * @param _shares The amount of shares to mint.
     * @param _receiver The address to receive the assets.
     */
    function mint(uint256 _shares, address _receiver) public override sync returns (uint256 _assets) {
        return super.mint(_shares, _receiver);
    }

    /**
     * @dev Withdraws assets and burns shares.
     * @param _assets The amount of assets to withdraw.
     * @param _receiver The address to receive the assets.
     * @param _owner The owner of the shares.
     */
    function withdraw(
        uint256 _assets,
        address _receiver,
        address _owner
    ) public override sync returns (uint256 _shares) {
        return super.withdraw(_assets, _receiver, _owner);
    }

    /**
     * @dev Redeems shares and returns assets.
     * @param _shares The amount of shares to redeem.
     * @param _receiver The address to receive the assets.
     * @param _owner The owner of the shares.
     */
    function redeem(uint256 _shares, address _receiver, address _owner) public override sync returns (uint256 _assets) {
        return super.redeem(_shares, _receiver, _owner);
    }

    /**
     * @dev Returns the duration of the reward period.
     */
    function duration() external view returns (uint256) {
        return duration_;
    }

    /**
     * @dev Returns the current reward rate.
     */
    function rewardRate() external view returns (uint256) {
        return rewardRate_;
    }

    /**
     * @dev Returns the end time of the current reward period.
     */
    function periodFinish() external view returns (uint256) {
        return periodFinish_;
    }

    /**
     * @dev Returns the last time the reward rate was updated.
     */
    function lastUpdateTime() external view returns (uint256) {
        return lastUpdateTime_;
    }

    /**
     * @dev Returns the available reward.
     * @return The amount of available reward.
     */
    function availableReward() external view returns (uint256) {
        return _availableReward();
    }

    /**
     * @dev Returns the total assets in the pool, including any accrued rewards.
     */
    function totalAssets() public view override returns (uint256) {
        return _currentTotalAssets(block.timestamp);
    }

    /**
     * @dev Returns the number of decimals for the token.
     */
    function decimals() public view override(ERC20Upgradeable, ERC4626Upgradeable) returns (uint8) {
        return ERC4626Upgradeable.decimals();
    }

    /**
     * @dev Checks if an address is a pause guardian.
     * @param _pauseGuardian The address to check.
     * @return True if the address is a pause guardian, false otherwise.
     */
    function isPauseGuardian(address _pauseGuardian) public view override returns (bool) {
        return PauseGuardian.isPauseGuardian(_pauseGuardian) || _pauseGuardian == owner();
    }
}
