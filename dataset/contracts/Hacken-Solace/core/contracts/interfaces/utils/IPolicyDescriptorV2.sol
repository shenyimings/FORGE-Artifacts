// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "../risk/IPolicyManager.sol";

/**
 * @title IPolicyDescriptor
 * @author solace.fi
 * @notice Produces a string containing the data URI for a JSON metadata string of a policy.
 * It is inspired from Uniswap V3 [`NonfungibleTokenPositionDescriptor`](https://docs.uniswap.org/protocol/reference/periphery/NonfungibleTokenPositionDescriptor).
 */
interface IPolicyDescriptorV2 {

    /// @notice Emitted when the base URI is set.
    event BaseUriSet(string base);

    /**
     * @notice Produces the URI describing a particular policy `product` for a given `policy id`.
     * @param policyManager The policy manager to retrieve policy info to produce URI descriptor.
     * @param policyID The ID of the policy for which to produce a description.
     * @return description The URI of the ERC721-compliant metadata.
     */
    function tokenURI(IPolicyManager policyManager, uint256 policyID) external view returns (string memory description);

    /**
     * @notice Returns the base of the URI descriptor.
     * @return base The base URI of the ERC721-compliant metadata.
     */
    function baseURI() external view returns (string memory base);

    /**
     * @notice Sets the base URI descriptor.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param base The new base URI.
     */
    function setBaseURI(string memory base) external;
}