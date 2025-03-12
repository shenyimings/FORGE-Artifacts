// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * @title IFeeSettingsV1
 * @author malteish
 * @notice This is the interface for the FeeSettings contract in v4 of the tokenize.it contracts. The token contract
 * and the investment contracts will use this interface to get the fees for the different actions, as well as the address
 * of the fee collector.
 */
interface IFeeSettingsV1 {
    function tokenFee(uint256) external view returns (uint256);

    function continuousFundraisingFee(uint256) external view returns (uint256);

    function personalInviteFee(uint256) external view returns (uint256);

    function feeCollector() external view returns (address);

    function owner() external view returns (address);

    function supportsInterface(bytes4) external view returns (bool); //because we inherit from ERC165
}

/**
 * @title IFeeSettingsV2
 * @author malteish
 * @notice This is the interface for the FeeSettings contract in v5 of the tokenize.it contracts.
 * From v4 to v5, the contract names have changed and instead of one fee collector, there are now three.
 */
interface IFeeSettingsV2 {
    function tokenFee(uint256, address) external view returns (uint256);

    function tokenFeeCollector(address) external view returns (address);

    function crowdinvestingFee(uint256, address) external view returns (uint256);

    function crowdinvestingFeeCollector(address) external view returns (address);

    function privateOfferFee(uint256, address) external view returns (uint256);

    function privateOfferFeeCollector(address) external view returns (address);

    function owner() external view returns (address);

    function supportsInterface(bytes4) external view returns (bool); //because we inherit from ERC165
}

/**
 * @notice The Fees struct contains all the parameters to change fee quantities and fee collector addresses,
 * as well as the time when the new settings can be activated.
 * @dev time has different meanings:
 *  1. it is ignored when the struct is used during initialization.
 *  2. it is the time when the new settings can be activated when the struct is used during a fee change.
 *  3. it is the time up to which the settings are valid when the struct is used for fee discounts for specific customers
 */
struct Fees {
    uint32 tokenFeeNumerator;
    uint32 tokenFeeDenominator;
    uint32 crowdinvestingFeeNumerator;
    uint32 crowdinvestingFeeDenominator;
    uint32 privateOfferFeeNumerator;
    uint32 privateOfferFeeDenominator;
    uint64 validityDate;
}
