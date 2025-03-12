// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Libraries
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Interfaces
import {ITransferSelectorNFT} from "../../contracts/interfaces/ITransferSelectorNFT.sol";

// Errors
import {ASSET_TYPE_NOT_SUPPORTED} from "../../contracts/helpers/ValidationCodeConstants.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract TransferSelectorNFTTest is ProtocolBase, ITransferSelectorNFT {
    address public newTransferManager = address(69_420);

    // Wrong selector
    bytes4 public newSelector = 0x69696969;

    function testInitialStates() public {
        (address transferManager0, bytes4 selector0) = looksRareProtocol.managerSelectorOfAssetType(0);
        assertEq(transferManager0, address(transferManager));
        assertEq(uint32(selector0), uint32(0xa7bc96d3));

        (address transferManager1, bytes4 selector1) = looksRareProtocol.managerSelectorOfAssetType(1);
        assertEq(transferManager1, address(transferManager));
        assertEq(uint32(selector1), uint32(0xa0a406c6));
    }

    function testCannotTransferIfNoManagerSelectorForAssetType() public {
        _setUpUsers();
        uint256 price = 0.1 ether;

        //  Prepare the orders and signature
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid, bytes memory signature) = _createSingleItemMakerAskAndTakerBidOrderAndSignature({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: 0, // Standard sale for fixed price
            assetType: 2, // It does not exist
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(0), // ETH
            signer: makerUser,
            minPrice: price,
            itemId: 10
        });

        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, ASSET_TYPE_NOT_SUPPORTED);

        vm.prank(takerUser);
        vm.expectRevert(abi.encodeWithSelector(ITransferSelectorNFT.NoTransferManagerForAssetType.selector, 2));
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );
    }

    function testAddTransferManagerForAssetType() public asPrankedUser(_owner) {
        vm.expectEmit(true, false, false, true);
        emit NewAssetType(2, newTransferManager, newSelector);
        looksRareProtocol.addTransferManagerForAssetType(2, newTransferManager, newSelector);

        (address currentTransferManager, bytes4 selector) = looksRareProtocol.managerSelectorOfAssetType(2);
        assertEq(currentTransferManager, newTransferManager);
        assertEq(uint32(selector), uint32(newSelector));
    }

    function testAddTransferManagerForAssetTypeNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.addTransferManagerForAssetType(2, newTransferManager, newSelector);
    }

    function testAddTransferManagerManagerSelectorAlreadySetForAssetType() public asPrankedUser(_owner) {
        vm.expectRevert(ManagerSelectorAlreadySetForAssetType.selector);
        looksRareProtocol.addTransferManagerForAssetType(0, newTransferManager, newSelector);
    }

    function testAddTransferManagerManagerSelectorEmpty() public asPrankedUser(_owner) {
        // 1. Empty transfer manager address
        vm.expectRevert(ManagerSelectorEmpty.selector);
        looksRareProtocol.addTransferManagerForAssetType(2, address(0), newSelector);

        // 2. Address transfer manager is protocol address
        vm.expectRevert(ManagerSelectorEmpty.selector);
        looksRareProtocol.addTransferManagerForAssetType(2, address(looksRareProtocol), newSelector);

        // 3. Empty selector
        vm.expectRevert(ManagerSelectorEmpty.selector);
        looksRareProtocol.addTransferManagerForAssetType(2, address(1), _EMPTY_BYTES4);
    }
}
