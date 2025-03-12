// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

/**
 *
 * | Type  | isFungible  | isCollection | isToken |
 * | FC    |   true      |     true     |  true   |
 * | NFC   |   false     |     true     |  false  |
 * | NFT   |   false     |     false    |  true   |
 *
 * | Type  | transfer    |    balance   |   supply    | owner |
 * | FC    |   OK        |     OK       |     OK      |  NOK  |
 * | NFC   |   NOK       |     OK       |     OK      |  NOK  |
 * | NFT   |   OK        |   0 or 1     |   0 or 1    |  OK   |
 */

// solhint-disable-next-line
interface IERC____NextTokenStandard {
    /**
     * Event emitted every time
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event TransferBatchOperator(address indexed operator, address[] froms, address[] tos, uint256[] ids, uint256[] values);
    event OperatorsApproval(address indexed owner, address[] indexed operators, bool[] approved);

    //                                Approvals                                 //

    function setApprovalForAllBatch(address[] calldata operators, bool[] calldata approved) external;

    function isApprovedForAllBatch(address[] calldata owners, address[] calldata operators) external view returns (bool[] memory approved);

    //                               Transfers                                 //

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external;

    function safeBatchOperatorTransferFrom(
        address[] calldata froms,
        address[] calldata tos,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external;

    //                           Supply and Ownership                           //

    function totalSupplyBatch(uint256[] calldata ids) external view returns (uint256[] memory supplies);

    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids) external view returns (uint256[] memory balances);

    function ownerOfBatch(uint256[] calldata nftIds) external view returns (address[] memory owners);

    //                         Identifiers Introspection                        //

    function isFungibleBatch(uint256[] calldata ids) external pure returns (bool[] memory fungible);

    function collectionOfBatch(uint256[] calldata nftIds) external pure returns (uint256[] memory collectionIds);
}

// solhint-disable-next-line
interface IERC____NextTokenStandard_MetadataEvent {
    event URI(string _value, uint256 indexed _id);
}

// solhint-disable-next-line
interface IERC____NextTokenStandard_MetadataFunction {
    /**
     * A distinct Uniform Resource Identifier (URI) for a given identifier.
     *  The URI MUST point to a JSON file that conforms to the "ERC-1155 Metadata URI JSON Schema".
     *  The uri function SHOULD be used to retrieve values if no event was emitted.
     *  The uri function MUST return the same value as the latest event for an _id if it was emitted.
     *  The uri function MUST NOT be used to check for the existence of a token as it is possible for
     *  an implementation to return a valid string even if the token does not exist.
     * @dev URIs are defined in RFC 3986.
     * @param id Identifier to retrieve the URI of.
     * @return URI string
     */
    function uri(uint256 id) external view returns (string memory);
}
