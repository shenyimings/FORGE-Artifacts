// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../../../contracts/interfaces/CloberOrderNFT.sol";
import "../../../contracts/OrderNFT.sol";
import "../../../contracts/mocks/MockWETH.sol";
import "./utils/MockERC721Receiver.sol";

contract OrderNFTUnitTest is Test {
    using OrderKeyUtils for OrderKey;
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    bool constant MOCK_IS_BID = true;
    uint16 constant MOCK_PRICE_INDEX = 21;
    uint232 constant MOCK_ORDER_INDEX = 2419868969812413223123412;

    OrderNFT orderToken;

    mapping(uint256 => address) mockOrderOwners;

    // mocking OrderBook
    function getOrder(OrderKey calldata orderKey) external view returns (CloberOrderBook.Order memory) {
        return CloberOrderBook.Order(0, 0, mockOrderOwners[orderToken.encodeId(orderKey)]);
    }

    function changeOrderOwner(OrderKey calldata orderKey, address newOwner) external {
        mockOrderOwners[orderToken.encodeId(orderKey)] = newOwner;
    }

    function cancel(address, OrderKey[] calldata) external pure {}

    // mocking factory
    function getMarketHost(address) external view returns (address) {
        return address(this);
    }

    function setUp() public {
        orderToken = new OrderNFT(address(this), address(this));
        orderToken.init("", "", address(this));
    }

    function testOwner() public {
        vm.expectCall(address(this), abi.encodeCall(CloberMarketFactory.getMarketHost, (address(this))));
        address _owner = orderToken.owner();
        assertEq(_owner, address(this));
    }

    function testChangeBaseURI() public {
        orderToken.changeBaseURI("URI");
        assertEq(orderToken.baseURI(), "URI", "URI");
    }

    function testChangeBaseURIAccess() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        vm.prank(address(1));
        orderToken.changeBaseURI("URI");
    }

    function testChangeContractURI() public {
        orderToken.changeContractURI("URI");
        assertEq(orderToken.contractURI(), "URI", "URI");
    }

    function testChangeContractURIAccess() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        vm.prank(address(1));
        orderToken.changeContractURI("URI");
    }

    function testSupportsInterface() public {
        assertTrue(orderToken.supportsInterface(type(IERC721).interfaceId));
        assertTrue(orderToken.supportsInterface(type(IERC721Metadata).interfaceId));
        assertTrue(orderToken.supportsInterface(type(IERC165).interfaceId));
    }

    function testBalanceOf() public {
        address user = address(0x123);
        assertEq(orderToken.balanceOf(user), 0, "BALANCE_0");
        _mint(user, MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        assertEq(orderToken.balanceOf(user), 1, "BALANCE_1");
        _mint(user, !MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        assertEq(orderToken.balanceOf(user), 2, "BALANCE_2");
        orderToken.onBurn(OrderKey(MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX).encode());
        orderToken.onBurn(OrderKey(!MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX).encode());
        assertEq(orderToken.balanceOf(user), 0, "BALANCE_0");
    }

    function testBalanceOfZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.EMPTY_INPUT));
        orderToken.balanceOf(address(0));
    }

    function testOwnerOf() public {
        address user = address(0x123);
        OrderKey memory orderKey = _mint(user, MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        uint256 tokenId = orderToken.encodeId(orderKey);

        vm.expectCall(address(this), abi.encodeCall(CloberOrderBook.getOrder, (orderKey)));
        address owner = orderToken.ownerOf(tokenId);

        assertEq(owner, user, "OWNER");
    }

    function testOwnerOfWhenOwnerIsZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        orderToken.ownerOf(123);
    }

    function testTokenURI() public {
        orderToken.changeBaseURI("URI/");
        address user = address(0x123);
        OrderKey memory orderKey = _mint(user, MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        uint256 tokenId = orderToken.encodeId(orderKey);
        assertEq(orderToken.tokenURI(tokenId), string(abi.encodePacked("URI/", vm.toString(tokenId))));
    }

    function testTokenURIWhenBaseURIIsEmpty() public {
        address user = address(0x123);
        OrderKey memory orderKey = _mint(user, MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        uint256 tokenId = orderToken.encodeId(orderKey);
        assertEq(orderToken.tokenURI(tokenId), "");
    }

    function testTokenURIWithInvalidTokenId() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_ID));
        orderToken.tokenURI(123);
    }

    function testApprove() public {
        address user = address(0x123);
        address spender = address(0x456);
        OrderKey memory orderKey = _mint(user, MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        uint256 tokenId = orderToken.encodeId(orderKey);

        vm.expectEmit(true, true, true, true);
        emit Approval(user, spender, tokenId);
        vm.prank(user);
        orderToken.approve(spender, tokenId);

        assertEq(orderToken.getApproved(tokenId), spender, "APPROVE");
    }

    function testApproveByOperator() public {
        address user = address(0x123);
        address spender = address(0x456);
        address operator = address(0x789);
        OrderKey memory orderKey = _mint(user, MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        uint256 tokenId = orderToken.encodeId(orderKey);
        vm.prank(user);
        orderToken.setApprovalForAll(operator, true);

        vm.expectEmit(true, true, true, true);
        emit Approval(user, spender, tokenId);
        vm.prank(operator);
        orderToken.approve(spender, tokenId);

        assertEq(orderToken.getApproved(tokenId), spender, "APPROVE");
    }

    function testApproveToOwner() public {
        address user = address(0x123);
        OrderKey memory orderKey = _mint(user, MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        uint256 tokenId = orderToken.encodeId(orderKey);

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        vm.prank(user);
        orderToken.approve(user, tokenId);
    }

    function testApproveByUnauthorized() public {
        address user = address(0x123);
        address unauthorized = address(0x456);
        OrderKey memory orderKey = _mint(user, MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        uint256 tokenId = orderToken.encodeId(orderKey);

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        vm.prank(unauthorized);
        orderToken.approve(unauthorized, tokenId);
    }

    function testGetApprovedOfInvalidTokenId() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_ID));
        orderToken.getApproved(123);
    }

    function testSetApproveForAll() public {
        address user = address(0x123);
        address operator = address(0x456);

        vm.expectEmit(true, true, true, true);
        emit ApprovalForAll(user, operator, true);
        vm.prank(user);
        orderToken.setApprovalForAll(operator, true);

        assertTrue(orderToken.isApprovedForAll(user, operator), "APPROVE_FOR_ALL_TRUE");

        vm.expectEmit(true, true, true, true);
        emit ApprovalForAll(user, operator, false);
        vm.prank(user);
        orderToken.setApprovalForAll(operator, false);

        assertTrue(!orderToken.isApprovedForAll(user, operator), "APPROVE_FOR_ALL_FALSE");
    }

    function testSetApproveForAllToCaller() public {
        address user = address(0x123);

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        vm.prank(user);
        orderToken.setApprovalForAll(user, true);
    }

    function testTransferFrom() public {
        address from = address(0x123);
        address to = address(0x456);
        OrderKey memory orderKey = _mint(from, MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        uint256 tokenId = orderToken.encodeId(orderKey);
        vm.prank(from);
        orderToken.approve(address(0x435), tokenId);

        uint256 snapshotId = vm.snapshot();
        // check Approval Event and external call to market
        vm.expectEmit(true, true, true, true);
        emit Approval(from, address(0), tokenId);
        vm.expectCall(address(this), abi.encodeCall(CloberOrderBook.changeOrderOwner, (orderKey, to)));
        vm.prank(from);
        orderToken.transferFrom(from, to, tokenId);
        // check Transfer Event
        vm.revertTo(snapshotId);
        vm.expectEmit(true, true, true, true);
        emit Transfer(from, to, tokenId);
        vm.prank(from);
        orderToken.transferFrom(from, to, tokenId);

        assertEq(orderToken.ownerOf(tokenId), to, "OWNER");
        assertEq(orderToken.balanceOf(from), 0, "FROM_BALANCE");
        assertEq(orderToken.balanceOf(to), 1, "TO_BALANCE");
        assertEq(orderToken.getApproved(tokenId), address(0), "APPROVE");
    }

    function testTransferFromOther() public {
        address from = address(0x123);
        address to = address(0x456);
        address spender = address(0x789);
        OrderKey memory orderKey = _mint(from, MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        uint256 tokenId = orderToken.encodeId(orderKey);
        vm.prank(from);
        orderToken.approve(spender, tokenId);

        uint256 snapshotId = vm.snapshot();
        // check Approval Event and external call to market
        vm.expectEmit(true, true, true, true);
        emit Approval(from, address(0), tokenId);
        vm.expectCall(address(this), abi.encodeCall(CloberOrderBook.changeOrderOwner, (orderKey, to)));
        vm.prank(spender);
        orderToken.transferFrom(from, to, tokenId);
        // check Transfer Event
        vm.revertTo(snapshotId);
        vm.expectEmit(true, true, true, true);
        emit Transfer(from, to, tokenId);
        vm.prank(spender);
        orderToken.transferFrom(from, to, tokenId);

        assertEq(orderToken.ownerOf(tokenId), to, "OWNER");
        assertEq(orderToken.balanceOf(from), 0, "FROM_BALANCE");
        assertEq(orderToken.balanceOf(to), 1, "TO_BALANCE");
        assertEq(orderToken.getApproved(tokenId), address(0), "APPROVE");
    }

    function testTransferFromWithDifferentFromAddress() public {
        address victim = address(0x123);
        address attacker = address(0x234);
        address attacker2 = address(0x345);
        _mint(victim, MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        OrderKey memory orderKey = _mint(attacker, !MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        uint256 tokenId = orderToken.encodeId(orderKey);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        vm.prank(attacker);
        orderToken.transferFrom(victim, attacker2, tokenId);
    }

    function testTransferFromUnauthorized() public {
        address from = address(0x123);
        address to = address(0x456);
        address unauthorized = address(0x789);
        OrderKey memory orderKey = _mint(from, MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        uint256 tokenId = orderToken.encodeId(orderKey);

        vm.prank(unauthorized);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        orderToken.transferFrom(from, to, tokenId);
    }

    function testTransferFromToZeroAddress() public {
        address from = address(0x123);
        OrderKey memory orderKey = _mint(from, MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        uint256 tokenId = orderToken.encodeId(orderKey);

        vm.prank(from);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.EMPTY_INPUT));
        orderToken.transferFrom(from, address(0), tokenId);
    }

    function testSafeTransferFrom() public {
        address from = address(0x123);
        address to = address(0x456);
        OrderKey memory orderKey = _mint(from, MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        uint256 tokenId = orderToken.encodeId(orderKey);
        vm.prank(from);
        orderToken.approve(address(0x435), tokenId);

        uint256 snapshotId = vm.snapshot();
        // check Approval Event and external call to market
        vm.expectEmit(true, true, true, true);
        emit Approval(from, address(0), tokenId);
        vm.expectCall(address(this), abi.encodeCall(CloberOrderBook.changeOrderOwner, (orderKey, to)));
        vm.prank(from);
        orderToken.safeTransferFrom(from, to, tokenId);
        // check Transfer Event
        vm.revertTo(snapshotId);
        vm.expectEmit(true, true, true, true);
        emit Transfer(from, to, tokenId);
        vm.prank(from);
        orderToken.safeTransferFrom(from, to, tokenId);

        assertEq(orderToken.ownerOf(tokenId), to, "OWNER");
        assertEq(orderToken.balanceOf(from), 0, "FROM_BALANCE");
        assertEq(orderToken.balanceOf(to), 1, "TO_BALANCE");
        assertEq(orderToken.getApproved(tokenId), address(0), "APPROVE");
    }

    function testSafeTransferFromUnauthorized() public {
        address from = address(0x123);
        address to = address(0x456);
        address unauthorized = address(0x789);
        OrderKey memory orderKey = _mint(from, MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        uint256 tokenId = orderToken.encodeId(orderKey);

        vm.prank(unauthorized);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        orderToken.safeTransferFrom(from, to, tokenId);
    }

    function testSafeTransferFromToContract() public {
        address from = address(0x123);
        address to = address(new MockERC721Receiver()); // which implements onERC721Received()
        address spender = address(0x789);
        OrderKey memory orderKey = _mint(from, MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        uint256 tokenId = orderToken.encodeId(orderKey);
        vm.prank(from);
        orderToken.approve(spender, tokenId);

        uint256 snapshotId = vm.snapshot();
        // check Approval Event and external call to market
        vm.expectEmit(true, true, true, true);
        emit Approval(from, address(0), tokenId);
        vm.expectCall(address(this), abi.encodeCall(CloberOrderBook.changeOrderOwner, (orderKey, to)));
        vm.prank(spender);
        orderToken.safeTransferFrom(from, to, tokenId);
        // check Transfer Event and external call to receiver contract
        vm.revertTo(snapshotId);
        vm.expectEmit(true, true, true, true);
        emit Transfer(from, to, tokenId);
        vm.expectCall(to, abi.encodeCall(IERC721Receiver.onERC721Received, (spender, from, tokenId, "")));
        vm.prank(spender);
        orderToken.safeTransferFrom(from, to, tokenId);

        assertEq(orderToken.ownerOf(tokenId), to, "OWNER");
        assertEq(orderToken.balanceOf(from), 0, "FROM_BALANCE");
        assertEq(orderToken.balanceOf(to), 1, "TO_BALANCE");
        assertEq(orderToken.getApproved(tokenId), address(0), "APPROVE");
    }

    function testSafeTransferFromToContractWithoutReceiver() public {
        address from = address(0x123);
        address to = address(new MockWETH()); // any contract without receiver
        OrderKey memory orderKey = _mint(from, MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        uint256 tokenId = orderToken.encodeId(orderKey);

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.NOT_IMPLEMENTED_INTERFACE));
        vm.prank(from);
        orderToken.safeTransferFrom(from, to, tokenId);
    }

    function testSafeTransferFromToContractReturnsWrongSelector() public {
        address from = address(0x123);
        address to = address(new MockERC721Receiver());
        OrderKey memory orderKey = _mint(from, MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        uint256 tokenId = orderToken.encodeId(orderKey);

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.NOT_IMPLEMENTED_INTERFACE));
        vm.prank(from);
        orderToken.safeTransferFrom(from, to, tokenId, abi.encode(bytes32("return wrong")));
    }

    function testSafeTransferFromToContractRevertsWithoutReason() public {
        address from = address(0x123);
        address to = address(new MockERC721Receiver());
        OrderKey memory orderKey = _mint(from, MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        uint256 tokenId = orderToken.encodeId(orderKey);

        vm.expectRevert(bytes("Custom Error"));
        vm.prank(from);
        orderToken.safeTransferFrom(from, to, tokenId, abi.encode(bytes32("custom error")));
    }

    function testOnMint() public {
        address to = address(0x123);
        uint256 tokenId = orderToken.encodeId(OrderKey(MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX));
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), to, tokenId);
        orderToken.onMint(to, OrderKey(MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX).encode());
        assertEq(orderToken.balanceOf(to), 1, "BALANCE");
    }

    function testOnMintAccess() public {
        address to = address(0x123);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        vm.prank(to);
        orderToken.onMint(to, OrderKey(MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX).encode());
    }

    function testOnMintToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.EMPTY_INPUT));
        orderToken.onMint(address(0), OrderKey(MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX).encode());
    }

    function testOnBurn() public {
        address to = address(0x123);
        uint256 tokenId = orderToken.encodeId(_mint(to, MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX));
        vm.prank(to);
        orderToken.approve(address(0x435), tokenId);

        vm.expectEmit(true, true, true, true);
        emit Transfer(to, address(0), tokenId);
        orderToken.onBurn(OrderKey(MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX).encode());

        assertEq(orderToken.getApproved(tokenId), address(0), "APPROVAL");
        assertEq(orderToken.balanceOf(to), 0, "BALANCE");
    }

    function testOnBurnAccess() public {
        address to = address(0x123);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        vm.prank(to);
        orderToken.onBurn(OrderKey(MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX).encode());
    }

    function testBurnAll() public {
        address user = address(0x123);
        address receiver = address(0x456);
        OrderKey[] memory orderKeys = new OrderKey[](2);
        uint256[] memory tokenIds = new uint256[](2);
        orderKeys[0] = _mint(user, MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        orderKeys[1] = _mint(user, !MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        tokenIds[0] = orderToken.encodeId(orderKeys[0]);
        tokenIds[1] = orderToken.encodeId(orderKeys[1]);

        vm.expectCall(address(this), abi.encodeCall(CloberOrderBook.cancel, (receiver, orderKeys)));
        orderToken.cancel(user, tokenIds, receiver);
    }

    function testBurnAllAccess() public {
        address user = address(0x123);
        address receiver = address(0x456);
        OrderKey[] memory orderKeys = new OrderKey[](2);
        uint256[] memory tokenIds = new uint256[](2);
        orderKeys[0] = _mint(user, MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        orderKeys[1] = _mint(user, !MOCK_IS_BID, MOCK_PRICE_INDEX, MOCK_ORDER_INDEX);
        tokenIds[0] = orderToken.encodeId(orderKeys[0]);
        tokenIds[1] = orderToken.encodeId(orderKeys[1]);

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        orderToken.cancel(receiver, tokenIds, receiver);

        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.ACCESS));
        vm.prank(user);
        orderToken.cancel(user, tokenIds, receiver);
    }

    function testEncodeAndDecode(
        bool isBid,
        uint16 priceIndex,
        uint232 orderIndex
    ) public {
        OrderKey memory orderKey = OrderKey(isBid, priceIndex, orderIndex);
        uint256 id = orderToken.encodeId(orderKey);
        OrderKey memory decodedOrderKey = orderToken.decodeId(id);
        assertEq(orderKey.isBid, decodedOrderKey.isBid, "IS_BID");
        assertEq(orderKey.priceIndex, decodedOrderKey.priceIndex, "PRICE_INDEX");
        assertEq(orderKey.orderIndex, decodedOrderKey.orderIndex, "ORDER_INDEX");
    }

    function testEncodeWithInvalidOrderIndex() public {
        OrderKey memory orderKey = OrderKey(MOCK_IS_BID, MOCK_PRICE_INDEX, uint256(type(uint232).max) + 1);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_ID));
        orderToken.encodeId(orderKey);
    }

    function testDecodeWithInvalidTokenId(uint256 tokenId) public {
        uint256 minInvalidTokenId = 2 << 248; // isBid > 1
        // It should work
        orderToken.decodeId(minInvalidTokenId - 1);

        tokenId = bound(tokenId, minInvalidTokenId, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.INVALID_ID));
        orderToken.decodeId(tokenId);
    }

    function _mint(
        address to,
        bool isBid,
        uint16 priceIndex,
        uint232 orderIndex
    ) internal returns (OrderKey memory orderKey) {
        orderKey = OrderKey(isBid, priceIndex, orderIndex);
        uint256 tokenId = orderToken.encodeId(orderKey);
        orderToken.onMint(to, tokenId);
        mockOrderOwners[tokenId] = to;
    }
}
