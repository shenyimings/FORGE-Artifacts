// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Libraries
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Core contracts
import {LooksRareProtocol} from "../../contracts/LooksRareProtocol.sol";
import {ITransferManager, TransferManager} from "../../contracts/TransferManager.sol";
import {WrongLengths} from "../../contracts/interfaces/SharedErrors.sol";

// Mocks and other utils
import {MockERC721} from "../mock/MockERC721.sol";
import {MockERC1155} from "../mock/MockERC1155.sol";
import {TestHelpers} from "./utils/TestHelpers.sol";
import {TestParameters} from "./utils/TestParameters.sol";

contract TransferManagerTest is ITransferManager, TestHelpers, TestParameters {
    address[] public operators;
    MockERC721 public mockERC721;
    MockERC1155 public mockERC1155;
    TransferManager public transferManager;

    /**
     * 0. Internal helper functions
     */

    function _grantApprovals(address user) private asPrankedUser(user) {
        mockERC721.setApprovalForAll(address(transferManager), true);
        mockERC1155.setApprovalForAll(address(transferManager), true);
        address[] memory approvedOperators = new address[](1);
        approvedOperators[0] = _transferrer;

        vm.expectEmit(true, false, false, true);
        emit ApprovalsGranted(user, approvedOperators);
        transferManager.grantApprovals(approvedOperators);
    }

    function _whitelistOperator(address transferrer) private {
        vm.prank(_owner);
        vm.expectEmit(true, false, false, true);
        emit OperatorWhitelisted(transferrer);
        transferManager.whitelistOperator(transferrer);
    }

    function setUp() public asPrankedUser(_owner) {
        transferManager = new TransferManager(_owner);
        mockERC721 = new MockERC721();
        mockERC1155 = new MockERC1155();
        operators.push(_transferrer);

        vm.deal(_transferrer, 100 ether);
        vm.deal(_sender, 100 ether);
    }

    /**
     * 1. Happy cases
     */

    function testTransferSingleItemERC721() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        uint256 itemId = 500;

        vm.prank(_sender);
        mockERC721.mint(_sender, itemId);

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        vm.prank(_transferrer);
        transferManager.transferItemsERC721(address(mockERC721), _sender, _recipient, itemIds, amounts);

        assertEq(mockERC721.ownerOf(itemId), _recipient);
    }

    function testTransferSingleItemERC1155() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        uint256 itemId = 1;
        uint256 amount = 2;

        mockERC1155.mint(_sender, itemId, amount);

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        vm.prank(_transferrer);
        transferManager.transferItemsERC1155(address(mockERC1155), _sender, _recipient, itemIds, amounts);

        assertEq(mockERC1155.balanceOf(_recipient, itemId), amount);
    }

    function testTransferBatchItemsSameERC721() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        uint256 tokenId1 = 1;
        uint256 tokenId2 = 2;

        uint256[] memory itemIds = new uint256[](2);
        itemIds[0] = tokenId1;
        itemIds[1] = tokenId2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        mockERC721.batchMint(_sender, itemIds);

        vm.prank(_transferrer);
        transferManager.transferItemsERC721(address(mockERC721), _sender, _recipient, itemIds, amounts);

        assertEq(mockERC721.ownerOf(tokenId1), _recipient);
        assertEq(mockERC721.ownerOf(tokenId2), _recipient);
    }

    function testTransferBatchItemsSameERC1155() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        uint256 tokenId1 = 1;
        uint256 amount1 = 2;
        uint256 tokenId2 = 2;
        uint256 amount2 = 5;

        mockERC1155.mint(_sender, tokenId1, amount1);
        mockERC1155.mint(_sender, tokenId2, amount2);

        uint256[] memory itemIds = new uint256[](2);
        itemIds[0] = tokenId1;
        itemIds[1] = tokenId2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        vm.prank(_transferrer);
        transferManager.transferItemsERC1155(address(mockERC1155), _sender, _recipient, itemIds, amounts);

        assertEq(mockERC1155.balanceOf(_recipient, tokenId1), amount1);
        assertEq(mockERC1155.balanceOf(_recipient, tokenId2), amount2);
    }

    function testTransferBatchItemsAcrossCollectionERC721AndERC1155() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        uint256 tokenIdERC721 = 55;
        uint256 tokenId1ERC1155 = 1;
        uint256 amount1ERC1155 = 2;
        uint256 tokenId2ERC1155 = 2;
        uint256 amount2ERC1155 = 5;

        address[] memory collections = new address[](2);
        uint256[] memory assetTypes = new uint256[](2);
        uint256[][] memory amounts = new uint256[][](2);
        uint256[][] memory itemIds = new uint256[][](2);

        {
            mockERC721.mint(_sender, tokenIdERC721);
            mockERC1155.mint(_sender, tokenId1ERC1155, amount1ERC1155);
            mockERC1155.mint(_sender, tokenId2ERC1155, amount2ERC1155);

            collections[0] = address(mockERC1155);
            collections[1] = address(mockERC721);

            assetTypes[0] = 1; // ERC1155
            assetTypes[1] = 0; // ERC721

            uint256[] memory tokenIdsERC1155 = new uint256[](2);
            tokenIdsERC1155[0] = tokenId1ERC1155;
            tokenIdsERC1155[1] = tokenId2ERC1155;

            uint256[] memory amountsERC1155 = new uint256[](2);
            amountsERC1155[0] = amount1ERC1155;
            amountsERC1155[1] = amount2ERC1155;

            uint256[] memory tokenIdsERC721 = new uint256[](1);
            tokenIdsERC721[0] = tokenIdERC721;

            uint256[] memory amountsERC721 = new uint256[](1);
            amountsERC721[0] = 1;

            amounts[0] = amountsERC1155;
            amounts[1] = amountsERC721;
            itemIds[0] = tokenIdsERC1155;
            itemIds[1] = tokenIdsERC721;
        }

        vm.prank(_transferrer);
        transferManager.transferBatchItemsAcrossCollections(
            collections,
            assetTypes,
            _sender,
            _recipient,
            itemIds,
            amounts
        );

        assertEq(mockERC721.ownerOf(tokenIdERC721), _recipient);
        assertEq(mockERC1155.balanceOf(_recipient, tokenId1ERC1155), amount1ERC1155);
        assertEq(mockERC1155.balanceOf(_recipient, tokenId2ERC1155), amount2ERC1155);
    }

    function testTransferBatchItemsAcrossCollectionERC721AndERC1155ByOwner() public asPrankedUser(_sender) {
        mockERC721.setApprovalForAll(address(transferManager), true);
        mockERC1155.setApprovalForAll(address(transferManager), true);

        uint256 tokenIdERC721 = 55;
        uint256 tokenId1ERC1155 = 1;
        uint256 amount1ERC1155 = 2;
        uint256 tokenId2ERC1155 = 2;
        uint256 amount2ERC1155 = 5;

        address[] memory collections = new address[](2);
        uint256[] memory assetTypes = new uint256[](2);
        uint256[][] memory amounts = new uint256[][](2);
        uint256[][] memory itemIds = new uint256[][](2);

        {
            mockERC721.mint(_sender, tokenIdERC721);
            mockERC1155.mint(_sender, tokenId1ERC1155, amount1ERC1155);
            mockERC1155.mint(_sender, tokenId2ERC1155, amount2ERC1155);

            collections[0] = address(mockERC1155);
            collections[1] = address(mockERC721);

            assetTypes[0] = 1; // ERC1155
            assetTypes[1] = 0; // ERC721

            uint256[] memory tokenIdsERC1155 = new uint256[](2);
            tokenIdsERC1155[0] = tokenId1ERC1155;
            tokenIdsERC1155[1] = tokenId2ERC1155;

            uint256[] memory amountsERC1155 = new uint256[](2);
            amountsERC1155[0] = amount1ERC1155;
            amountsERC1155[1] = amount2ERC1155;

            uint256[] memory tokenIdsERC721 = new uint256[](1);
            tokenIdsERC721[0] = tokenIdERC721;

            uint256[] memory amountsERC721 = new uint256[](1);
            amountsERC721[0] = 1;

            amounts[0] = amountsERC1155;
            amounts[1] = amountsERC721;
            itemIds[0] = tokenIdsERC1155;
            itemIds[1] = tokenIdsERC721;
        }

        transferManager.transferBatchItemsAcrossCollections(
            collections,
            assetTypes,
            _sender,
            _recipient,
            itemIds,
            amounts
        );

        assertEq(mockERC721.ownerOf(tokenIdERC721), _recipient);
        assertEq(mockERC1155.balanceOf(_recipient, tokenId1ERC1155), amount1ERC1155);
        assertEq(mockERC1155.balanceOf(_recipient, tokenId2ERC1155), amount2ERC1155);
    }

    /**
     * 2. Revertion patterns
     */

    function testTransferBatchItemsAcrossCollectionZeroCollectionsLength() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        uint256 tokenIdERC721 = 55;
        uint256 tokenId1ERC1155 = 1;
        uint256 amount1ERC1155 = 2;
        uint256 tokenId2ERC1155 = 2;
        uint256 amount2ERC1155 = 5;

        address[] memory collections = new address[](0);
        uint256[] memory assetTypes = new uint256[](2);
        uint256[][] memory amounts = new uint256[][](2);
        uint256[][] memory itemIds = new uint256[][](2);

        {
            assetTypes[0] = 1; // ERC1155
            assetTypes[1] = 0; // ERC721

            uint256[] memory tokenIdsERC1155 = new uint256[](2);
            tokenIdsERC1155[0] = tokenId1ERC1155;
            tokenIdsERC1155[1] = tokenId2ERC1155;

            uint256[] memory amountsERC1155 = new uint256[](2);
            amountsERC1155[0] = amount1ERC1155;
            amountsERC1155[1] = amount2ERC1155;

            uint256[] memory tokenIdsERC721 = new uint256[](1);
            tokenIdsERC721[0] = tokenIdERC721;

            uint256[] memory amountsERC721 = new uint256[](1);
            amountsERC721[0] = 1;

            amounts[0] = amountsERC1155;
            amounts[1] = amountsERC721;
            itemIds[0] = tokenIdsERC1155;
            itemIds[1] = tokenIdsERC721;
        }

        vm.expectRevert(WrongLengths.selector);
        vm.prank(_transferrer);
        transferManager.transferBatchItemsAcrossCollections(
            collections,
            assetTypes,
            _sender,
            _recipient,
            itemIds,
            amounts
        );
    }

    function testTransferBatchItemsAcrossCollectionWrongAssetTypesLength() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        uint256 tokenIdERC721 = 55;
        uint256 tokenId1ERC1155 = 1;
        uint256 amount1ERC1155 = 2;
        uint256 tokenId2ERC1155 = 2;
        uint256 amount2ERC1155 = 5;

        address[] memory collections = new address[](2);
        uint256[] memory assetTypes = new uint256[](1);
        uint256[][] memory amounts = new uint256[][](2);
        uint256[][] memory itemIds = new uint256[][](2);

        {
            collections[0] = address(mockERC1155);
            collections[1] = address(mockERC721);

            assetTypes[0] = 1; // ERC1155

            uint256[] memory tokenIdsERC1155 = new uint256[](2);
            tokenIdsERC1155[0] = tokenId1ERC1155;
            tokenIdsERC1155[1] = tokenId2ERC1155;

            uint256[] memory tokenIdsERC721 = new uint256[](1);
            tokenIdsERC721[0] = tokenIdERC721;

            uint256[] memory amountsERC1155 = new uint256[](2);
            amountsERC1155[0] = amount1ERC1155;
            amountsERC1155[1] = amount2ERC1155;

            uint256[] memory amountsERC721 = new uint256[](1);
            amountsERC721[0] = 1;

            amounts[0] = amountsERC1155;
            amounts[1] = amountsERC721;
            itemIds[0] = tokenIdsERC1155;
            itemIds[1] = tokenIdsERC721;
        }

        vm.expectRevert(WrongLengths.selector);
        vm.prank(_transferrer);
        transferManager.transferBatchItemsAcrossCollections(
            collections,
            assetTypes,
            _sender,
            _recipient,
            itemIds,
            amounts
        );
    }

    function testTransferBatchItemsAcrossCollectionWrongItemIdsLength() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        uint256 tokenId1ERC1155 = 1;
        uint256 amount1ERC1155 = 2;
        uint256 tokenId2ERC1155 = 2;
        uint256 amount2ERC1155 = 5;

        address[] memory collections = new address[](2);
        uint256[] memory assetTypes = new uint256[](2);
        uint256[][] memory amounts = new uint256[][](2);
        uint256[][] memory itemIds = new uint256[][](1);

        {
            collections[0] = address(mockERC1155);
            collections[1] = address(mockERC721);

            assetTypes[0] = 1; // ERC1155
            assetTypes[1] = 0; // ERC721

            uint256[] memory tokenIdsERC1155 = new uint256[](2);
            tokenIdsERC1155[0] = tokenId1ERC1155;
            tokenIdsERC1155[1] = tokenId2ERC1155;

            uint256[] memory amountsERC1155 = new uint256[](2);
            amountsERC1155[0] = amount1ERC1155;
            amountsERC1155[1] = amount2ERC1155;

            uint256[] memory amountsERC721 = new uint256[](1);
            amountsERC721[0] = 1;

            amounts[0] = amountsERC1155;
            amounts[1] = amountsERC721;
            itemIds[0] = tokenIdsERC1155;
        }

        vm.expectRevert(WrongLengths.selector);
        vm.prank(_transferrer);
        transferManager.transferBatchItemsAcrossCollections(
            collections,
            assetTypes,
            _sender,
            _recipient,
            itemIds,
            amounts
        );
    }

    function testTransferBatchItemsAcrossCollectionWrongAmountsLength() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        uint256 tokenIdERC721 = 55;
        uint256 tokenId1ERC1155 = 1;
        uint256 amount1ERC1155 = 2;
        uint256 tokenId2ERC1155 = 2;
        uint256 amount2ERC1155 = 5;

        address[] memory collections = new address[](2);
        uint256[] memory assetTypes = new uint256[](2);
        uint256[][] memory amounts = new uint256[][](1);
        uint256[][] memory itemIds = new uint256[][](2);

        {
            collections[0] = address(mockERC1155);
            collections[1] = address(mockERC721);

            assetTypes[0] = 1; // ERC1155
            assetTypes[1] = 0; // ERC721

            uint256[] memory tokenIdsERC1155 = new uint256[](2);
            tokenIdsERC1155[0] = tokenId1ERC1155;
            tokenIdsERC1155[1] = tokenId2ERC1155;

            uint256[] memory amountsERC1155 = new uint256[](2);
            amountsERC1155[0] = amount1ERC1155;
            amountsERC1155[1] = amount2ERC1155;

            uint256[] memory tokenIdsERC721 = new uint256[](1);
            tokenIdsERC721[0] = tokenIdERC721;

            amounts[0] = amountsERC1155;
            itemIds[0] = tokenIdsERC1155;
            itemIds[1] = tokenIdsERC721;
        }

        vm.expectRevert(WrongLengths.selector);
        vm.prank(_transferrer);
        transferManager.transferBatchItemsAcrossCollections(
            collections,
            assetTypes,
            _sender,
            _recipient,
            itemIds,
            amounts
        );
    }

    function testCannotBatchTransferIfAssetTypeIsNotZeroOrOne() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        address[] memory collections = new address[](1);
        uint256[] memory assetTypes = new uint256[](1);
        uint256[][] memory amounts = new uint256[][](1);
        uint256[][] memory itemIds = new uint256[][](1);

        collections[0] = address(mockERC1155);
        assetTypes[0] = 2; // WRONG ASSET TYPE

        uint256[] memory subItemIds = new uint256[](1);
        subItemIds[0] = 0;

        uint256[] memory subAmounts = new uint256[](1);
        subAmounts[0] = 1;

        amounts[0] = subAmounts;
        itemIds[0] = subItemIds;

        vm.prank(_sender);
        vm.expectRevert(abi.encodeWithSelector(WrongAssetType.selector, 2));

        transferManager.transferBatchItemsAcrossCollections(
            collections,
            assetTypes,
            _sender,
            _recipient,
            itemIds,
            amounts
        );
    }

    function testTransferBatchItemsAcrossCollectionPerCollectionItemIdsLengthZero() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        uint256 tokenIdERC721 = 55;
        uint256 tokenId1ERC1155 = 1;
        uint256 amount1ERC1155 = 2;
        uint256 tokenId2ERC1155 = 2;
        uint256 amount2ERC1155 = 5;

        address[] memory collections = new address[](2);
        uint256[] memory assetTypes = new uint256[](2);
        uint256[][] memory amounts = new uint256[][](2);
        uint256[][] memory itemIds = new uint256[][](2);

        {
            mockERC721.mint(_sender, tokenIdERC721);
            mockERC1155.mint(_sender, tokenId1ERC1155, amount1ERC1155);
            mockERC1155.mint(_sender, tokenId2ERC1155, amount2ERC1155);

            collections[0] = address(mockERC1155);
            collections[1] = address(mockERC721);

            assetTypes[0] = 1; // ERC1155
            assetTypes[1] = 0; // ERC721

            uint256[] memory tokenIdsERC1155 = new uint256[](0);

            uint256[] memory amountsERC1155 = new uint256[](0);

            uint256[] memory tokenIdsERC721 = new uint256[](1);
            tokenIdsERC721[0] = tokenIdERC721;

            uint256[] memory amountsERC721 = new uint256[](1);
            amountsERC721[0] = 1;

            amounts[0] = amountsERC1155;
            amounts[1] = amountsERC721;
            itemIds[0] = tokenIdsERC1155;
            itemIds[1] = tokenIdsERC721;
        }

        vm.prank(_transferrer);
        vm.expectRevert(WrongLengths.selector);
        transferManager.transferBatchItemsAcrossCollections(
            collections,
            assetTypes,
            _sender,
            _recipient,
            itemIds,
            amounts
        );
    }

    function testTransferBatchItemsAcrossCollectionPerCollectionAmountsAndItemIdsLengthMismatch() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        uint256 tokenIdERC721 = 55;
        uint256 tokenId1ERC1155 = 1;
        uint256 amount1ERC1155 = 2;
        uint256 tokenId2ERC1155 = 2;
        uint256 amount2ERC1155 = 5;

        address[] memory collections = new address[](2);
        uint256[] memory assetTypes = new uint256[](2);
        uint256[][] memory amounts = new uint256[][](2);
        uint256[][] memory itemIds = new uint256[][](2);

        {
            mockERC721.mint(_sender, tokenIdERC721);
            mockERC1155.mint(_sender, tokenId1ERC1155, amount1ERC1155);
            mockERC1155.mint(_sender, tokenId2ERC1155, amount2ERC1155);

            collections[0] = address(mockERC1155);
            collections[1] = address(mockERC721);

            assetTypes[0] = 1; // ERC1155
            assetTypes[1] = 0; // ERC721

            uint256[] memory tokenIdsERC1155 = new uint256[](2);
            tokenIdsERC1155[0] = tokenId1ERC1155;
            tokenIdsERC1155[1] = tokenId2ERC1155;

            uint256[] memory amountsERC1155 = new uint256[](1);
            amountsERC1155[0] = amount1ERC1155;

            uint256[] memory tokenIdsERC721 = new uint256[](1);
            tokenIdsERC721[0] = tokenIdERC721;

            uint256[] memory amountsERC721 = new uint256[](1);
            amountsERC721[0] = 1;

            amounts[0] = amountsERC1155;
            amounts[1] = amountsERC721;
            itemIds[0] = tokenIdsERC1155;
            itemIds[1] = tokenIdsERC721;
        }

        vm.prank(_transferrer);
        vm.expectRevert(WrongLengths.selector);
        transferManager.transferBatchItemsAcrossCollections(
            collections,
            assetTypes,
            _sender,
            _recipient,
            itemIds,
            amounts
        );
    }

    function testCannotTransferERC721IfOperatorApprovalsRevokedByUserOrOperatorRemovedByOwner() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        // 1. User revokes the operator
        vm.prank(_sender);
        vm.expectEmit(false, false, false, true);
        emit ApprovalsRemoved(_sender, operators);
        transferManager.revokeApprovals(operators);

        uint256 itemId = 500;
        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        vm.prank(_transferrer);
        vm.expectRevert(ITransferManager.TransferCallerInvalid.selector);
        transferManager.transferItemsERC721(address(mockERC721), _sender, _recipient, itemIds, amounts);

        // 2. Sender grants again approvals but owner removes the operators
        _grantApprovals(_sender);
        vm.prank(_owner);
        vm.expectEmit(false, false, false, true);
        emit OperatorRemoved(_transferrer);
        transferManager.removeOperator(_transferrer);

        vm.prank(_transferrer);
        vm.expectRevert(ITransferManager.TransferCallerInvalid.selector);
        transferManager.transferItemsERC721(address(mockERC721), _sender, _recipient, itemIds, amounts);
    }

    function testCannotTransferERC1155IfOperatorApprovalsRevokedByUserOrOperatorRemovedByOwner() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        // 1. User revokes the operator
        vm.prank(_sender);
        vm.expectEmit(false, false, false, true);
        emit ApprovalsRemoved(_sender, operators);
        transferManager.revokeApprovals(operators);

        uint256 itemId = 500;
        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 5;

        vm.prank(_transferrer);
        vm.expectRevert(ITransferManager.TransferCallerInvalid.selector);
        transferManager.transferItemsERC1155(address(mockERC1155), _sender, _recipient, itemIds, amounts);

        // 2. Sender grants again approvals but owner removes the operators
        _grantApprovals(_sender);
        vm.prank(_owner);
        vm.expectEmit(false, false, false, true);
        emit OperatorRemoved(_transferrer);
        transferManager.removeOperator(_transferrer);

        vm.prank(_transferrer);
        vm.expectRevert(ITransferManager.TransferCallerInvalid.selector);
        transferManager.transferItemsERC1155(address(mockERC1155), _sender, _recipient, itemIds, amounts);
    }

    function testCannotBatchTransferIfOperatorApprovalsRevoked() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        // 1. User revokes the operator
        vm.prank(_sender);
        vm.expectEmit(false, false, false, true);
        emit ApprovalsRemoved(_sender, operators);
        transferManager.revokeApprovals(operators);

        address[] memory collections = new address[](2);
        uint256[] memory assetTypes = new uint256[](2);
        uint256[][] memory amounts = new uint256[][](2);
        uint256[][] memory itemIds = new uint256[][](2);

        collections[0] = address(mockERC721);
        collections[1] = address(mockERC1155);
        assetTypes[0] = 0;
        assetTypes[1] = 1;

        uint256 itemId0 = 500;
        uint256 itemId1 = 500;

        itemIds[0] = new uint256[](1);
        itemIds[1] = new uint256[](1);
        itemIds[0][0] = itemId0;
        itemIds[1][0] = itemId1;

        amounts[0] = new uint256[](1);
        amounts[1] = new uint256[](1);
        amounts[0][0] = 1;
        amounts[1][0] = 2;

        vm.prank(_transferrer);
        vm.expectRevert(ITransferManager.TransferCallerInvalid.selector);
        transferManager.transferBatchItemsAcrossCollections(
            collections,
            assetTypes,
            _sender,
            _recipient,
            itemIds,
            amounts
        );

        // 2. Sender grants again approvals but owner removes the operators
        _grantApprovals(_sender);
        vm.prank(_owner);
        vm.expectEmit(false, false, false, true);
        emit OperatorRemoved(_transferrer);
        transferManager.removeOperator(_transferrer);

        vm.prank(_transferrer);
        vm.expectRevert(ITransferManager.TransferCallerInvalid.selector);
        transferManager.transferBatchItemsAcrossCollections(
            collections,
            assetTypes,
            _sender,
            _recipient,
            itemIds,
            amounts
        );
    }

    function testCannotTransferERC721OrERC1155IfArrayLengthIs0() public {
        uint256[] memory emptyArrayUint256 = new uint256[](0);

        // 1. ERC721
        vm.expectRevert(WrongLengths.selector);
        transferManager.transferItemsERC721(
            address(mockERC721),
            _sender,
            _recipient,
            emptyArrayUint256,
            emptyArrayUint256
        );

        // 2. ERC1155 length is 0
        vm.expectRevert(WrongLengths.selector);
        transferManager.transferItemsERC1155(
            address(mockERC1155),
            _sender,
            _recipient,
            emptyArrayUint256,
            emptyArrayUint256
        );
    }

    function testCannotTransferERC1155IfArrayLengthDiffers() public {
        uint256[] memory itemIds = new uint256[](2);
        uint256[] memory amounts = new uint256[](3);

        vm.expectRevert(WrongLengths.selector);
        transferManager.transferItemsERC1155(address(mockERC1155), _sender, _recipient, itemIds, amounts);
    }

    function testUserCannotGrantOrRevokeApprovalsIfArrayLengthIs0() public {
        address[] memory emptyArrayAddresses = new address[](0);

        // 1. Grant approvals
        vm.expectRevert(WrongLengths.selector);
        transferManager.grantApprovals(emptyArrayAddresses);

        // 2. Revoke approvals
        vm.expectRevert(WrongLengths.selector);
        transferManager.revokeApprovals(emptyArrayAddresses);
    }

    function testUserCannotGrantApprovalIfOperatorNotWhitelisted() public asPrankedUser(_owner) {
        address randomOperator = address(420);
        transferManager.whitelistOperator(randomOperator);
        vm.expectRevert(ITransferManager.AlreadyWhitelisted.selector);
        transferManager.whitelistOperator(randomOperator);
    }

    function testWhitelistOperatorNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        transferManager.whitelistOperator(address(0));
    }

    function testOwnerCannotWhitelistOperatorIfAlreadyWhitelisted() public asPrankedUser(_owner) {
        address randomOperator = address(420);
        transferManager.whitelistOperator(randomOperator);
        vm.expectRevert(ITransferManager.AlreadyWhitelisted.selector);
        transferManager.whitelistOperator(randomOperator);
    }

    function testOwnerCannotRemoveOperatorIfNotWhitelisted() public asPrankedUser(_owner) {
        address notOperator = address(420);
        vm.expectRevert(ITransferManager.NotWhitelisted.selector);
        transferManager.removeOperator(notOperator);
    }

    function testUserCannotGrantApprovalsIfNotWhitelisted() public {
        address[] memory approvedOperators = new address[](1);
        approvedOperators[0] = _transferrer;

        vm.expectRevert(ITransferManager.NotWhitelisted.selector);
        vm.prank(_sender);
        transferManager.grantApprovals(approvedOperators);
    }

    function testUserCannotGrantApprovalsIfAlreadyApproved() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        address[] memory approvedOperators = new address[](1);
        approvedOperators[0] = _transferrer;

        vm.expectRevert(ITransferManager.AlreadyApproved.selector);
        vm.prank(_sender);
        transferManager.grantApprovals(approvedOperators);
    }

    function testUserCannotRevokeApprovalsIfNotApproved() public {
        address[] memory approvedOperators = new address[](1);
        approvedOperators[0] = _transferrer;

        vm.expectRevert(ITransferManager.NotApproved.selector);
        vm.prank(_sender);
        transferManager.revokeApprovals(approvedOperators);
    }

    function testRemoveOperatorNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        transferManager.removeOperator(address(0));
    }
}
