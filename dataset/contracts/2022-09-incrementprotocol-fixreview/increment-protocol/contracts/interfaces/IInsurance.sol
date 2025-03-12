// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.16;

import {IClearingHouse} from "./IClearingHouse.sol";

interface IInsurance {
    /* ****************** */
    /*     Errors         */
    /* ****************** */

    /// @notice Emitted when the zero address is provided as a parameter in the constructor
    error Insurance_ZeroAddressConstructor(uint8 paramIndex);

    /// @notice Emitted when the sender is not the vault address
    error Insurance_SenderNotVault();

    /// @notice Emitted when the sender is not the clearingHouse address
    error Insurance_SenderNotClearingHouse();

    /// @notice Emitted when locked insurance falls below insurance ratio
    error Insurance_InsufficientInsurance();

    /// @notice Emitted when the proposed clearingHouse address is equal to the zero address
    error Insurance_ClearingHouseZeroAddress();

    /// @notice Emitted when the clearingHouse has already been set (one time call function)
    error Insurance_ClearingHouseAlreadySet();

    /* ****************** */
    /*     Events         */
    /* ****************** */

    /// @notice Emitted when a new ClearingHouse is connected to the issuer
    /// @param newClearingHouse New ClearingHouse contract address
    event ClearingHouseChanged(IClearingHouse newClearingHouse);

    /// @notice Emitted when some insurance reserves are withdrawn by governance
    /// @param amount Amount of insurance reserves withdrawn. 18 decimals
    event InsuranceRemoved(uint256 amount);

    /// @notice Emitted when the system debt is updated, upwards or downwards
    /// @param newSystemDebt New amount of system debt. 18 decimals (accounted for in UA)
    event SystemDebtChanged(uint256 newSystemDebt);

    /* ****************** */
    /*     Viewer         */
    /* ****************** */

    /* ****************** */
    /*  State modifying   */
    /* ****************** */

    function fundInsurance(uint256 amount) external;

    function settleDebt(uint256 amount) external;

    function removeInsurance(uint256 amount) external;
}
