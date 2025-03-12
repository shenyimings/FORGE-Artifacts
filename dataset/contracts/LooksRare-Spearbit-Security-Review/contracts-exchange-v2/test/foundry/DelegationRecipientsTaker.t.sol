// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries and interfaces
import {ITransferSelectorNFT} from "../../contracts/interfaces/ITransferSelectorNFT.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract DelegationRecipientsTakerTest is ProtocolBase {
    // Fixed price of sale
    uint256 private constant price = 1 ether;

    /**
     * One ERC721 is sold through a taker ask using WETH and the proceeds of the sale goes to a random recipient.
     */
    function testTakerAskERC721WithRoyaltiesFromRegistryWithDelegation() public {
        _setUpUsers();
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);
        address randomRecipientSaleProceeds = address(420);
        uint256 itemId = 0;

        // Mint asset
        mockERC721.mint(takerUser, itemId);

        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk, bytes memory signature) = _createSingleItemMakerBidAndTakerAskOrderAndSignature({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 0, // Standard sale for fixed price
            assetType: 0, // ERC721
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: itemId
        });

        // Adjust recipient
        takerAsk.recipient = randomRecipientSaleProceeds;

        // Verify maker bid order
        _isMakerBidOrderValid(makerBid, signature);

        // Arrays for events
        address[3] memory expectedRecipients;
        expectedRecipients[0] = _owner;
        expectedRecipients[1] = _royaltyRecipient;
        expectedRecipients[2] = randomRecipientSaleProceeds;

        uint256[3] memory expectedFees;
        expectedFees[0] = (price * _standardProtocolFeeBp) / 10_000;
        expectedFees[1] = (price * _standardRoyaltyFee) / 10_000;
        expectedFees[2] = price - (expectedFees[1] + expectedFees[0]);

        vm.prank(takerUser);
        vm.expectEmit(true, false, false, true);

        emit TakerAsk(
            SignatureParameters({
                orderHash: _computeOrderHashMakerBid(makerBid),
                orderNonce: makerBid.orderNonce,
                isNonceInvalidated: true
            }),
            takerUser,
            makerUser,
            makerBid.strategyId,
            makerBid.currency,
            makerBid.collection,
            makerBid.itemIds,
            makerBid.amounts,
            expectedRecipients,
            expectedFees
        );
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(itemId), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Random recipient user receives 98% of the whole price and taker user receives nothing.
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser);
        assertEq(weth.balanceOf(randomRecipientSaleProceeds), (price * 9_800) / 10_000);
        // Royalty recipient receives 0.5% of the whole price
        assertEq(
            weth.balanceOf(_royaltyRecipient),
            _initialWETHBalanceRoyaltyRecipient + (price * _standardRoyaltyFee) / 10_000
        );
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }

    /**
     * One ERC721 is sold through a taker bid and the NFT transfer goes to a random recipient.
     */
    function testTakerBidERC721WithRoyaltiesFromRegistryWithDelegation() public {
        address randomRecipientNFT = address(420);
        uint256 itemId = 0;

        _setUpUsers();
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);

        // Mint asset
        mockERC721.mint(makerUser, itemId);

        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid, bytes memory signature) = _createSingleItemMakerAskAndTakerBidOrderAndSignature({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: 0, // Standard sale for fixed price
            assetType: 0, // ERC721
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(0), // ETH
            signer: makerUser,
            minPrice: price,
            itemId: itemId
        });

        // Adjust recipient to random recipient
        takerBid.recipient = randomRecipientNFT;

        // Verify validity of maker ask order
        _isMakerAskOrderValid(makerAsk, signature);

        // Arrays for events
        address[3] memory expectedRecipients;
        expectedRecipients[0] = _owner;
        expectedRecipients[1] = _royaltyRecipient;
        expectedRecipients[2] = makerUser;

        uint256[3] memory expectedFees;
        expectedFees[0] = (price * _standardProtocolFeeBp) / 10_000;
        expectedFees[1] = (price * _standardRoyaltyFee) / 10_000;
        expectedFees[2] = price - (expectedFees[1] + expectedFees[0]);

        vm.prank(takerUser);

        emit TakerBid(
            SignatureParameters({
                orderHash: _computeOrderHashMakerAsk(makerAsk),
                orderNonce: makerAsk.orderNonce,
                isNonceInvalidated: true
            }),
            takerUser,
            randomRecipientNFT,
            makerAsk.strategyId,
            makerAsk.currency,
            makerAsk.collection,
            makerAsk.itemIds,
            makerAsk.amounts,
            expectedRecipients,
            expectedFees
        );

        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        // Random recipient user has received the asset
        assertEq(mockERC721.ownerOf(itemId), randomRecipientNFT);
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - price);
        // Maker ask user receives 98% of the whole price (2%)
        assertEq(address(makerUser).balance, _initialETHBalanceUser + (price * 9_800) / 10_000);
        // Royalty recipient receives 0.5% of the whole price
        assertEq(
            address(_royaltyRecipient).balance,
            _initialETHBalanceRoyaltyRecipient + (price * _standardRoyaltyFee) / 10_000
        );
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerAsk.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }
}
