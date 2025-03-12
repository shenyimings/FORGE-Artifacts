// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import "./library/PauseGuardian.sol";
import "./library/Manable.sol";

import "./interface/ICore.sol";

/**
 * @title Aspida's ETH 2.0 staking reward oracle
 * @dev This contract serves as a reward oracle for ETH 2.0 staking. It calculates and updates the epoch reward based on various parameters.
 * @author Aspida engineer
 */
contract RewardOracle is Ownable2StepUpgradeable, PauseGuardian, Manable {
    uint256 internal constant BASE = 1e18;
    uint256 internal constant SECONDS_PER_SLOT = 12 seconds;
    uint256 internal constant SLOT_PER_EPOCH = 32;
    uint256 internal constant EPOCH_PER_YEAR = 365 days / (SECONDS_PER_SLOT * SLOT_PER_EPOCH);
    uint256 internal constant EPOCH_INTEREST_RATE_MAX = BASE / EPOCH_PER_YEAR;

    uint256 internal constant DEPOSIT_SIZE = 32 ether; // The deposit size for validators

    ICore internal immutable CORE; // The interface for the core contract

    uint256 internal interestRateLimitPerEpoch_; // The interest rate limit per epoch
    uint256 internal validatorLimitPerEpoch_; // The validator limit per epoch

    uint256 internal lastEpochId_; // The last epoch ID
    uint256 internal lastActivatedValidatorCount_; // The last activated validator count

    /**
     * @dev Emitted when the interest rate limit per epoch is set
     */
    event SetInterestRateLimitPerEpoch(uint256 interestRateLimitPerEpoch);

    /**
     * @dev Emitted when the validator limit per epoch is set
     */
    event SetValidatorLimitPerEpoch(uint256 validatorLimitPerEpoch);

    /**
     * @dev Emitted when the epoch reward is updated
     */
    event UpdateEpochReward(
        uint256 lastEpochId,
        uint256 submitEpochId,
        uint256 lastActivatedValidatorCount,
        uint256 activatedValidatorCount,
        uint256 rewardIncrement
    );

    /**
     * @notice Only for the implementation contract, as for the proxy pattern,
     *            should call `initialize()` separately.
     * @param _core The interface for the core contract
     */
    constructor(ICore _core) {
        CORE = _core;
        initialize();
    }

    /**
     * @notice Expects to call only once to initialize RewardOracle.
     */
    function initialize() public initializer {
        __Ownable2Step_init();
        _setInterestRateLimitPerEpoch(BASE);
    }

    /**
     * @dev Unpause when RewardOracle is paused.
     */
    function _open() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Pause RewardOracle.
     */
    function _close() external onlyPauseGuardian {
        _pause();
    }

    /**
     * @notice Add `_pauseGuardian` into pause guardians.
     * @param _pauseGuardian The address of the pause guardian to add
     */
    function _addPauseGuardian(address _pauseGuardian) external onlyOwner {
        _addPauseGuardianInternal(_pauseGuardian);
    }

    /**
     * @notice Remove `_pauseGuardian` from pause guardians.
     * @param _pauseGuardian The address of the pause guardian to remove
     */
    function _removePauseGuardian(address _pauseGuardian) external onlyOwner {
        _removePauseGuardianInternal(_pauseGuardian);
    }

    /**
     * @notice Add `_manager` into managers.
     * If `_manager` have not been a manager, emits a `ManagerAdded` event.
     *
     * @param _manager The manager to add
     *
     * Requirements:
     * - the caller must be `owner`.
     */
    function _addManager(address _manager) external onlyOwner {
        _addManagerInternal(_manager);
    }

    /**
     * @notice Remove `_manager` from managers.
     * If `_manager` is a manager, emits a `ManagerRemoved` event.
     *
     * @param _manager The manager to remove
     *
     * Requirements:
     * - the caller must be `owner`.
     */
    function _removeManager(address _manager) external onlyOwner {
        _removeManagerInternal(_manager);
    }

    /**
     * @notice Set the interest rate limit per epoch.
     * @param _annualInterestRate The annual interest rate
     *
     * Requirements:
     * - the caller must be `owner`.
     * - the interest rate must not be too large.
     * - the interest rate cannot be set to the same value.
     */
    function _setInterestRateLimitPerEpoch(uint256 _annualInterestRate) public onlyOwner {
        uint256 _interestRateLimitPerEpoch = _annualInterestRate / EPOCH_PER_YEAR;
        require(
            _interestRateLimitPerEpoch <= EPOCH_INTEREST_RATE_MAX,
            "_setInterestRateLimitPerEpoch: Interest rate too large"
        );
        require(
            _interestRateLimitPerEpoch != interestRateLimitPerEpoch_,
            "_setInterestRateLimitPerEpoch: Cannot set the same value"
        );
        interestRateLimitPerEpoch_ = _interestRateLimitPerEpoch;
        emit SetInterestRateLimitPerEpoch(_interestRateLimitPerEpoch);
    }

    /**
     * @notice Set the validator limit per epoch.
     * @param _validatorLimitPerEpoch The validator limit per epoch
     *
     * Requirements:
     * - the caller must be `owner`.
     * - the validator limit cannot be set to the same value.
     */
    function _setValidatorLimitPerEpoch(uint256 _validatorLimitPerEpoch) public onlyOwner {
        require(
            _validatorLimitPerEpoch != validatorLimitPerEpoch_,
            "_setValidatorLimitPerEpoch: Cannot set the same value"
        );
        validatorLimitPerEpoch_ = _validatorLimitPerEpoch;
        emit SetValidatorLimitPerEpoch(_validatorLimitPerEpoch);
    }

    /**
     * @notice Calculate the epoch interest rate.
     * @param _epochCount The number of epochs
     * @param _activatedValidatorCount The number of activated validators
     * @param _rewardIncrement The reward increment
     * @return The epoch interest rate
     */
    function _calculateEpochInterestRate(
        uint256 _epochCount,
        uint256 _activatedValidatorCount,
        uint256 _rewardIncrement
    ) internal pure returns (uint256) {
        uint256 _principal = _epochCount * _activatedValidatorCount * DEPOSIT_SIZE;
        return (_rewardIncrement * BASE + _principal - 1) / _principal;
    }

    /**
     * @notice Update the epoch reward.
     * @param _epochId The epoch ID
     * @param _activatedValidatorCount The number of activated validators
     * @param _rewardIncrement The reward increment
     *
     * Requirements:
     * - the active validators must not be 0.
     * - the epoch ID must increase.
     * - the epoch interest rate must be valid.
     * - the validator limit must not be exceeded.
     */
    function _updateEpochReward(uint256 _epochId, uint256 _activatedValidatorCount, uint256 _rewardIncrement) internal {
        require(_activatedValidatorCount > 0, "_updateEpochReward: Active validators must not be 0");

        uint256 _lastEpochId = lastEpochId_;
        require(_epochId > _lastEpochId, "_updateEpochReward: Epoch id must increase");

        uint256 _epochCount = _epochId - _lastEpochId;
        uint256 _epochInterestRate = _calculateEpochInterestRate(
            _epochCount,
            _activatedValidatorCount,
            _rewardIncrement
        );
        require(_epochInterestRate <= interestRateLimitPerEpoch_, "_updateEpochReward: Invalid epoch interest rate");

        uint256 _lastActivatedValidatorCount = lastActivatedValidatorCount_;
        if (_activatedValidatorCount > _lastActivatedValidatorCount) {
            require(
                (_activatedValidatorCount - _lastActivatedValidatorCount + _epochCount - 1) / _epochCount <=
                    validatorLimitPerEpoch_,
                "_updateEpochReward: Validator out of increment per epoch"
            );
        }

        lastEpochId_ = _epochId;
        lastActivatedValidatorCount_ = _activatedValidatorCount;
        emit UpdateEpochReward(
            _lastEpochId,
            _epochId,
            _lastActivatedValidatorCount,
            _activatedValidatorCount,
            _rewardIncrement
        );
    }

    /**
     * @notice Submit the epoch reward.
     * @param _epochId The epoch ID
     * @param _activatedValidatorCount The number of activated validators
     * @param _rewardIncrement The reward increment
     *
     * Requirements:
     * - the caller must be the `manager`.
     * - the contract must not be paused.
     */
    function submitEpochReward(
        uint256 _epochId,
        uint256 _activatedValidatorCount,
        uint256 _rewardIncrement
    ) external whenNotPaused onlyManager {
        _updateEpochReward(_epochId, _activatedValidatorCount, _rewardIncrement);
        CORE.supplyReward(_rewardIncrement);
    }

    /**
     * @notice Get the CORE contract.
     * @return The CORE contract.
     */
    function core() external view returns (ICore) {
        return CORE;
    }

    /**
     * @notice Get the interest rate limit per epoch.
     * @return The interest rate limit per epoch.
     */
    function interestRateLimitPerEpoch() external view returns (uint256) {
        return interestRateLimitPerEpoch_;
    }

    /**
     * @notice Get the validator limit per epoch.
     * @return The validator limit per epoch.
     */
    function validatorLimitPerEpoch() external view returns (uint256) {
        return validatorLimitPerEpoch_;
    }

    /**
     * @notice Get the last epoch ID.
     * @return The last epoch ID.
     */
    function lastEpochId() external view returns (uint256) {
        return lastEpochId_;
    }

    /**
     * @notice Get the last activated validator count.
     * @return The last activated validator count.
     */
    function lastActivatedValidatorCount() external view returns (uint256) {
        return lastActivatedValidatorCount_;
    }

    /**
     * @notice Check if an address is a pause guardian.
     * @param _pauseGuardian The address to check.
     * @return True if the address is a pause guardian or the owner, false otherwise.
     */
    function isPauseGuardian(address _pauseGuardian) public view override returns (bool) {
        return PauseGuardian.isPauseGuardian(_pauseGuardian) || _pauseGuardian == owner();
    }
}
