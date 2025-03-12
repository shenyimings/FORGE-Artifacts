// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";

// Other tests
import {TestHelpers} from "./TestHelpers.sol";
import {TestParameters} from "./TestParameters.sol";

contract ProtocolHelpers is TestHelpers, TestParameters {
    using OrderStructs for OrderStructs.MakerAsk;
    using OrderStructs for OrderStructs.MakerBid;
    using OrderStructs for OrderStructs.MerkleTree;

    receive() external payable {}

    bytes32 internal _domainSeparator;

    function _createSingleItemMakerAskAndTakerBidOrderAndSignature(
        uint256 askNonce,
        uint256 subsetNonce,
        uint256 strategyId,
        uint256 assetType,
        uint256 orderNonce,
        address collection,
        address currency,
        address signer,
        uint256 minPrice,
        uint256 itemId
    )
        internal
        view
        returns (
            OrderStructs.MakerAsk memory newMakerAsk,
            OrderStructs.TakerBid memory newTakerBid,
            bytes memory signature
        )
    {
        newMakerAsk = _createSingleItemMakerAskOrder(
            askNonce,
            subsetNonce,
            strategyId,
            assetType,
            orderNonce,
            collection,
            currency,
            signer,
            minPrice,
            itemId
        );

        signature = _signMakerAsk(newMakerAsk, makerUserPK);

        newTakerBid = OrderStructs.TakerBid(
            takerUser,
            newMakerAsk.minPrice,
            newMakerAsk.itemIds,
            newMakerAsk.amounts,
            abi.encode()
        );
    }

    function _createSingleItemMakerAskOrder(
        uint256 askNonce,
        uint256 subsetNonce,
        uint256 strategyId,
        uint256 assetType,
        uint256 orderNonce,
        address collection,
        address currency,
        address signer,
        uint256 minPrice,
        uint256 itemId
    ) internal view returns (OrderStructs.MakerAsk memory newMakerAsk) {
        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        newMakerAsk = OrderStructs.MakerAsk({
            askNonce: askNonce,
            subsetNonce: subsetNonce,
            strategyId: strategyId,
            assetType: assetType,
            orderNonce: orderNonce,
            collection: collection,
            currency: currency,
            signer: signer,
            startTime: block.timestamp,
            endTime: block.timestamp + 1,
            minPrice: minPrice,
            itemIds: itemIds,
            amounts: amounts,
            additionalParameters: abi.encode()
        });
    }

    function _createMultiItemMakerAskOrder(
        uint256 askNonce,
        uint256 subsetNonce,
        uint256 strategyId,
        uint256 assetType,
        uint256 orderNonce,
        address collection,
        address currency,
        address signer,
        uint256 minPrice,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) internal view returns (OrderStructs.MakerAsk memory newMakerAsk) {
        newMakerAsk = OrderStructs.MakerAsk({
            askNonce: askNonce,
            subsetNonce: subsetNonce,
            strategyId: strategyId,
            assetType: assetType,
            orderNonce: orderNonce,
            collection: collection,
            currency: currency,
            signer: signer,
            startTime: block.timestamp,
            endTime: block.timestamp + 1,
            minPrice: minPrice,
            itemIds: itemIds,
            amounts: amounts,
            additionalParameters: abi.encode()
        });
    }

    function _createSingleItemMakerBidAndTakerAskOrderAndSignature(
        uint256 bidNonce,
        uint256 subsetNonce,
        uint256 strategyId,
        uint256 assetType,
        uint256 orderNonce,
        address collection,
        address currency,
        address signer,
        uint256 maxPrice,
        uint256 itemId
    )
        internal
        view
        returns (
            OrderStructs.MakerBid memory newMakerBid,
            OrderStructs.TakerAsk memory newTakerAsk,
            bytes memory signature
        )
    {
        newMakerBid = _createSingleItemMakerBidOrder(
            bidNonce,
            subsetNonce,
            strategyId,
            assetType,
            orderNonce,
            collection,
            currency,
            signer,
            maxPrice,
            itemId
        );

        signature = _signMakerBid(newMakerBid, makerUserPK);

        newTakerAsk = OrderStructs.TakerAsk(
            takerUser,
            newMakerBid.maxPrice,
            newMakerBid.itemIds,
            newMakerBid.amounts,
            abi.encode()
        );
    }

    function _createSingleItemMakerBidOrder(
        uint256 bidNonce,
        uint256 subsetNonce,
        uint256 strategyId,
        uint256 assetType,
        uint256 orderNonce,
        address collection,
        address currency,
        address signer,
        uint256 maxPrice,
        uint256 itemId
    ) internal view returns (OrderStructs.MakerBid memory newMakerBid) {
        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        newMakerBid = OrderStructs.MakerBid({
            bidNonce: bidNonce,
            subsetNonce: subsetNonce,
            strategyId: strategyId,
            assetType: assetType,
            orderNonce: orderNonce,
            collection: collection,
            currency: currency,
            signer: signer,
            startTime: block.timestamp,
            endTime: block.timestamp + 1,
            maxPrice: maxPrice,
            itemIds: itemIds,
            amounts: amounts,
            additionalParameters: abi.encode()
        });
    }

    function _createMultiItemMakerBidOrder(
        uint256 bidNonce,
        uint256 subsetNonce,
        uint256 strategyId,
        uint256 assetType,
        uint256 orderNonce,
        address collection,
        address currency,
        address signer,
        uint256 maxPrice,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) internal view returns (OrderStructs.MakerBid memory newMakerBid) {
        newMakerBid = OrderStructs.MakerBid({
            bidNonce: bidNonce,
            subsetNonce: subsetNonce,
            strategyId: strategyId,
            assetType: assetType,
            orderNonce: orderNonce,
            collection: collection,
            currency: currency,
            signer: signer,
            startTime: block.timestamp,
            endTime: block.timestamp + 1,
            maxPrice: maxPrice,
            itemIds: itemIds,
            amounts: amounts,
            additionalParameters: abi.encode()
        });
    }

    function _signMakerAsk(
        OrderStructs.MakerAsk memory _makerAsk,
        uint256 _signerKey
    ) internal view returns (bytes memory) {
        bytes32 orderHash = _makerAsk.hash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _signerKey,
            keccak256(abi.encodePacked("\x19\x01", _domainSeparator, orderHash))
        );

        return abi.encodePacked(r, s, v);
    }

    function _signMakerBid(
        OrderStructs.MakerBid memory _makerBid,
        uint256 _signerKey
    ) internal view returns (bytes memory) {
        bytes32 orderHash = _computeOrderHashMakerBid(_makerBid);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _signerKey,
            keccak256(abi.encodePacked("\x19\x01", _domainSeparator, orderHash))
        );

        return abi.encodePacked(r, s, v);
    }

    function _signMerkleProof(
        OrderStructs.MerkleTree memory _merkleTree,
        uint256 _signerKey
    ) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _signerKey,
            keccak256(abi.encodePacked("\x19\x01", _domainSeparator, _merkleTree.hash()))
        );

        return abi.encodePacked(r, s, v);
    }

    function _computeOrderHashMakerAsk(OrderStructs.MakerAsk memory _makerAsk) internal pure returns (bytes32) {
        return _makerAsk.hash();
    }

    function _computeOrderHashMakerBid(OrderStructs.MakerBid memory _makerBid) internal pure returns (bytes32) {
        return _makerBid.hash();
    }
}
