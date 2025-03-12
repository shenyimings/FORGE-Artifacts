// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {State} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

import {Math, PERCENT, YEAR} from "@src/libraries/Math.sol";
import {Initialize} from "@src/libraries/actions/Initialize.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

import {
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/libraries/actions/Initialize.sol";

struct UpdateConfigParams {
    // The key of the configuration parameter to update
    string key;
    // The new value of the configuration parameter
    // When updating an address, the value is converted to uint160 and then to address
    uint256 value;
}

/// @title UpdateConfig
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic to update the configuration of the protocol
/// @dev The input validation is performed using the Initialize library
///      A `key` string is used to identify the configuration parameter to update and a `value` uint256 is used to set the new value
///      In case where an address is being updated, the `value` is converted to `uint160` and then to `address`
library UpdateConfig {
    using Initialize for State;

    /// @notice Returns the current fee configuration parameters
    /// @param state The state of the protocol
    /// @return The current fee configuration parameters
    function feeConfigParams(State storage state) public view returns (InitializeFeeConfigParams memory) {
        return InitializeFeeConfigParams({
            swapFeeAPR: state.feeConfig.swapFeeAPR,
            fragmentationFee: state.feeConfig.fragmentationFee,
            liquidationRewardPercent: state.feeConfig.liquidationRewardPercent,
            overdueCollateralProtocolPercent: state.feeConfig.overdueCollateralProtocolPercent,
            collateralProtocolPercent: state.feeConfig.collateralProtocolPercent,
            feeRecipient: state.feeConfig.feeRecipient
        });
    }

    /// @notice Returns the current risk configuration parameters
    /// @param state The state of the protocol
    /// @return The current risk configuration parameters
    function riskConfigParams(State storage state) public view returns (InitializeRiskConfigParams memory) {
        return InitializeRiskConfigParams({
            crOpening: state.riskConfig.crOpening,
            crLiquidation: state.riskConfig.crLiquidation,
            minimumCreditBorrowAToken: state.riskConfig.minimumCreditBorrowAToken,
            borrowATokenCap: state.riskConfig.borrowATokenCap,
            minTenor: state.riskConfig.minTenor,
            maxTenor: state.riskConfig.maxTenor
        });
    }

    /// @notice Returns the current oracle configuration parameters
    /// @param state The state of the protocol
    /// @return The current oracle configuration parameters
    function oracleParams(State storage state) public view returns (InitializeOracleParams memory) {
        return InitializeOracleParams({
            priceFeed: address(state.oracle.priceFeed),
            variablePoolBorrowRateStaleRateInterval: state.oracle.variablePoolBorrowRateStaleRateInterval
        });
    }

    /// @dev Validation is done at execution
    ///      We purposefuly leave this function empty for documentation purposes
    function validateUpdateConfig(State storage, UpdateConfigParams calldata) external pure {
        // validation is done at execution
    }

    /// @notice Updates the configuration of the protocol
    /// @param state The state of the protocol
    /// @param params The parameters to update the configuration
    function executeUpdateConfig(State storage state, UpdateConfigParams calldata params) external {
        if (Strings.equal(params.key, "crOpening")) {
            state.riskConfig.crOpening = params.value;
        } else if (Strings.equal(params.key, "crLiquidation")) {
            if (params.value >= state.riskConfig.crLiquidation) {
                revert Errors.INVALID_COLLATERAL_RATIO(params.value);
            }
            state.riskConfig.crLiquidation = params.value;
        } else if (Strings.equal(params.key, "minimumCreditBorrowAToken")) {
            state.riskConfig.minimumCreditBorrowAToken = params.value;
        } else if (Strings.equal(params.key, "borrowATokenCap")) {
            state.riskConfig.borrowATokenCap = params.value;
        } else if (Strings.equal(params.key, "minTenor")) {
            if (
                state.feeConfig.swapFeeAPR != 0
                    && params.value >= Math.mulDivDown(YEAR, PERCENT, state.feeConfig.swapFeeAPR)
            ) {
                revert Errors.VALUE_GREATER_THAN_MAX(
                    params.value, Math.mulDivDown(YEAR, PERCENT, state.feeConfig.swapFeeAPR)
                );
            }
            state.riskConfig.minTenor = params.value;
        } else if (Strings.equal(params.key, "maxTenor")) {
            if (
                state.feeConfig.swapFeeAPR != 0
                    && params.value >= Math.mulDivDown(YEAR, PERCENT, state.feeConfig.swapFeeAPR)
            ) {
                revert Errors.VALUE_GREATER_THAN_MAX(
                    params.value, Math.mulDivDown(YEAR, PERCENT, state.feeConfig.swapFeeAPR)
                );
            }
            state.riskConfig.maxTenor = params.value;
        } else if (Strings.equal(params.key, "swapFeeAPR")) {
            if (params.value >= Math.mulDivDown(PERCENT, YEAR, state.riskConfig.maxTenor)) {
                revert Errors.VALUE_GREATER_THAN_MAX(
                    params.value, Math.mulDivDown(PERCENT, YEAR, state.riskConfig.maxTenor)
                );
            }
            state.feeConfig.swapFeeAPR = params.value;
        } else if (Strings.equal(params.key, "fragmentationFee")) {
            state.feeConfig.fragmentationFee = params.value;
        } else if (Strings.equal(params.key, "liquidationRewardPercent")) {
            state.feeConfig.liquidationRewardPercent = params.value;
        } else if (Strings.equal(params.key, "overdueCollateralProtocolPercent")) {
            state.feeConfig.overdueCollateralProtocolPercent = params.value;
        } else if (Strings.equal(params.key, "collateralProtocolPercent")) {
            state.feeConfig.collateralProtocolPercent = params.value;
        } else if (Strings.equal(params.key, "feeRecipient")) {
            state.feeConfig.feeRecipient = address(uint160(params.value));
        } else if (Strings.equal(params.key, "priceFeed")) {
            state.oracle.priceFeed = IPriceFeed(address(uint160(params.value)));
        } else if (Strings.equal(params.key, "variablePoolBorrowRateStaleRateInterval")) {
            state.oracle.variablePoolBorrowRateStaleRateInterval = uint64(params.value);
        } else {
            revert Errors.INVALID_KEY(params.key);
        }

        Initialize.validateInitializeFeeConfigParams(feeConfigParams(state));
        Initialize.validateInitializeRiskConfigParams(riskConfigParams(state));
        Initialize.validateInitializeOracleParams(oracleParams(state));

        emit Events.UpdateConfig(params.key, params.value);
    }
}
