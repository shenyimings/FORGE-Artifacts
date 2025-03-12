// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


/**
 * @title IZeroToken
 * @dev Interface for the BondingToken contract.
 */
interface IZeroToken {
    function setVaultFees(uint256 entryFeeBasisPoints, uint256 exitFeeBasisPoints) external;

    function setCreatorFees(uint256 entryFeeBasisPoints, uint256 exitFeeBasisPoints) external;

    function setCreatorFeeRecipient(address newRecipient) external;

    function setProtocolFees(uint256 entryFeeBasisPoints, uint256 exitFeeBasisPoints) external;
    
    function setProtocolFeeRecipient(address newRecipient) external;

    function getFeeData() external view returns (uint256 entryFeeVault, uint256 exitFeeVault, uint256 entryFeeProtocol, uint256 exitFeeProtocol, uint256 entryFeeCreator, uint256 exitFeeCreator, address feeRecipientProtocol, address feeRecipientCreator);
}