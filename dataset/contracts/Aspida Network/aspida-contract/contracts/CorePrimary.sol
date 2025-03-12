// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./library/PauseGuardian.sol";
import "./library/Manable.sol";
import "./core/ActionControl.sol";
import "./core/CoreTreasury.sol";
import "./core/CoreStrategy.sol";
import "./core/StakingModel.sol";
import "./core/Submit.sol";
import "./core/WithdrawalQueue.sol";

import "./interface/IRewardOracle.sol";

/**
 * @title Aspida's ETH 2.0 staking Core(primary)
 * @author Aspida engineer
 * @notice This contract is the primary contract for Aspida's ETH 2.0 staking Core.
 *         It inherits from several other contracts and contains various functions for managing the Core.
 * @dev This contract is implemented using the OpenZeppelin library.
 *      It is used for staking ETH 2.0 and managing the Core's treasury, strategies, and actions.
 *      It also contains functions for submitting and withdrawing ETH, as well as managing the withdrawal queue.
 */
contract CorePrimary is
    Ownable2StepUpgradeable,
    PauseGuardian,
    ReentrancyGuardUpgradeable,
    Manable,
    ActionControl,
    CoreTreasury,
    CoreStrategy,
    Submit,
    StakingModel,
    WithdrawalQueue
{
    address internal rewardOracle_;

    uint256 internal received_;

    event SetRewardOracle(address rewardOracle);
    event Received(uint256 _ethValue);

    /**
     * @dev Throws if called by any account other than the rewardOracle.
     */
    modifier onlyRewardOracle() {
        require(rewardOracle_ == msg.sender, "onlyRewardOracle: caller is not the rewardOracle");
        _;
    }

    /**
     * @notice Only for the implementation contract, as for the proxy pattern,
     *            should call `initialize()` separately.
     */
    constructor(
        IDepositContract _depositContract,
        IdETH _dETH,
        IsdETH _sdETH
    ) StakingModel(_depositContract) Submit(_dETH, _sdETH) {
        initialize();
    }

    /**
     * @notice Expects to call only once to initialize CorePrimary.
     */
    function initialize() public initializer {
        __Ownable2Step_init();
        _setTreasuryInternal(owner());
        _setWithdrawalCredentialsInternal(_addressToWithdrawalCredentials(address(this)));
    }

    /**
     * @notice Receives ETH sent to the contract.
     */
    receive() external payable {
        received_ += msg.value;
        emit Received(msg.value);
    }

    /**
     * @dev Unpause when Core is paused.
     */
    function _open() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Pause Core.
     */
    function _close() external onlyPauseGuardian {
        _pause();
    }

    /**
     * @notice Adds a new pause guardian to the Core.
     * @param _pauseGuardian The address of the new pause guardian.
     */
    function _addPauseGuardian(address _pauseGuardian) external onlyOwner {
        _addPauseGuardianInternal(_pauseGuardian);
    }

    /**
     * @notice Removes a pause guardian from the Core.
     * @param _pauseGuardian The address of the pause guardian to remove.
     */
    function _removePauseGuardian(address _pauseGuardian) external onlyOwner {
        _removePauseGuardianInternal(_pauseGuardian);
    }

    /**
     * @notice Adds a new manager to the Core.
     * @param _manager The address of the new manager.
     */
    function _addManager(address _manager) external onlyOwner {
        _addManagerInternal(_manager);
    }

    /**
     * @notice Removes a manager from the Core.
     * @param _manager The address of the manager to remove.
     */
    function _removeManager(address _manager) external onlyOwner {
        _removeManagerInternal(_manager);
    }

    /**
     * @notice Sets the treasury address.
     * @param _treasury The address of the new treasury.
     */
    function _setTreasury(address _treasury) external onlyOwner {
        _setTreasuryInternal(_treasury);
    }

    /**
     * @notice Sets the treasury ratio.
     * @param _treasuryRatio The new treasury ratio.
     */
    function _setTreasuryRatio(uint256 _treasuryRatio) external onlyOwner {
        _setTreasuryRatioInternal(_treasuryRatio);
    }

    /**
     * @notice Sets the action limit.
     * @param _actionId The action ID.
     * @param _limit The new limit.
     */
    function _setActionLimit(Action _actionId, uint256 _limit) external onlyOwner {
        _setActionLimitInternal(_actionId, _limit);
    }

    /**
     * @notice Sets the action threshold.
     * @param _actionId The action ID.
     * @param _threshold The new threshold.
     */
    function _setActionThreshold(Action _actionId, uint256 _threshold) external onlyOwner {
        _setActionThresholdInternal(_actionId, _threshold);
    }

    /**
     * @notice Sets the reserve ratio.
     * @param _reserveRatio The new reserve ratio.
     */
    function _setReserveRatio(uint256 _reserveRatio) external onlyOwner {
        _setReserveRatioInternal(_reserveRatio);
    }

    /**
     * @notice Adds a new strategy.
     * @param _strategy The address of the new strategy.
     */
    function _addStrategy(address _strategy) external onlyOwner {
        _addStrategyInternal(_strategy);
    }

    /**
     * @notice Removes a strategy.
     * @param _strategy The address of the strategy to remove.
     */
    function _removeStrategy(address _strategy) external onlyOwner {
        _removeStrategyInternal(_strategy);
    }

    /**
     * @notice Releases the strategy reserve.
     * @param _releaseAmount The amount to release.
     */
    function _releaseStrategyReserve(uint256 _releaseAmount) external onlyOwner {
        _decreaseStrategyReserve(_releaseAmount);
    }

    /**
     * @notice Sets the reward oracle address.
     * @param _rewardOracle The address of the new reward oracle.
     */
    function _setRewardOracle(address _rewardOracle) external onlyOwner {
        require(
            _rewardOracle != rewardOracle_ && IRewardOracle(_rewardOracle).core() == address(this),
            "_setRewardOracle: Invalid reward oracle address"
        );
        rewardOracle_ = _rewardOracle;
        emit SetRewardOracle(_rewardOracle);
    }

    /**
     * @notice Disables the reward oracle.
     */
    function _disableRewardOracle() external onlyOwner {
        rewardOracle_ = address(0);
        emit SetRewardOracle(address(0));
    }

    /**
     * @notice Deposits ETH into a strategy.
     * @param _strategy The address of the strategy.
     * @param _ethAmount The amount of ETH to deposit.
     */
    function _depositIntoStrategy(address _strategy, uint256 _ethAmount) external onlyOwner {
        _depositIntoStrategyInternal(_strategy, _ethAmount);
    }

    /**
     * @notice Deposits ETH into the contract for staking.
     * @param _validators The array of validators to deposit.
     */
    function deposit(Validator[] calldata _validators) external whenNotPaused nonReentrant onlyManager {
        require(
            (address(this).balance - strategyReserve_ - pendingClaimAmount_) / DEPOSIT_SIZE >= _validators.length,
            "deposit: Not enough ETH"
        );

        _deposit(_validators);
    }

    /**
     * @notice Supplies reward.
     * @param _amount The amount to supply.
     */
    function supplyReward(uint256 _amount) external whenNotPaused onlyRewardOracle {
        require(_amount != 0, "supplyReward: Amount cannot be 0");

        uint256 _treasuryAmount = _getTreasuryAmount(_amount);
        if (_treasuryAmount > 0) DETH.mint(treasury_, _treasuryAmount);

        uint256 _reward = _amount - _treasuryAmount;
        if (_reward > 0) DETH.mint(address(SDETH), _reward);
    }

    /**
     * @notice Mints DETH to the specified receiver.
     * @param _receiver The address of the receiver.
     * @param _amount The amount of DETH to mint.
     */
    function strategyMinting(address _receiver, uint256 _amount) external whenNotPaused isStrategy(msg.sender) {
        DETH.mint(_receiver, _amount);
    }

    /**
     * @notice Receives earnings from a strategy.
     */
    function receiveStrategyEarning() external payable {
        _receiveStrategyEarning(msg.sender);
    }

    /**
     * @notice Submits a transaction to the CorePrimary contract.
     * @dev This function is called internally when a user submits a transaction.
     * @param _receiver The address of the receiver of the transaction.
     */
    function _submit(address _receiver) internal override whenNotPaused nonReentrant {
        uint256 _ethValue = msg.value;
        _checkActionLimit(Action.submit, block.timestamp / 1 days, _ethValue, submitted_);
        _increaseReservesByRatio(_ethValue);
        Submit._submit(_receiver);
    }

    /**
     * @dev Internal function to withdraw funds from the contract.
     * @param _sender The address of the sender.
     * @param _receiver The address of the receiver.
     * @param _amount The amount to withdraw.
     */
    function _withdraw(
        address _sender,
        address _receiver,
        uint256 _amount
    ) internal override whenNotPaused nonReentrant {
        _checkAction(
            Action.withdraw,
            block.timestamp / 1 days,
            _amount,
            totalWithdrawn_ + pendingClaimAmount_ + totalClaimed_
        );
        DETH.burnFrom(_sender, _amount);
        WithdrawalQueue._withdraw(_sender, _receiver, _amount);
    }

    /**
     * @notice Claims the rewards by queue ID.
     * @param _sender The address of the sender.
     * @param _receiver The address of the receiver.
     * @param _queueIds The array of queue IDs.
     * @param _userQueueIds The set of user queue IDs.
     */
    function _claimByQueueId(
        address _sender,
        address _receiver,
        uint256[] memory _queueIds,
        EnumerableSet.UintSet storage _userQueueIds
    ) internal override whenNotPaused nonReentrant {
        WithdrawalQueue._claimByQueueId(_sender, _receiver, _queueIds, _userQueueIds);
    }

    /**
     * @dev Returns the amount of ETH that can be withdrawn from the contract.
     * @return _availableAmount The available amount of ETH that can be withdrawn.
     */
    function _withdrawableAmount() internal view override returns (uint256 _availableAmount) {
        uint256 _balance = address(this).balance;
        uint256 _locked = pendingClaimAmount_ + strategyReserve_;
        if (_balance > _locked) {
            _availableAmount = _balance - _locked;
        }
    }

    /**
     * @dev Returns the amount of ETH that can be claimed from the contract.
     * @return _claimableAmount The amount of ETH that can be claimed.
     */
    function _claimableAmount() internal view override returns (uint256) {
        return address(this).balance - strategyReserve_ + totalClaimed_;
    }

    /**
     * @notice Withdraws a specified amount of tokens with permit functionality.
     * @param _amount The amount of tokens to withdraw.
     * @param _receiver The address to receive the tokens.
     * @param _deadline The deadline for the permit.
     * @param _approveMax Boolean indicating whether to approve the maximum amount.
     * @param _v The recovery id of the permit signature.
     * @param _r The R value of the permit signature.
     * @param _s The S value of the permit signature.
     */
    function withdrawWithPermit(
        uint256 _amount,
        address _receiver,
        uint256 _deadline,
        bool _approveMax,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        // Determine the value to be approved
        uint256 _value = _approveMax ? type(uint256).max : _amount;

        // Call the permit function of the token contract
        DETH.permit(msg.sender, address(this), _value, _deadline, _v, _r, _s);

        // Withdraw the specified amount of tokens
        _withdraw(msg.sender, _receiver, _amount);
    }

    /**
     * @notice Redeems a specified amount of sdETH and withdraws the underlying ETH.
     * @param _sdETHAmount The amount of sdETH to redeem.
     */
    function redeemAndWithdraw(uint256 _sdETHAmount) external {
        address _sender = msg.sender;
        uint256 _amount = SDETH.redeem(_sdETHAmount, address(this), _sender);
        _withdraw(address(this), _sender, _amount);
    }

    /**
     * @notice Withdraws a specified amount of underlying ETH and sdETH.
     * @param _amount The amount of underlying ETH to withdraw.
     */
    function redeemUnderlyingAndWithdraw(uint256 _amount) external {
        address _sender = msg.sender;
        SDETH.withdraw(_amount, address(this), _sender);
        _withdraw(address(this), _sender, _amount);
    }

    /**
     * @dev Returns the address of the reward oracle.
     * @return The address of the reward oracle.
     */
    function rewardOracle() external view returns (address) {
        return rewardOracle_;
    }

    /**
     * @dev Returns the amount of ETH received by the contract.
     * @return The amount of ETH received by the contract.
     */
    function received() external view returns (uint256) {
        return received_;
    }

    /**
     * @dev Returns the remaining amount of ETH that can be submitted for the current day.
     * @return The remaining amount of ETH that can be submitted for the current day.
     */
    function submitRemaining() external view returns (uint256) {
        return actionRemaining(Action.submit, block.timestamp / 1 days, submitted_);
    }

    /**
     * @dev Returns the remaining amount of ETH that can be withdrawn for the current day.
     * @return The remaining amount of ETH that can be withdrawn for the current day.
     */
    function withdrawRemaining() external view returns (uint256) {
        return
            actionRemaining(
                Action.withdraw,
                block.timestamp / 1 days,
                totalWithdrawn_ + pendingClaimAmount_ + totalClaimed_
            );
    }

    /**
     * @dev Returns the withdraw threshold.
     * @return The withdraw threshold.
     */
    function withdrawThreshold() external view returns (uint256) {
        return actionDatas_[Action.withdraw].threshold;
    }

    /**
     * @dev Returns whether the given address is a pause guardian.
     * @param _pauseGuardian The address to check.
     * @return Whether the given address is a pause guardian.
     */
    function isPauseGuardian(address _pauseGuardian) public view override returns (bool) {
        return PauseGuardian.isPauseGuardian(_pauseGuardian) || _pauseGuardian == owner();
    }

    /**
     * @dev Returns the staking reward.
     * @param _deposited The amount deposited.
     * @param _exited The amount exited.
     * @return _stakingReward The staking reward.
     */
    function stakingReward(uint256 _deposited, uint256 _exited) external view returns (uint256 _stakingReward) {
        uint256 _minuend = address(this).balance +
            totalWithdrawn_ +
            totalClaimed_ +
            depositStrategy_ +
            _deposited *
            DEPOSIT_SIZE;
        uint256 _subtrahend = submitted_ + received_ + receiveStrategy_ + _exited * DEPOSIT_SIZE;
        if (_minuend > _subtrahend) _stakingReward = _minuend - _subtrahend;
    }
}
