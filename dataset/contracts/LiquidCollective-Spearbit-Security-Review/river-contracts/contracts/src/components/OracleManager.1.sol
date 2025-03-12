//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../libraries/Errors.sol";
import "../libraries/LibOwnable.sol";

import "../state/river/OracleAddress.sol";
import "../state/river/LastOracleRoundId.sol";
import "../state/river/BeaconValidatorBalanceSum.sol";
import "../state/river/BeaconValidatorCount.sol";
import "../state/river/DepositedValidatorCount.sol";

import "../interfaces/components/IOracleManager.1.sol";

/// @title Oracle Manager (v1)
/// @author Kiln
/// @notice This contract handles the inputs provided by the oracle
abstract contract OracleManagerV1 is IOracleManagerV1 {
    /// @notice Handler called if the delta between the last and new validator balance sum is positive
    /// @dev Must be overriden
    /// @param _profits The positive increase in the validator balance sum (staking rewards)
    function _onEarnings(uint256 _profits) internal virtual;

    function _pullELFees() internal virtual returns (uint256);

    /// @notice Prevents unauthorized calls
    modifier onlyAdmin() virtual {
        if (msg.sender != LibOwnable._getAdmin()) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice Set the initial oracle address
    /// @param _oracle Address of the oracle
    function initOracleManagerV1(address _oracle) internal {
        OracleAddress.set(_oracle);
    }

    /// @notice Sets the validator count and validator balance sum reported by the oracle
    /// @dev Can only be called by the oracle address
    /// @param _validatorCount The number of active validators on the consensus layer
    /// @param _validatorBalanceSum The validator balance sum of the active validators on the consensus layer
    /// @param _roundId An identifier for this update
    function setBeaconData(uint256 _validatorCount, uint256 _validatorBalanceSum, bytes32 _roundId) external {
        if (msg.sender != OracleAddress.get()) {
            revert Errors.Unauthorized(msg.sender);
        }

        if (_validatorCount > DepositedValidatorCount.get()) {
            revert InvalidValidatorCountReport(_validatorCount, DepositedValidatorCount.get());
        }

        uint256 newValidators = _validatorCount - BeaconValidatorCount.get();
        uint256 previousValidatorBalanceSum = BeaconValidatorBalanceSum.get() + (newValidators * 32 ether);

        BeaconValidatorBalanceSum.set(_validatorBalanceSum);
        BeaconValidatorCount.set(_validatorCount);
        LastOracleRoundId.set(_roundId);

        uint256 executionLayerFees = _pullELFees();

        if (previousValidatorBalanceSum < _validatorBalanceSum + executionLayerFees) {
            _onEarnings((_validatorBalanceSum + executionLayerFees) - previousValidatorBalanceSum);
        }

        emit BeaconDataUpdate(_validatorCount, _validatorBalanceSum, _roundId);
    }

    /// @notice Get Oracle address
    function getOracle() external view returns (address oracle) {
        oracle = OracleAddress.get();
    }

    /// @notice Set Oracle address
    /// @param _oracleAddress Address of the oracle
    function setOracle(address _oracleAddress) external onlyAdmin {
        OracleAddress.set(_oracleAddress);
    }

    /// @notice Get Beacon validator balance sum
    function getBeaconValidatorBalanceSum() external view returns (uint256 beaconValidatorBalanceSum) {
        beaconValidatorBalanceSum = BeaconValidatorBalanceSum.get();
    }

    /// @notice Get Beacon validator count (the amount of validator reported by the oracles)
    function getBeaconValidatorCount() external view returns (uint256 beaconValidatorCount) {
        beaconValidatorCount = BeaconValidatorCount.get();
    }
}
