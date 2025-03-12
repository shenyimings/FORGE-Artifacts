// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Direct dependencies
import {ExecutionManager} from "./ExecutionManager.sol";
import {PackableReentrancyGuard} from "@looksrare/contracts-libs/contracts/PackableReentrancyGuard.sol";

// Interfaces
import {ITransferSelectorNFT} from "./interfaces/ITransferSelectorNFT.sol";

/**
 * @title TransferSelectorNFT
 * @notice This contract handles the logic for transferring non-fungible items.
 * @author LooksRare protocol team (ðŸ‘€,ðŸ’Ž)
 */
contract TransferSelectorNFT is ITransferSelectorNFT, ExecutionManager, PackableReentrancyGuard {
    /**
     * @notice It returns the transfer manager address and the associated bytes4
     * selector used to transfer assets for this asset type.
     */
    mapping(uint256 => ManagerSelector) public managerSelectorOfAssetType;

    /**
     * @notice Constructor
     * @param _owner Owner address
     * @param transferManager Address of the transfer manager for ERC721/ERC1155
     */
    constructor(address _owner, address transferManager) ExecutionManager(_owner) {
        // Transfer manager with selectors for ERC721/ERC1155
        managerSelectorOfAssetType[0] = ManagerSelector({transferManager: transferManager, selector: 0xa7bc96d3});
        managerSelectorOfAssetType[1] = ManagerSelector({transferManager: transferManager, selector: 0xa0a406c6});
    }

    /**
     * @notice This function allows the owner to add new transfer manager implementations for new asset types.
     * @param assetType Asset type
     * @param transferManagerForAssetType Transfer manager address for this asset type
     * @param selectorForAssetType Selector for the function to call to transfer this asset type
     * @dev Only callable by owner.
     */
    function addTransferManagerForAssetType(
        uint256 assetType,
        address transferManagerForAssetType,
        bytes4 selectorForAssetType
    ) external onlyOwner {
        if (
            transferManagerForAssetType == address(0) ||
            transferManagerForAssetType == address(this) ||
            selectorForAssetType == bytes4(0)
        ) {
            revert ManagerSelectorEmpty();
        }

        if (managerSelectorOfAssetType[assetType].transferManager != address(0)) {
            revert ManagerSelectorAlreadySetForAssetType();
        }

        managerSelectorOfAssetType[assetType] = ManagerSelector({
            transferManager: transferManagerForAssetType,
            selector: selectorForAssetType
        });

        emit NewAssetType(assetType, transferManagerForAssetType, selectorForAssetType);
    }

    /**
     * @notice This function is internal and used to transfer non-fungible tokens.
     * @param collection Collection address
     * @param assetType Asset type (e.g. 0 = ERC721, 1 = ERC1155)
     * @param sender Sender address
     * @param recipient Recipient address
     * @param itemIds Array of itemIds
     * @param amounts Array of amounts
     */
    function _transferNFT(
        address collection,
        uint256 assetType,
        address sender,
        address recipient,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) internal {
        address transferManager = managerSelectorOfAssetType[assetType].transferManager;

        if (transferManager == address(0)) {
            revert NoTransferManagerForAssetType(assetType);
        }

        (bool status, ) = transferManager.call(
            abi.encodeWithSelector(
                managerSelectorOfAssetType[assetType].selector,
                collection,
                sender,
                recipient,
                itemIds,
                amounts
            )
        );

        if (!status) {
            revert NFTTransferFail(collection, assetType);
        }
    }
}
