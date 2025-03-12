// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Generic interfaces
import {IERC165} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC165.sol";

// Libraries
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";

// Other helpers
import {ProtocolHelpers} from "../utils/ProtocolHelpers.sol";

contract MockOrderGenerator is ProtocolHelpers {
    function _createMockMakerAskAndTakerBid(
        address collection
    ) internal view returns (OrderStructs.MakerAsk memory newMakerAsk, OrderStructs.TakerBid memory newTakerBid) {
        uint256 assetType;

        // If ERC1155, adjust asset type
        if (IERC165(collection).supportsInterface(0xd9b67a26)) {
            assetType = 1;
        }

        newMakerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: 0,
            assetType: assetType,
            orderNonce: 0,
            collection: collection,
            currency: address(0), // ETH
            signer: makerUser,
            minPrice: 1 ether,
            itemId: 0
        });

        newTakerBid = OrderStructs.TakerBid(
            takerUser,
            newMakerAsk.minPrice,
            newMakerAsk.itemIds,
            newMakerAsk.amounts,
            abi.encode()
        );
    }

    function _createMockMakerBidAndTakerAsk(
        address collection,
        address currency
    ) internal view returns (OrderStructs.MakerBid memory newMakerBid, OrderStructs.TakerAsk memory newTakerAsk) {
        uint256 assetType;
        // If ERC1155, adjust asset type
        if (IERC165(collection).supportsInterface(0xd9b67a26)) {
            assetType = 1;
        }

        newMakerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 0,
            assetType: assetType,
            orderNonce: 0,
            collection: collection,
            currency: currency,
            signer: makerUser,
            maxPrice: 1 ether,
            itemId: 0
        });

        newTakerAsk = OrderStructs.TakerAsk(
            takerUser,
            newMakerBid.maxPrice,
            newMakerBid.itemIds,
            newMakerBid.amounts,
            abi.encode()
        );
    }

    function _createMockMakerAskAndTakerBidWithBundle(
        address collection,
        uint256 numberTokens
    ) internal view returns (OrderStructs.MakerAsk memory newMakerAsk, OrderStructs.TakerBid memory newTakerBid) {
        uint256 assetType;

        // If ERC1155, adjust asset type
        if (IERC165(collection).supportsInterface(0xd9b67a26)) {
            assetType = 1;
        }

        uint256[] memory itemIds = new uint256[](numberTokens);
        uint256[] memory amounts = new uint256[](numberTokens);

        for (uint256 i; i < itemIds.length; i++) {
            itemIds[i] = i;
            amounts[i] = 1;
        }

        newMakerAsk = _createMultiItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: 0,
            assetType: assetType,
            orderNonce: 0,
            collection: collection,
            currency: address(0),
            signer: makerUser,
            minPrice: 1 ether,
            itemIds: itemIds,
            amounts: amounts
        });

        newTakerBid = OrderStructs.TakerBid(
            takerUser,
            newMakerAsk.minPrice,
            newMakerAsk.itemIds,
            newMakerAsk.amounts,
            abi.encode()
        );
    }

    function _createMockMakerBidAndTakerAskWithBundle(
        address collection,
        address currency,
        uint256 numberTokens
    ) internal view returns (OrderStructs.MakerBid memory newMakerBid, OrderStructs.TakerAsk memory newTakerAsk) {
        uint256 assetType;
        // If ERC1155, adjust asset type
        if (IERC165(collection).supportsInterface(0x4e2312e0)) {
            assetType = 1;
        }

        uint256[] memory itemIds = new uint256[](numberTokens);
        uint256[] memory amounts = new uint256[](numberTokens);

        for (uint256 i; i < itemIds.length; i++) {
            itemIds[i] = i;
            amounts[i] = 1;
        }

        newMakerBid = _createMultiItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 0,
            assetType: assetType,
            orderNonce: 0,
            collection: collection,
            currency: currency,
            signer: makerUser,
            maxPrice: 1 ether,
            itemIds: itemIds,
            amounts: amounts
        });

        newTakerAsk = OrderStructs.TakerAsk(
            takerUser,
            newMakerBid.maxPrice,
            newMakerBid.itemIds,
            newMakerBid.amounts,
            abi.encode()
        );
    }
}
