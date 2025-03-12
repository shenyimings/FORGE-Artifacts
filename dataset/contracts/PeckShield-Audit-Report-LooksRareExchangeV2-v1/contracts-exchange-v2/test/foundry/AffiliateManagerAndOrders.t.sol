// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// LooksRare unopinionated libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Libraries
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Interfaces
import {IAffiliateManager} from "../../contracts/interfaces/IAffiliateManager.sol";

// Mocks and other tests
import {ProtocolBase} from "./ProtocolBase.t.sol";
import {MockERC20} from "../mock/MockERC20.sol";

// Constants
import {ONE_HUNDRED_PERCENT_IN_BP} from "../../contracts/constants/NumericConstants.sol";

// Enums
import {CollectionType} from "../../contracts/enums/CollectionType.sol";
import {QuoteType} from "../../contracts/enums/QuoteType.sol";

contract AffiliateOrdersTest is ProtocolBase, IAffiliateManager {
    function setUp() public {
        _setUp();
    }

    // Affiliate rate
    uint256 internal _affiliateRate = 2_000;
    uint256 private constant price = 1 ether; // Fixed price of sale

    function _calculateAffiliateFee(
        uint256 originalAmount,
        uint256 tierRate
    ) private pure returns (uint256 affiliateFee) {
        affiliateFee = (originalAmount * tierRate) / (ONE_HUNDRED_PERCENT_IN_BP * ONE_HUNDRED_PERCENT_IN_BP);
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
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
        emit NewAffiliateController(_owner);
        looksRareProtocol.updateAffiliateController(_owner);

        // 2. NewAffiliateProgramStatus
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
        emit NewAffiliateProgramStatus(true);
        looksRareProtocol.updateAffiliateProgramStatus(true);

        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
        emit NewAffiliateProgramStatus(false);
        looksRareProtocol.updateAffiliateProgramStatus(false);

        // 3. NewAffiliateRate
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
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
        uint256 affiliateRateLimitBp = ONE_HUNDRED_PERCENT_IN_BP;
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

        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMockMakerAskAndTakerBid(
            address(mockERC721)
        );

        // Mint asset
        mockERC721.mint(makerUser, makerAsk.itemIds[0]);

        // Sign order
        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        // Verify validity of maker ask order
        _assertValidMakerOrder(makerAsk, signature);

        uint256 expectedAffiliateFeeAmount = _calculateAffiliateFee(price * _minTotalFeeBp, _affiliateRate);

        // Execute taker bid transaction
        vm.prank(takerUser);
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
        emit AffiliatePayment(_affiliate, makerAsk.currency, expectedAffiliateFeeAmount);
        looksRareProtocol.executeTakerBid{value: price}(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _affiliate);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(makerAsk.itemIds[0]), takerUser);
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - price);
        // Maker ask user receives 99.5% of the whole price (0.5% protocol)
        assertEq(
            address(makerUser).balance,
            _initialETHBalanceUser + (price * (ONE_HUNDRED_PERCENT_IN_BP - _minTotalFeeBp)) / ONE_HUNDRED_PERCENT_IN_BP
        );
        // Affiliate user receives 20% of protocol fee
        assertEq(address(_affiliate).balance, _initialETHBalanceAffiliate + expectedAffiliateFeeAmount);
        assertEq(
            address(protocolFeeRecipient).balance,
            ((price * _minTotalFeeBp) / ONE_HUNDRED_PERCENT_IN_BP - expectedAffiliateFeeAmount),
            "ProtocolFeeRecipient should receive 80% of protocol fee"
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

        OrderStructs.Maker[] memory makerAsks = new OrderStructs.Maker[](numberPurchases);
        OrderStructs.Taker[] memory takerBids = new OrderStructs.Taker[](numberPurchases);
        bytes[] memory signatures = new bytes[](numberPurchases);

        for (uint256 i; i < numberPurchases; i++) {
            // Mint asset
            mockERC721.mint(makerUser, i);

            makerAsks[i] = _createSingleItemMakerOrder({
                quoteType: QuoteType.Ask,
                globalNonce: 0,
                subsetNonce: 0,
                strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
                collectionType: CollectionType.ERC721,
                orderNonce: i,
                collection: address(mockERC721),
                currency: ETH,
                signer: makerUser,
                price: price,
                itemId: i // (0, 1, etc.)
            });

            // Sign order
            signatures[i] = _signMakerOrder(makerAsks[i], makerUserPK);

            // Verify validity of maker ask order
            _assertValidMakerOrder(makerAsks[i], signatures[i]);

            takerBids[i] = _genericTakerOrder();
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
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
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
        // Maker ask user receives 99.5% of the whole price (0.5% protocol)
        assertEq(
            address(makerUser).balance,
            _initialETHBalanceUser +
                ((price * _sellerProceedBpWithStandardProtocolFeeBp) * (numberPurchases - 1)) /
                ONE_HUNDRED_PERCENT_IN_BP
        );
        // Affiliate user receives 20% of protocol fee
        assertEq(address(_affiliate).balance, _initialETHBalanceAffiliate + expectedAffiliateFeeAmount);
        assertEq(
            address(protocolFeeRecipient).balance,
            (((numberPurchases - 1) * (price * _minTotalFeeBp)) /
                ONE_HUNDRED_PERCENT_IN_BP -
                expectedAffiliateFeeAmount),
            "ProtocolFeeRecipient should receive 80% of protocol fee"
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

        (OrderStructs.Maker memory makerBid, OrderStructs.Taker memory takerAsk) = _createMockMakerBidAndTakerAsk(
            address(mockERC721),
            address(weth)
        );

        // Sign order
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        // Verify validity of maker bid order
        _assertValidMakerOrder(makerBid, signature);

        // Mint asset
        mockERC721.mint(takerUser, makerBid.itemIds[0]);

        uint256 expectedAffiliateFeeAmount = _calculateAffiliateFee(price * _minTotalFeeBp, _affiliateRate);

        // Execute taker ask transaction
        vm.prank(takerUser);
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
        emit AffiliatePayment(_affiliate, makerBid.currency, expectedAffiliateFeeAmount);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _affiliate);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(makerBid.itemIds[0]), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Taker ask user receives 99.5% of whole price (protocol fee)
        assertEq(
            weth.balanceOf(takerUser),
            _initialWETHBalanceUser + (price * _sellerProceedBpWithStandardProtocolFeeBp) / ONE_HUNDRED_PERCENT_IN_BP
        );
        // Affiliate user receives 20% of protocol fee
        assertEq(weth.balanceOf(_affiliate), _initialWETHBalanceAffiliate + expectedAffiliateFeeAmount);
        assertEq(
            weth.balanceOf(address(protocolFeeRecipient)),
            ((price * _minTotalFeeBp) / ONE_HUNDRED_PERCENT_IN_BP - expectedAffiliateFeeAmount),
            "ProtocolFeeRecipient should receive 80% of protocol fee"
        );
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }
}
