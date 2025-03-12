// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Libraries
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Interfaces
import {IAffiliateManager} from "../../contracts/interfaces/IAffiliateManager.sol";

// Mocks and other tests
import {ProtocolBase} from "./ProtocolBase.t.sol";
import {MockERC20} from "../mock/MockERC20.sol";

contract AffiliateOrdersTest is ProtocolBase, IAffiliateManager {
    // Affiliate rate
    uint256 internal _affiliateRate = 2_000;
    uint256 private constant price = 1 ether; // Fixed price of sale

    function _calculateAffiliateFee(
        uint256 originalAmount,
        uint256 tierRate
    ) private pure returns (uint256 affiliateFee) {
        affiliateFee = (originalAmount * tierRate) / (10_000 * 10_000);
    }

    function _setUpAffiliate() private {
        vm.startPrank(_owner);
        looksRareProtocol.updateAffiliateController(_owner);
        looksRareProtocol.updateAffiliateProgramStatus(true);
        looksRareProtocol.updateAffiliateRate(_affiliate, _affiliateRate);
        vm.stopPrank();

        vm.deal(_affiliate, _initialETHBalanceAffiliate + _initialWETHBalanceAffiliate);
        vm.prank(_affiliate);
        weth.deposit{value: _initialWETHBalanceAffiliate}();
    }

    function testEventsAreEmittedAsExpected() public asPrankedUser(_owner) {
        // 1. NewAffiliateController
        vm.expectEmit(true, false, false, true);
        emit NewAffiliateController(_owner);
        looksRareProtocol.updateAffiliateController(_owner);

        // 2. NewAffiliateProgramStatus
        vm.expectEmit(true, false, false, true);
        emit NewAffiliateProgramStatus(true);
        looksRareProtocol.updateAffiliateProgramStatus(true);

        vm.expectEmit(true, false, false, true);
        emit NewAffiliateProgramStatus(false);
        looksRareProtocol.updateAffiliateProgramStatus(false);

        // 3. NewAffiliateRate
        vm.expectEmit(true, false, false, true);
        emit NewAffiliateRate(takerUser, 30);
        looksRareProtocol.updateAffiliateRate(takerUser, 30);
    }

    function testCannotUpdateAffiliateRateIfNotAffiliateController() public {
        vm.expectRevert(IAffiliateManager.NotAffiliateController.selector);
        looksRareProtocol.updateAffiliateRate(address(42), 100);
    }

    function testCannotUpdateAffiliateRateIfRateHigherthan10000() public asPrankedUser(_owner) {
        looksRareProtocol.updateAffiliateController(_owner);

        address randomAffiliate = address(42);
        uint256 affiliateRateLimitBp = 10000;
        vm.expectRevert(IAffiliateManager.PercentageTooHigh.selector);
        looksRareProtocol.updateAffiliateRate(randomAffiliate, affiliateRateLimitBp + 1);

        // It does not revert
        looksRareProtocol.updateAffiliateRate(randomAffiliate, affiliateRateLimitBp);
        assertEq(looksRareProtocol.affiliateRates(randomAffiliate), affiliateRateLimitBp);
    }

    function testUpdateAffiliateControllerNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.updateAffiliateController(address(0));
    }

    function testUpdateAffiliateProgramStatusNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.updateAffiliateProgramStatus(false);
    }

    /**
     * TakerBid matches makerAsk. Protocol fee is set, no royalties, affiliate is set.
     */
    function testTakerBidERC721WithAffiliateButWithoutRoyalty() public {
        _setUpUsers();
        _setUpAffiliate();

        uint256 itemId = 0;

        // Mint asset
        mockERC721.mint(makerUser, itemId);

        // Prepare the order hash
        OrderStructs.MakerAsk memory makerAsk = _createSingleItemMakerAskOrder({
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

        // Sign order
        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        // Prepare the taker bid
        OrderStructs.TakerBid memory takerBid = OrderStructs.TakerBid(
            takerUser,
            makerAsk.minPrice,
            makerAsk.itemIds,
            makerAsk.amounts,
            abi.encode()
        );

        uint256 expectedAffiliateFeeAmount = _calculateAffiliateFee(price * _minTotalFeeBp, _affiliateRate);

        // Execute taker bid transaction
        vm.prank(takerUser);
        vm.expectEmit(true, false, false, true);
        emit AffiliatePayment(_affiliate, makerAsk.currency, expectedAffiliateFeeAmount);
        looksRareProtocol.executeTakerBid{value: price}(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _affiliate);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(itemId), takerUser);
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - price);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(address(makerUser).balance, _initialETHBalanceUser + (price * (10_000 - _minTotalFeeBp)) / 10_000);
        // Affiliate user receives 20% of protocol fee
        assertEq(address(_affiliate).balance, _initialETHBalanceAffiliate + expectedAffiliateFeeAmount);
        // Owner receives 80% of protocol fee
        assertEq(
            address(_owner).balance,
            _initialETHBalanceOwner + ((price * _minTotalFeeBp) / 10_000 - expectedAffiliateFeeAmount)
        );
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerAsk.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }

    /**
     * Multiple takerBids match makerAsk orders. Protocol fee is set, no royalties, affiliate is set.
     */
    function testMultipleTakerBidsERC721WithAffiliateButWithoutRoyalty() public {
        _setUpUsers();
        _setUpAffiliate();

        uint256 numberPurchases = 8;
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
                minPrice: price,
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

        // Transfer tokenId=2 to random user
        address randomUser = address(55);

        vm.prank(makerUser);
        mockERC721.transferFrom(makerUser, randomUser, faultyTokenId);

        // Other execution parameters
        OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](numberPurchases);

        uint256 expectedAffiliateFeeAmount = _calculateAffiliateFee(
            (numberPurchases - 1) * price * _minTotalFeeBp,
            _affiliateRate
        );

        // Execute taker bid transaction
        vm.prank(takerUser);
        vm.expectEmit(true, false, false, true);
        emit AffiliatePayment(_affiliate, makerAsks[0].currency, expectedAffiliateFeeAmount);
        looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
            takerBids,
            makerAsks,
            signatures,
            merkleTrees,
            _affiliate,
            false
        );

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
        // Affiliate user receives 20% of protocol fee
        assertEq(address(_affiliate).balance, _initialETHBalanceAffiliate + expectedAffiliateFeeAmount);
        // Owner receives 80% of protocol fee
        assertEq(
            address(_owner).balance,
            _initialETHBalanceOwner +
                (((numberPurchases - 1) * (price * _minTotalFeeBp)) / 10_000 - expectedAffiliateFeeAmount)
        );
        // Only 1 wei left in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 1);
    }

    /**
     * TakerAsk matches makerBid. Protocol fee is set, no royalties, affiliate is set.
     */
    function testTakerAskERC721WithAffiliateButWithoutRoyalty() public {
        _setUpUsers();
        _setUpAffiliate();

        uint256 itemId = 0;

        // Prepare the order hash
        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
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

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Mint asset
        mockERC721.mint(takerUser, itemId);

        // Prepare the taker ask
        OrderStructs.TakerAsk memory takerAsk = OrderStructs.TakerAsk(
            takerUser,
            makerBid.maxPrice,
            makerBid.itemIds,
            makerBid.amounts,
            abi.encode()
        );

        uint256 expectedAffiliateFeeAmount = _calculateAffiliateFee(price * _minTotalFeeBp, _affiliateRate);

        // Execute taker ask transaction
        vm.prank(takerUser);
        vm.expectEmit(true, false, false, true);
        emit AffiliatePayment(_affiliate, makerBid.currency, expectedAffiliateFeeAmount);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _affiliate);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(itemId), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Taker ask user receives 98% of whole price (protocol fee)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9_800) / 10_000);
        // Affiliate user receives 20% of protocol fee
        assertEq(weth.balanceOf(_affiliate), _initialWETHBalanceAffiliate + expectedAffiliateFeeAmount);
        // Owner receives 80% of protocol fee
        assertEq(
            weth.balanceOf(_owner),
            _initialWETHBalanceOwner + ((price * _minTotalFeeBp) / 10_000 - expectedAffiliateFeeAmount)
        );
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }
}
