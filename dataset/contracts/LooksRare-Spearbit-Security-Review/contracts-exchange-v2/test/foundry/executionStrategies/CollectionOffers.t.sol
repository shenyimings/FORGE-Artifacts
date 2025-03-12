// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Murky (third-party) library is used to compute Merkle trees in Solidity
import {Merkle} from "../../../lib/murky/src/Merkle.sol";

// Libraries
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";

// Shared errors
import {OrderInvalid, WrongFunctionSelector, WrongMerkleProof} from "../../../contracts/interfaces/SharedErrors.sol";
import {MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE} from "../../../contracts/helpers/ValidationCodeConstants.sol";

// Strategies
import {StrategyCollectionOffer} from "../../../contracts/executionStrategies/StrategyCollectionOffer.sol";

// Base test
import {ProtocolBase} from "../ProtocolBase.t.sol";

contract CollectionOrdersTest is ProtocolBase {
    StrategyCollectionOffer public strategyCollectionOffer;
    bytes4 public selectorNoProof = strategyCollectionOffer.executeCollectionStrategyWithTakerAsk.selector;
    bytes4 public selectorWithProof = strategyCollectionOffer.executeCollectionStrategyWithTakerAskWithProof.selector;

    uint256 private constant price = 1 ether; // Fixed price of sale
    bytes32 private constant mockMerkleRoot = bytes32(keccak256("Mock")); // Mock merkle root

    function setUp() public override {
        super.setUp();
        _setUpNewStrategies();
    }

    function _setUpNewStrategies() private asPrankedUser(_owner) {
        strategyCollectionOffer = new StrategyCollectionOffer();

        looksRareProtocol.addStrategy(
            _standardProtocolFeeBp,
            _minTotalFeeBp,
            _maxProtocolFeeBp,
            selectorNoProof,
            true,
            address(strategyCollectionOffer)
        );

        looksRareProtocol.addStrategy(
            _standardProtocolFeeBp,
            _minTotalFeeBp,
            _maxProtocolFeeBp,
            selectorWithProof,
            true,
            address(strategyCollectionOffer)
        );
    }

    function testNewStrategies() public {
        (
            bool strategyIsActive,
            uint16 strategyStandardProtocolFee,
            uint16 strategyMinTotalFee,
            uint16 strategyMaxProtocolFee,
            bytes4 strategySelector,
            bool strategyIsMakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(1);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, _standardProtocolFeeBp);
        assertEq(strategyMinTotalFee, _minTotalFeeBp);
        assertEq(strategyMaxProtocolFee, _maxProtocolFeeBp);
        assertEq(strategySelector, selectorNoProof);
        assertTrue(strategyIsMakerBid);
        assertEq(strategyImplementation, address(strategyCollectionOffer));

        (
            strategyIsActive,
            strategyStandardProtocolFee,
            strategyMinTotalFee,
            strategyMaxProtocolFee,
            strategySelector,
            strategyIsMakerBid,
            strategyImplementation
        ) = looksRareProtocol.strategyInfo(2);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, _standardProtocolFeeBp);
        assertEq(strategyMinTotalFee, _minTotalFeeBp);
        assertEq(strategyMaxProtocolFee, _maxProtocolFeeBp);
        assertEq(strategySelector, selectorWithProof);
        assertTrue(strategyIsMakerBid);
        assertEq(strategyImplementation, address(strategyCollectionOffer));
    }

    function testItemIdsLengthNotOne() public {
        _setUpUsers();

        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMockMakerBidAndTakerAsk(
            address(mockERC721),
            address(weth)
        );

        // Adjust strategy for collection order and sign order
        // Change array to make it bigger than expected
        uint256[] memory itemIds = new uint256[](2);
        itemIds[0] = 1;
        makerBid.strategyId = 1;
        takerAsk.itemIds = itemIds;
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Maker bid is still valid
        _assertOrderIsValid(makerBid, false);
        _isMakerBidOrderValid(makerBid, signature);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // With proof
        makerBid.strategyId = 2;
        makerBid.additionalParameters = abi.encode(mockMerkleRoot);
        signature = _signMakerBid(makerBid, makerUserPK);

        // Maker bid is still valid
        _assertOrderIsValid(makerBid, true);
        _isMakerBidOrderValid(makerBid, signature);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testAmountsMismatch() public {
        _setUpUsers();

        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMockMakerBidAndTakerAsk(
            address(mockERC1155),
            address(weth)
        );

        uint256[] memory makerBidAmounts = new uint256[](1);
        makerBidAmounts[0] = 1;
        uint256[] memory takerAskAmounts = new uint256[](1);
        takerAskAmounts[0] = 2;
        makerBid.amounts = makerBidAmounts;
        takerAsk.amounts = takerAskAmounts;

        // Adjust strategy for collection order and sign order
        makerBid.strategyId = 1;
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _assertOrderIsValid(makerBid, false);
        _isMakerBidOrderValid(makerBid, signature);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // With proof
        makerBid.strategyId = 2;
        makerBid.additionalParameters = abi.encode(mockMerkleRoot);
        signature = _signMakerBid(makerBid, makerUserPK);

        _assertOrderIsValid(makerBid, true);
        _isMakerBidOrderValid(makerBid, signature);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testAmountsLengthNotOne() public {
        _setUpUsers();

        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMockMakerBidAndTakerAsk(
            address(mockERC721),
            address(weth)
        );

        // Adjust strategy for collection order and sign order
        // Change array to make it bigger than expected
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        makerBid.strategyId = 1;
        makerBid.amounts = amounts;
        takerAsk.amounts = amounts;
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _assertOrderIsInvalid(makerBid, false);
        _doesMakerBidOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // With proof
        makerBid.strategyId = 2;
        makerBid.additionalParameters = abi.encode(mockMerkleRoot);
        signature = _signMakerBid(makerBid, makerUserPK);

        _assertOrderIsInvalid(makerBid, true);
        _doesMakerBidOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testZeroAmount() public {
        _setUpUsers();

        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMockMakerBidAndTakerAsk(
            address(mockERC721),
            address(weth)
        );

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        makerBid.amounts = amounts;
        makerBid.strategyId = 1;
        makerBid.additionalParameters = abi.encode(mockMerkleRoot);
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _assertOrderIsInvalid(makerBid, false);
        _doesMakerBidOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testBidAskAmountMismatch() public {
        _setUpUsers();

        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMockMakerBidAndTakerAsk(
            address(mockERC721),
            address(weth)
        );

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;
        takerAsk.amounts = amounts;
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Maker bid still valid
        _assertOrderIsValid(makerBid, false);
        _isMakerBidOrderValid(makerBid, signature);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testPriceMismatch() public {
        _setUpUsers();

        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMockMakerBidAndTakerAsk(
            address(mockERC721),
            address(weth)
        );

        takerAsk.minPrice = makerBid.maxPrice + 1;
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Maker bid still valid
        _assertOrderIsValid(makerBid, false);
        _isMakerBidOrderValid(makerBid, signature);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    /**
     * Any itemId for ERC721 (where royalties come from the registry) is sold through a collection taker ask using WETH.
     * We use fuzzing to generate the tokenId that is sold.
     */
    function testTakerAskCollectionOrderERC721(uint256 tokenId) public {
        _setUpUsers();

        // Prepare the order hash
        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 1,
            assetType: 0, // ERC721
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: 0 // Not used
        });

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Mint asset
        mockERC721.mint(takerUser, tokenId);

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = tokenId;

        // Prepare the taker ask
        OrderStructs.TakerAsk memory takerAsk = OrderStructs.TakerAsk(
            takerUser,
            makerBid.maxPrice,
            itemIds,
            makerBid.amounts,
            abi.encode()
        );

        _assertOrderIsValid(makerBid, false);
        _isMakerBidOrderValid(makerBid, signature);

        // Execute taker ask transaction
        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(tokenId), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Taker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9_800) / 10_000);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }

    /**
     * A collection offer with merkle tree criteria
     */
    function testTakerAskCollectionOrderWithMerkleTreeERC721() public {
        _setUpUsers();

        // Initialize Merkle Tree
        Merkle m = new Merkle();

        bytes32[] memory merkleTreeIds = new bytes32[](5);
        for (uint256 i; i < merkleTreeIds.length; i++) {
            mockERC721.mint(takerUser, i);
            merkleTreeIds[i] = keccak256(abi.encodePacked(i));
        }

        // Compute merkle root
        bytes32 merkleRoot = m.getRoot(merkleTreeIds);

        // Prepare the order hash
        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 2,
            assetType: 0, // ERC721
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: 0 // Not used
        });

        makerBid.additionalParameters = abi.encode(merkleRoot);

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        uint256 itemIdSold = 2;
        bytes32[] memory proof = m.getProof(merkleTreeIds, 2);

        assertTrue(m.verifyProof(merkleRoot, proof, merkleTreeIds[2]));

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemIdSold;

        // Prepare the taker ask
        OrderStructs.TakerAsk memory takerAsk = OrderStructs.TakerAsk(
            takerUser,
            makerBid.maxPrice,
            itemIds,
            makerBid.amounts,
            abi.encode(proof)
        );

        // Verify validity of maker bid order
        _assertOrderIsValid(makerBid, true);
        _isMakerBidOrderValid(makerBid, signature);

        // Execute taker ask transaction
        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(itemIdSold), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Taker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9_800) / 10_000);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }

    function testTakerAskCannotExecuteWithWrongProof(uint256 itemIdSold) public {
        vm.assume(itemIdSold > 5);
        _setUpUsers();

        // Initialize Merkle Tree
        Merkle m = new Merkle();

        bytes32[] memory merkleTreeIds = new bytes32[](5);
        for (uint256 i; i < merkleTreeIds.length; i++) {
            mockERC721.mint(takerUser, i);
            merkleTreeIds[i] = keccak256(abi.encodePacked(i));
        }

        // Compute merkle root
        bytes32 merkleRoot = m.getRoot(merkleTreeIds);

        // Prepare the order hash
        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 2,
            assetType: 0, // ERC721
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: 0 // Not used
        });

        makerBid.additionalParameters = abi.encode(merkleRoot);

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        bytes32[] memory proof = m.getProof(merkleTreeIds, 2);

        assertTrue(m.verifyProof(merkleRoot, proof, merkleTreeIds[2]));

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemIdSold;

        // Prepare the taker ask
        OrderStructs.TakerAsk memory takerAsk = OrderStructs.TakerAsk(
            takerUser,
            makerBid.maxPrice,
            itemIds,
            makerBid.amounts,
            abi.encode(proof)
        );

        // Verify validity of maker bid order
        _assertOrderIsValid(makerBid, true);
        _isMakerBidOrderValid(makerBid, signature);

        vm.prank(takerUser);
        vm.expectRevert(WrongMerkleProof.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testWrongAmounts() public {
        _setUpUsers();

        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 1,
            assetType: 0,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: 0
        });

        // Random itemIds
        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = 5;

        // Prepare the taker ask
        OrderStructs.TakerAsk memory takerAsk = OrderStructs.TakerAsk(
            takerUser,
            makerBid.maxPrice,
            itemIds,
            makerBid.amounts,
            abi.encode()
        );

        // 1. Amount is 0 (without merkle proof)
        makerBid.amounts[0] = 0;
        takerAsk.amounts = makerBid.amounts;
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);
        _assertOrderIsInvalid(makerBid, false);
        _doesMakerBidOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.prank(takerUser);
        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // 2. Amount is too high for ERC721 (without merkle proof)
        makerBid.amounts[0] = 2;
        signature = _signMakerBid(makerBid, makerUserPK);
        _assertOrderIsInvalid(makerBid, false);
        _doesMakerBidOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.prank(takerUser);
        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // 3. Amount is 0 (with merkle proof)
        makerBid.strategyId = 2;
        makerBid.additionalParameters = abi.encode(mockMerkleRoot);
        makerBid.amounts[0] = 0;
        takerAsk.amounts = makerBid.amounts;
        signature = _signMakerBid(makerBid, makerUserPK);
        _assertOrderIsInvalid(makerBid, true);
        _doesMakerBidOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.prank(takerUser);
        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // 4. Amount is too high for ERC721 (with merkle proof)
        makerBid.amounts[0] = 2;
        takerAsk.amounts = makerBid.amounts;
        signature = _signMakerBid(makerBid, makerUserPK);
        _assertOrderIsInvalid(makerBid, true);
        _doesMakerBidOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.prank(takerUser);
        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testMerkleRootLengthIsNot32() public {
        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 2,
            assetType: 0,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: 0
        });

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Prepare the taker ask
        OrderStructs.TakerAsk memory takerAsk = OrderStructs.TakerAsk(
            takerUser,
            makerBid.maxPrice,
            makerBid.itemIds,
            makerBid.amounts,
            abi.encode()
        );

        _assertOrderIsInvalid(makerBid, true);
        _doesMakerBidOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.prank(takerUser);
        vm.expectRevert(); // It should revert without data (since the root cannot be extracted since the additionalParameters length is 0)
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testWrongSelector() public {
        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 3,
            assetType: 0,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: 0
        });

        (bool orderIsValid, bytes4 errorSelector) = strategyCollectionOffer.isMakerBidValid(makerBid, bytes4(0));
        assertFalse(orderIsValid);
        assertEq(errorSelector, WrongFunctionSelector.selector);
    }

    function _assertOrderIsValid(OrderStructs.MakerBid memory makerBid, bool withProof) private {
        (bool orderIsValid, bytes4 errorSelector) = strategyCollectionOffer.isMakerBidValid(
            makerBid,
            withProof
                ? StrategyCollectionOffer.executeCollectionStrategyWithTakerAskWithProof.selector
                : StrategyCollectionOffer.executeCollectionStrategyWithTakerAsk.selector
        );
        assertTrue(orderIsValid);
        assertEq(errorSelector, _EMPTY_BYTES4);
    }

    function _assertOrderIsInvalid(OrderStructs.MakerBid memory makerBid, bool withProof) private {
        (bool orderIsValid, bytes4 errorSelector) = strategyCollectionOffer.isMakerBidValid(
            makerBid,
            withProof
                ? StrategyCollectionOffer.executeCollectionStrategyWithTakerAskWithProof.selector
                : StrategyCollectionOffer.executeCollectionStrategyWithTakerAsk.selector
        );

        assertFalse(orderIsValid);
        assertEq(errorSelector, OrderInvalid.selector);
    }
}
