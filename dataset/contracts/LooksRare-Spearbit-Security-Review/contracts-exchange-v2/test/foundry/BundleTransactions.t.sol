// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Other tests
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract BundleTransactionsTest is ProtocolBase {
    function testTakerAskERC721BundleNoRoyalties() public {
        _setUpUsers();
        uint256 numberItemsInBundle = 5;

        (
            OrderStructs.MakerBid memory makerBid,
            OrderStructs.TakerAsk memory takerAsk
        ) = _createMockMakerBidAndTakerAskWithBundle(address(mockERC721), address(weth), numberItemsInBundle);

        uint256 price = makerBid.maxPrice;

        // Sign the order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Mint the items
        mockERC721.batchMint(takerUser, makerBid.itemIds);

        // Execute taker ask transaction
        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        for (uint256 i; i < makerBid.itemIds.length; i++) {
            // Maker user has received all the assets in the bundle
            assertEq(mockERC721.ownerOf(makerBid.itemIds[i]), makerUser);
        }
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Royalty recipient receives no royalty
        assertEq(weth.balanceOf(_royaltyRecipient), _initialWETHBalanceRoyaltyRecipient);
        // Owner receives protocol fee
        assertEq(weth.balanceOf(_owner), _initialWETHBalanceOwner + (price * _minTotalFeeBp) / 10_000);
        // Taker ask user receives 98% of the whole price (no royalties are paid)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9_800) / 10_000);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }

    function testTakerAskERC721BundleWithRoyaltiesFromRegistry() public {
        _setUpUsers();
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);
        uint256 numberItemsInBundle = 5;

        (
            OrderStructs.MakerBid memory makerBid,
            OrderStructs.TakerAsk memory takerAsk
        ) = _createMockMakerBidAndTakerAskWithBundle(address(mockERC721), address(weth), numberItemsInBundle);

        uint256 price = makerBid.maxPrice;

        // Sign the order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Mint the items
        mockERC721.batchMint(takerUser, makerBid.itemIds);

        // Execute taker ask transaction
        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        for (uint256 i; i < makerBid.itemIds.length; i++) {
            // Maker user has received all the assets in the bundle
            assertEq(mockERC721.ownerOf(makerBid.itemIds[i]), makerUser);
        }

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Royalty recipient receives royalties
        assertEq(
            weth.balanceOf(_royaltyRecipient),
            _initialWETHBalanceRoyaltyRecipient + (price * _standardRoyaltyFee) / 10_000
        );
        // Owner receives protocol fee
        assertEq(weth.balanceOf(_owner), _initialWETHBalanceOwner + (price * _standardProtocolFeeBp) / 10_000);
        // Taker ask user receives 98% of the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9_800) / 10_000);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }

    function testTakerBidERC721BundleNoRoyalties() public {
        _setUpUsers();
        uint256 numberItemsInBundle = 5;

        (
            OrderStructs.MakerAsk memory makerAsk,
            OrderStructs.TakerBid memory takerBid
        ) = _createMockMakerAskAndTakerBidWithBundle(address(mockERC721), numberItemsInBundle);

        uint256 price = makerAsk.minPrice;

        // Mint the items and sign the order
        mockERC721.batchMint(makerUser, makerAsk.itemIds);
        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        // Execute taker bid transaction
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        for (uint256 i; i < makerAsk.itemIds.length; i++) {
            // Taker user has received all the assets in the bundle
            assertEq(mockERC721.ownerOf(makerAsk.itemIds[i]), takerUser);
        }
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - price);
        // Royalty recipient receives no royalty
        assertEq(address(_royaltyRecipient).balance, _initialETHBalanceRoyaltyRecipient);
        // Owner receives protocol fee
        assertEq(address(_owner).balance, _initialETHBalanceOwner + (price * _minTotalFeeBp) / 10_000);
        // Maker ask user receives 98% of the whole price (no royalties are paid)
        assertEq(address(makerUser).balance, _initialETHBalanceUser + (price * 9_800) / 10_000);
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerAsk.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }

    function testTakerBidERC721BundleWithRoyaltiesFromRegistry() public {
        _setUpUsers();
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);
        uint256 numberItemsInBundle = 5;

        (
            OrderStructs.MakerAsk memory makerAsk,
            OrderStructs.TakerBid memory takerBid
        ) = _createMockMakerAskAndTakerBidWithBundle(address(mockERC721), numberItemsInBundle);

        uint256 price = makerAsk.minPrice;

        // Mint the items and sign the order
        mockERC721.batchMint(makerUser, makerAsk.itemIds);
        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        // Execute taker bid transaction
        vm.prank(takerUser);

        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        for (uint256 i; i < makerAsk.itemIds.length; i++) {
            // Taker user has received all the assets in the bundle
            assertEq(mockERC721.ownerOf(makerAsk.itemIds[i]), takerUser);
        }

        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - price);
        // Royalty recipient receives the royalties
        assertEq(
            address(_royaltyRecipient).balance,
            _initialETHBalanceRoyaltyRecipient + (price * _standardRoyaltyFee) / 10_000
        );
        // Owner receives protocol fee
        assertEq(address(_owner).balance, _initialETHBalanceOwner + (price * _standardProtocolFeeBp) / 10_000);
        // Maker ask user receives 98% of the whole price
        assertEq(address(makerUser).balance, _initialETHBalanceUser + (price * 9_800) / 10_000);
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerAsk.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }
}
