// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries, interfaces, errors
import {ITransferSelectorNFT} from "../../contracts/interfaces/ITransferSelectorNFT.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {WrongLengths} from "../../contracts/interfaces/SharedErrors.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract StandardTransactionsTest is ProtocolBase {
    /**
     * One ERC721 (where royalties come from the registry) is sold through a taker bid
     */
    function testTakerBidERC721WithRoyaltiesFromRegistry(uint256 price) public {
        vm.assume(price <= 2 ether);
        _setUpUsers();
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);

        uint256 itemId = 42;

        // Mint asset
        mockERC721.mint(makerUser, itemId);

        // Prepare the orders and signature
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

        // Verify validity of maker ask order
        _isMakerAskOrderValid(makerAsk, signature);

        // Arrays for events
        uint256[3] memory expectedFees;
        address[3] memory expectedRecipients;

        expectedFees[0] = (price * _standardProtocolFeeBp) / 10_000;
        expectedFees[1] = (price * _standardRoyaltyFee) / 10_000;
        if (expectedFees[0] + expectedFees[1] < ((price * _minTotalFeeBp) / 10000)) {
            expectedFees[0] = ((price * _minTotalFeeBp) / 10000) - expectedFees[1];
        }
        expectedFees[2] = price - (expectedFees[1] + expectedFees[0]);

        expectedRecipients[0] = _owner;
        expectedRecipients[1] = _royaltyRecipient;
        expectedRecipients[2] = makerUser;

        // Execute taker bid transaction
        vm.prank(takerUser);
        vm.expectEmit(true, false, false, true);

        emit TakerBid(
            SignatureParameters({
                orderHash: _computeOrderHashMakerAsk(makerAsk),
                orderNonce: makerAsk.orderNonce,
                isNonceInvalidated: true
            }),
            takerUser,
            takerUser,
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

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(itemId), takerUser);
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - price);
        // Maker ask user receives 98% of the whole price (2%)
        assertEq(address(makerUser).balance, _initialETHBalanceUser + expectedFees[2]);
        // Royalty recipient receives 0.5% of the whole price
        assertEq(address(_royaltyRecipient).balance, _initialETHBalanceRoyaltyRecipient + expectedFees[1]);
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerAsk.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }

    /**
     * One ERC721 is sold through taker bid. Address zero is specified as the recipient in the taker struct.
     */
    function testTakerBidERC721WithAddressZeroSpecifiedAsRecipient(uint256 price) public {
        vm.assume(price <= 2 ether);
        _setUpUsers();
        uint256 itemId = 42;

        // Mint asset
        mockERC721.mint(makerUser, itemId);

        // Prepare the orders and signature
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

        // Adjustment
        takerBid.recipient = address(0);

        // Verify validity of maker ask order
        _isMakerAskOrderValid(makerAsk, signature);

        // Arrays for events
        uint256[3] memory expectedFees;
        address[3] memory expectedRecipients;

        expectedFees[0] = (price * _minTotalFeeBp) / 10_000; // 2% is paid instead of 1.5%
        expectedFees[1] = 0; // No royalties
        if (expectedFees[0] + expectedFees[1] < ((price * _minTotalFeeBp) / 10000)) {
            expectedFees[0] = ((price * _minTotalFeeBp) / 10000) - expectedFees[1];
        }
        expectedFees[2] = price - (expectedFees[1] + expectedFees[0]);

        expectedRecipients[0] = _owner;
        expectedRecipients[1] = address(0); // No royalties
        expectedRecipients[2] = makerUser;

        // Execute taker bid transaction
        vm.prank(takerUser);
        vm.expectEmit(true, false, false, true);

        emit TakerBid(
            SignatureParameters({
                orderHash: _computeOrderHashMakerAsk(makerAsk),
                orderNonce: makerAsk.orderNonce,
                isNonceInvalidated: true
            }),
            takerUser,
            takerUser,
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

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(itemId), takerUser);
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - price);
        // Maker ask user receives 98% of the whole price (2%)
        assertEq(address(makerUser).balance, _initialETHBalanceUser + expectedFees[2]);
    }

    /**
     * One ERC721 (where royalties come from the registry) is sold through a taker ask using WETH
     */
    function testTakerAskERC721WithRoyaltiesFromRegistry(uint256 price) public {
        vm.assume(price <= 2 ether);

        _setUpUsers();
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);

        uint256 itemId = 42;

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

        // Verify maker bid order
        _isMakerBidOrderValid(makerBid, signature);

        // Mint asset
        mockERC721.mint(takerUser, itemId);

        // Arrays for events
        uint256[3] memory expectedFees;
        address[3] memory expectedRecipients;

        expectedFees[0] = (price * _standardProtocolFeeBp) / 10_000;
        expectedFees[1] = (price * _standardRoyaltyFee) / 10_000;
        if (expectedFees[0] + expectedFees[1] < ((price * _minTotalFeeBp) / 10000)) {
            expectedFees[0] = ((price * _minTotalFeeBp) / 10000) - expectedFees[1];
        }
        expectedFees[2] = price - (expectedFees[1] + expectedFees[0]);

        expectedRecipients[0] = _owner;
        expectedRecipients[1] = _royaltyRecipient;
        expectedRecipients[2] = takerUser;

        // Execute taker ask transaction
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
        // Taker ask user receives 98% of the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + expectedFees[2]);
        // Owner receives 1.5% of the whole price
        assertEq(weth.balanceOf(_owner), _initialWETHBalanceOwner + expectedFees[0]);
        // Royalty recipient receives 0.5% of the whole price
        assertEq(weth.balanceOf(_royaltyRecipient), _initialWETHBalanceRoyaltyRecipient + expectedFees[1]);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }

    /**
     * One ERC721 is sold through a taker ask using WETH. Address zero is specified as the recipient in the taker struct.
     */
    function testTakerAskERC721WithAddressZeroSpecifiedAsRecipient(uint256 price) public {
        vm.assume(price <= 2 ether);
        _setUpUsers();

        uint256 itemId = 42;

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

        // Verify maker bid order
        _isMakerBidOrderValid(makerBid, signature);

        // Adjustment
        takerAsk.recipient = address(0);

        // Mint asset
        mockERC721.mint(takerUser, itemId);

        // Arrays for events
        uint256[3] memory expectedFees;
        address[3] memory expectedRecipients;

        expectedFees[0] = (price * _minTotalFeeBp) / 10_000; // 2% is paid instead of 1.5%
        expectedFees[1] = 0; // No royalties
        if (expectedFees[0] + expectedFees[1] < ((price * _minTotalFeeBp) / 10000)) {
            expectedFees[0] = ((price * _minTotalFeeBp) / 10000) - expectedFees[1];
        }
        expectedFees[2] = price - (expectedFees[1] + expectedFees[0]);

        expectedRecipients[0] = _owner;
        expectedRecipients[1] = address(0); // No royalties
        expectedRecipients[2] = takerUser;

        // Execute taker ask transaction
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
        // Taker ask user receives 98% of the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + expectedFees[2]);
    }

    /**
     * Three ERC721 are sold through 3 taker bids in one transaction with non-atomicity.
     */
    function testThreeTakerBidsERC721() public {
        uint256 price = 0.015 ether;
        _setUpUsers();

        uint256 numberPurchases = 3;

        OrderStructs.MakerAsk[] memory makerAsks = new OrderStructs.MakerAsk[](numberPurchases);
        OrderStructs.TakerBid[] memory takerBids = new OrderStructs.TakerBid[](numberPurchases);
        bytes[] memory signatures = new bytes[](numberPurchases);

        for (uint256 i; i < numberPurchases; i++) {
            // Mint asset
            mockERC721.mint(makerUser, i);

            // Prepare the order hash
            makerAsks[i] = _createSingleItemMakerAskOrder({
                askNonce: 0,
                subsetNonce: 0,
                strategyId: 0, // Standard sale for fixed price
                assetType: 0, // ERC721
                orderNonce: i,
                collection: address(mockERC721),
                currency: address(0), // ETH
                signer: makerUser,
                minPrice: price, // Fixed
                itemId: i // (0, 1, etc.)
            });

            // Sign order
            signatures[i] = _signMakerAsk(makerAsks[i], makerUserPK);

            takerBids[i] = OrderStructs.TakerBid(
                takerUser,
                makerAsks[i].minPrice,
                makerAsks[i].itemIds,
                makerAsks[i].amounts,
                abi.encode()
            );
        }

        // Other execution parameters
        OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](numberPurchases);

        // Execute taker bid transaction
        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
            takerBids,
            makerAsks,
            signatures,
            merkleTrees,
            _EMPTY_AFFILIATE,
            false
        );

        for (uint256 i; i < numberPurchases; i++) {
            // Taker user has received the asset
            assertEq(mockERC721.ownerOf(i), takerUser);
            // Verify the nonce is marked as executed
            assertEq(looksRareProtocol.userOrderNonce(makerUser, i), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
        }

        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - (numberPurchases * price));
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(address(makerUser).balance, _initialETHBalanceUser + ((price * 9_800) * numberPurchases) / 10_000);
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
    }

    /**
     * Transaction cannot go through if atomic, goes through if non-atomic (fund returns to buyer).
     */
    function testThreeTakerBidsERC721OneFails() public {
        uint256 price = 1.4 ether;

        _setUpUsers();

        uint256 numberPurchases = 3;
        uint256 faultyTokenId = numberPurchases - 1;

        OrderStructs.MakerAsk[] memory makerAsks = new OrderStructs.MakerAsk[](numberPurchases);
        OrderStructs.TakerBid[] memory takerBids = new OrderStructs.TakerBid[](numberPurchases);
        bytes[] memory signatures = new bytes[](numberPurchases);

        for (uint256 i; i < numberPurchases; i++) {
            // Mint asset
            mockERC721.mint(makerUser, i);

            // Prepare the order hash
            makerAsks[i] = _createSingleItemMakerAskOrder({
                askNonce: 0,
                subsetNonce: 0,
                strategyId: 0, // Standard sale for fixed price
                assetType: 0, // ERC721
                orderNonce: i,
                collection: address(mockERC721),
                currency: address(0), // ETH
                signer: makerUser,
                minPrice: price, // Fixed
                itemId: i // (0, 1, etc.)
            });

            // Sign order
            signatures[i] = _signMakerAsk(makerAsks[i], makerUserPK);

            takerBids[i] = OrderStructs.TakerBid(
                takerUser,
                makerAsks[i].minPrice,
                makerAsks[i].itemIds,
                makerAsks[i].amounts,
                abi.encode()
            );
        }

        // Transfer tokenId = 2 to random user
        address randomUser = address(55);
        vm.prank(makerUser);
        mockERC721.transferFrom(makerUser, randomUser, faultyTokenId);

        /**
         * 1. The whole purchase fails if execution is atomic
         */
        {
            // Other execution parameters
            OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](numberPurchases);

            // NFTTransferFail(address collection, uint256 assetType);
            vm.expectRevert(
                abi.encodeWithSelector(
                    ITransferSelectorNFT.NFTTransferFail.selector,
                    makerAsks[faultyTokenId].collection,
                    0
                )
            );
            vm.prank(takerUser);
            looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
                takerBids,
                makerAsks,
                signatures,
                merkleTrees,
                _EMPTY_AFFILIATE,
                true
            );
        }

        /**
         * 2. The whole purchase doesn't fail if execution is not-atomic
         */
        {
            // Other execution parameters
            OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](numberPurchases);

            vm.prank(takerUser);
            // Execute taker bid transaction
            looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
                takerBids,
                makerAsks,
                signatures,
                merkleTrees,
                _EMPTY_AFFILIATE,
                false
            );
        }

        for (uint256 i; i < faultyTokenId; i++) {
            // Taker user has received the first two assets
            assertEq(mockERC721.ownerOf(i), takerUser);
            // Verify the first two nonces are marked as executed
            assertEq(looksRareProtocol.userOrderNonce(makerUser, i), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
        }

        // Taker user has not received the asset
        assertEq(mockERC721.ownerOf(faultyTokenId), randomUser);
        // Verify the nonce is NOT marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, faultyTokenId), bytes32(0));
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - 1 - ((numberPurchases - 1) * price));
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(
            address(makerUser).balance,
            _initialETHBalanceUser + ((price * 9_800) * (numberPurchases - 1)) / 10_000
        );
        // 1 wei left in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 1);
    }

    function testThreeTakerBidsERC721WrongLengths() public {
        _setUpUsers();

        uint256 price = 1.12121111111 ether;
        uint256 numberPurchases = 3;

        OrderStructs.TakerBid[] memory takerBids = new OrderStructs.TakerBid[](numberPurchases);
        bytes[] memory signatures = new bytes[](numberPurchases);
        OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](numberPurchases);

        // 1. Wrong maker asks length
        OrderStructs.MakerAsk[] memory makerAsks = new OrderStructs.MakerAsk[](numberPurchases - 1);

        vm.expectRevert(WrongLengths.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
            takerBids,
            makerAsks,
            signatures,
            merkleTrees,
            _EMPTY_AFFILIATE,
            false
        );

        // 2. Wrong signatures length
        makerAsks = new OrderStructs.MakerAsk[](numberPurchases);
        signatures = new bytes[](numberPurchases - 1);

        vm.expectRevert(WrongLengths.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
            takerBids,
            makerAsks,
            signatures,
            merkleTrees,
            _EMPTY_AFFILIATE,
            false
        );

        // 3. Wrong merkle trees length
        signatures = new bytes[](numberPurchases);
        merkleTrees = new OrderStructs.MerkleTree[](numberPurchases - 1);

        vm.expectRevert(WrongLengths.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
            takerBids,
            makerAsks,
            signatures,
            merkleTrees,
            _EMPTY_AFFILIATE,
            false
        );
    }
}
