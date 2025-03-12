// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../utils/Governable.sol";
import "../interfaces/risk/IPolicyManager.sol";
import "../interfaces/utils/IPolicyDescriptorV2.sol";

/**
 * @title PolicyDescriptor
 * @author solace.fi
 * @notice Produces a string containing the data URI for a JSON metadata string of a policy.
 * It is inspired from Uniswap V3 [`NonfungibleTokenPositionDescriptor`](https://docs.uniswap.org/protocol/reference/periphery/NonfungibleTokenPositionDescriptor).
 */
contract PolicyDescriptorV2 is IPolicyDescriptorV2, Governable {

    string _baseUri;

    /**
     * @notice Constructs the policy descriptor contract.
     * @param governance_ The address of the [governor](/docs/protocol/governance).
     */
    //constructor(address governance_, string memory base) Governable(governance_) {
        //_baseUri = base;
    constructor(address governance_) Governable(governance_) {
        string memory base = string(abi.encodePacked("https://paclas.solace.fi/policy/?chainid=", Strings.toString(block.chainid), "&policyid="));
        _baseUri = base;
        emit BaseUriSet(base);
    }

    /**
     * @notice Describes a policy.
     * @param policyManager The policy manager to retrieve policy info to produce URI description.
     * @param policyID The ID of the policy for which to produce a description.
     * @return description The URI of the ERC721-compliant metadata.
     */
    // solhint-disable-next-line no-unused-vars
    function tokenURI(IPolicyManager policyManager, uint256 policyID) external view override returns (string memory description) {
        return string(abi.encodePacked(_baseUri, Strings.toString(policyID)));
    }

    /**
     * @notice Returns the base of the URI descriptor.
     * @return base The base URI of the ERC721-compliant metadata.
     */
    function baseURI() external view override returns (string memory base) {
        return _baseUri;
    }

    /**
     * @notice Sets the base URI descriptor.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param base The new base URI.
     */
    function setBaseURI(string calldata base) external override onlyGovernance {
        _baseUri = base;
        emit BaseUriSet(base);
    }
}