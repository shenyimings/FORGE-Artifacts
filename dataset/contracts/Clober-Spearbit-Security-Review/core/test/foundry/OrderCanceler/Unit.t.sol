// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../../contracts/OrderCanceler.sol";
import "../../../contracts/OrderNFT.sol";
import "./utils/MockOrderNFT.sol";

contract OrderCancelerUnitTest is Test {
    OrderCanceler canceler;
    MockOrderNFT public orderToken;

    function setUp() public {
        canceler = new OrderCanceler();
        orderToken = new MockOrderNFT();
    }

    function testCancel() public {
        address user = address(0x123);

        CloberOrderCanceler.CancelParams[] memory paramsList = new CloberOrderCanceler.CancelParams[](1);
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 12;
        tokenIds[1] = 132;
        paramsList[0].market = address(this);
        paramsList[0].tokenIds = tokenIds;

        vm.expectCall(address(orderToken), abi.encodeCall(CloberOrderNFT.cancel, (user, paramsList[0].tokenIds, user)));
        vm.prank(user);
        canceler.cancel(paramsList);
    }

    function testCancelTo() public {
        address user = address(0x123);
        address receiver = address(0x456);

        CloberOrderCanceler.CancelParams[] memory paramsList = new CloberOrderCanceler.CancelParams[](1);
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 12;
        tokenIds[1] = 132;
        paramsList[0].market = address(this);
        paramsList[0].tokenIds = tokenIds;

        vm.expectCall(
            address(orderToken),
            abi.encodeCall(CloberOrderNFT.cancel, (user, paramsList[0].tokenIds, receiver))
        );
        vm.prank(user);
        canceler.cancelTo(paramsList, receiver);
    }
}
