// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ITransferSelectorNFT
 * @author LooksRare protocol team (ðŸ‘€,ðŸ’Ž)
 */
interface ITransferSelectorNFT {
    /**
     * @notice This struct contains information about the transfer manager and the associated function selector.
     * @param transferManager Address of the transfer manager
     * @param selector Function selector
     */
    struct ManagerSelector {
        address transferManager;
        bytes4 selector;
    }

    /**
     * @notice It is emitted if there is a new asset type added to the protocol.
     * @param assetType Asset type id
     * @param transferManager Address of the transfer manager
     * @param selector Function selector
     */
    event NewAssetType(uint256 assetType, address transferManager, bytes4 selector);

    /**
     * @notice It is returned if the transfer manager is already initialized for the asset type id.
     * @dev It is only used for owner functions.
     */
    error ManagerSelectorAlreadySetForAssetType();

    /**
     * @notice It is returned if there is no transfer manager address or an empty selector.
     * @dev It is only used for owner functions.
     */
    error ManagerSelectorEmpty();

    /**
     * @notice It is returned if the NFT transfer fails.
     * @param collection Collection address
     * @param assetType Asset type id
     */
    error NFTTransferFail(address collection, uint256 assetType);

    /**
     * @notice It is returned if there is no transfer manager for the asset type.
     * @param assetType Asset type id
     */
    error NoTransferManagerForAssetType(uint256 assetType);
}
