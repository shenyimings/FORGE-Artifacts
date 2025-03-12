// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {IERC721} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC721.sol";

// Libraries and interfaces
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {ICreatorFeeManager} from "../../contracts/interfaces/ICreatorFeeManager.sol";
import {IExecutionManager} from "../../contracts/interfaces/IExecutionManager.sol";

// Shared errors
import {BUNDLE_ERC2981_NOT_SUPPORTED} from "../../contracts/helpers/ValidationCodeConstants.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract CreatorFeeManagerWithRebatesTest is ProtocolBase {
    function _setUpRoyaltiesRegistry(uint256 fee) private {
        vm.prank(_owner);
        royaltyFeeRegistry.updateRoyaltyInfoForCollection(
            address(mockERC721),
            _royaltyRecipient,
            _royaltyRecipient,
            fee
        );
    }

    function _testCreatorFeeRebatesArePaid(address erc721) private {
        _setUpUsers();

        // Parameters
        uint256 price = 1 ether;
        uint256 itemId = 42;

        if (erc721 == address(mockERC721)) {
            // Adjust royalties
            _setUpRoyaltiesRegistry(_standardRoyaltyFee);
            // Mint asset
            mockERC721.mint(takerUser, itemId);
        } else if (erc721 == address(mockERC721WithRoyalties)) {
            // Adjust ERC721 with royalties
            mockERC721WithRoyalties.addCustomRoyaltyInformationForTokenId(
                itemId,
                _royaltyRecipient,
                _standardRoyaltyFee
            );
            // Mint asset
            mockERC721WithRoyalties.mint(takerUser, itemId);
        }

        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk, bytes memory signature) = _createSingleItemMakerBidAndTakerAskOrderAndSignature({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 0, // Standard sale for fixed price
            assetType: 0, // ERC721
            orderNonce: 0,
            collection: erc721,
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: itemId
        });

        _isMakerBidOrderValid(makerBid, signature);

        // Execute taker ask transaction
        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // Verify ownership is transferred
        assertEq(IERC721(erc721).ownerOf(itemId), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Owner receives 1.5% of the whole price
        assertEq(weth.balanceOf(_owner), _initialWETHBalanceOwner + (price * _standardProtocolFeeBp) / 10000);
        // Taker ask user receives 98% of the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9800) / 10000);
        // Royalty recipient receives 0.5% of the whole price
        assertEq(
            weth.balanceOf(_royaltyRecipient),
            _initialWETHBalanceRoyaltyRecipient + (price * _standardRoyaltyFee) / 10000
        );
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }

    function _testCreatorFeeRebatesArePaidForBundles(address erc721) private {
        _setUpUsers();
        _setUpRoyaltiesRegistry(_standardRoyaltyFee);

        // Parameters
        uint256 numberItemsInBundle = 5;

        // Create order
        (
            OrderStructs.MakerBid memory makerBid,
            OrderStructs.TakerAsk memory takerAsk
        ) = _createMockMakerBidAndTakerAskWithBundle(erc721, address(weth), numberItemsInBundle);

        // Adjust price
        uint256 price = makerBid.maxPrice;

        if (erc721 == address(mockERC721)) {
            // Adjust royalties
            _setUpRoyaltiesRegistry(_standardRoyaltyFee);
            // Mint the items
            mockERC721.batchMint(takerUser, makerBid.itemIds);
        } else if (erc721 == address(mockERC721WithRoyalties)) {
            // Adjust ERC721 with royalties
            for (uint256 i; i < makerBid.itemIds.length; i++) {
                mockERC721WithRoyalties.addCustomRoyaltyInformationForTokenId(
                    makerBid.itemIds[i],
                    _royaltyRecipient,
                    _standardRoyaltyFee
                );
            }
            // Mint the items
            mockERC721WithRoyalties.batchMint(takerUser, makerBid.itemIds);
        }

        // Sign the order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _isMakerBidOrderValid(makerBid, signature);

        // Taker user actions
        vm.prank(takerUser);

        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // Verify ownership is transferred
        for (uint256 i; i < makerBid.itemIds.length; i++) {
            // Maker user has received all the assets in the bundle
            assertEq(IERC721(erc721).ownerOf(makerBid.itemIds[i]), makerUser);
        }

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Royalty recipient receives royalties
        assertEq(
            weth.balanceOf(_royaltyRecipient),
            _initialWETHBalanceRoyaltyRecipient + (price * _standardRoyaltyFee) / 10000
        );
        // Owner receives protocol fee (1.5%)
        assertEq(weth.balanceOf(_owner), _initialWETHBalanceOwner + (price * _standardProtocolFeeBp) / 10000);
        // Taker ask user receives 98% of the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9800) / 10000);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }

    function testCreatorRebatesArePaidForRoyaltyFeeManager() public {
        _testCreatorFeeRebatesArePaid(address(mockERC721));
    }

    function testCreatorRebatesArePaidForERC2981() public {
        _testCreatorFeeRebatesArePaid(address(mockERC721WithRoyalties));
    }

    function testCreatorRebatesArePaidForRoyaltyFeeManagerWithBundles() public {
        _testCreatorFeeRebatesArePaidForBundles(address(mockERC721));
    }

    function testCreatorRoyaltiesGetPaidForERC2981WithBundles() public {
        _testCreatorFeeRebatesArePaidForBundles(address(mockERC721WithRoyalties));
    }

    function testCreatorRoyaltiesRevertForEIP2981WithBundlesIfInfoDiffer() public {
        _setUpUsers();

        uint256 numberItemsInBundle = 5;

        (
            OrderStructs.MakerBid memory makerBid,
            OrderStructs.TakerAsk memory takerAsk
        ) = _createMockMakerBidAndTakerAskWithBundle(
                address(mockERC721WithRoyalties),
                address(weth),
                numberItemsInBundle
            );

        // Sign the order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Mint the items
        mockERC721WithRoyalties.batchMint(takerUser, makerBid.itemIds);

        _isMakerBidOrderValid(makerBid, signature);

        /**
         * Different recipient
         */

        // Adjust ERC721 with royalties
        for (uint256 i; i < makerBid.itemIds.length; i++) {
            mockERC721WithRoyalties.addCustomRoyaltyInformationForTokenId(
                makerBid.itemIds[i],
                i == 0 ? _royaltyRecipient : address(50),
                50
            );
        }

        _doesMakerBidOrderReturnValidationCode(makerBid, signature, BUNDLE_ERC2981_NOT_SUPPORTED);

        vm.prank(takerUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICreatorFeeManager.BundleEIP2981NotAllowed.selector,
                address(mockERC721WithRoyalties)
            )
        );
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }
}
