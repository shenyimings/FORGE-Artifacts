// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../../../contracts/interfaces/CloberMarketSwapCallbackReceiver.sol";
import "../../../../contracts/mocks/MockQuoteToken.sol";
import "../../../../contracts/mocks/MockBaseToken.sol";
import "../../../../contracts/mocks/MockPriceBook.sol";
import "../../../../contracts/OrderNFT.sol";
import "../../../../contracts/OrderBook.sol";
import "../utils/MockReentrancyToken.sol";
import "./Constants.sol";

contract OrderBookReentrancyUnitTest is Test, CloberMarketSwapCallbackReceiver, CloberMarketFlashCallbackReceiver {
    address constant FEE_RECEIVER = address(0xfee);

    uint96 internal constant _QUOTE_UNIT = 10**4; // unit is 1 USDC
    uint256 internal constant _INIT_AMOUNT = 1000000000;

    MockQuoteToken quoteToken;
    MockReentrancyToken baseToken;
    OrderBook market;
    OrderNFT orderToken;
    uint256 receiveStatus;
    bytes receiveErr;

    // mocking factory to get host and daoTreasury
    function getMarketHost(address market_) external view returns (address) {
        market_;
        return address(this);
    }

    function daoTreasury() external view returns (address) {
        return address(this);
    }

    function setUp() public {
        quoteToken = new MockQuoteToken();
        baseToken = new MockReentrancyToken();
        orderToken = new OrderNFT(address(this), address(this));
        market = new OrderBook(
            address(orderToken),
            address(quoteToken),
            address(baseToken),
            10**4,
            int24(Constants.MAKE_FEE),
            Constants.TAKE_FEE,
            address(this),
            address(new MockPriceBook())
        );
        orderToken.init("", "", address(market));

        // mint & approve
        uint256 _quotePrecision = 10**quoteToken.decimals();
        quoteToken.mint(address(this), 1000000000 * _quotePrecision);
        quoteToken.approve(address(market), type(uint256).max);

        uint256 _basePrecision = 10**baseToken.decimals();
        baseToken.mint(address(this), 1000000000 * _basePrecision);
        baseToken.approve(address(market), type(uint256).max);
    }

    function cloberMarketSwapCallback(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        bytes calldata data
    ) external payable {
        tokenIn;
        tokenOut;
        amountIn;
        amountOut;
        bytes32 callType = abi.decode(data, (bytes32));
        if (callType == bytes32("limitOrder")) {
            market.limitOrder(address(this), 10, 0, 1000, 0, new bytes(0));
        } else if (callType == bytes32("marketOrder")) {
            market.marketOrder(address(this), 0, 0, 0, 0, new bytes(0));
        } else if (callType == bytes32("claim")) {
            market.claim(address(this), new OrderKey[](0));
        } else if (callType == bytes32("cancel")) {
            market.cancel(address(this), new OrderKey[](0));
        } else if (callType == bytes32("flash")) {
            market.flash(address(this), 0, 0, new bytes(0));
        } else if (callType == bytes32("collectFees")) {
            market.collectFees(address(quoteToken), address(this));
        } else {
            IERC20(tokenIn).transfer(msg.sender, amountIn);
        }
    }

    function cloberMarketFlashCallback(
        address quoteToken_,
        address baseToken_,
        uint256 quoteAmount,
        uint256 baseAmount,
        uint256 quoteFee,
        uint256 baseFee,
        bytes calldata data
    ) external {
        quoteToken_;
        baseToken_;
        quoteAmount;
        baseAmount;
        quoteFee;
        baseFee;
        bytes32 callType = abi.decode(data, (bytes32));

        if (callType == bytes32("limitOrder")) {
            market.limitOrder(address(this), 0, 1000, 10, 0, new bytes(0));
        } else if (callType == bytes32("marketOrder")) {
            market.marketOrder(address(this), 0, 0, 0, 0, new bytes(0));
        } else if (callType == bytes32("claim")) {
            market.claim(address(this), new OrderKey[](0));
        } else if (callType == bytes32("cancel")) {
            market.cancel(address(this), new OrderKey[](0));
        } else if (callType == bytes32("flash")) {
            market.flash(address(this), 0, 0, new bytes(0));
        } else if (callType == bytes32("collectFees")) {
            market.collectFees(address(quoteToken), address(this));
        }
    }

    receive() external payable {
        if (receiveStatus == 1) {
            try market.limitOrder(address(this), 10, 0, 1000, 0, new bytes(0)) {} catch (bytes memory reason) {
                receiveErr = reason;
            }
        } else if (receiveStatus == 2) {
            try market.marketOrder(address(this), 0, 0, 0, 0, new bytes(0)) {} catch (bytes memory reason) {
                receiveErr = reason;
            }
        } else if (receiveStatus == 3) {
            try market.claim(address(this), new OrderKey[](0)) {} catch (bytes memory reason) {
                receiveErr = reason;
            }
        } else if (receiveStatus == 4) {
            try market.cancel(address(this), new OrderKey[](0)) {} catch (bytes memory reason) {
                receiveErr = reason;
            }
        } else if (receiveStatus == 5) {
            try market.flash(address(this), 0, 0, new bytes(0)) {} catch (bytes memory reason) {
                receiveErr = reason;
            }
        } else if (receiveStatus == 6) {
            try market.collectFees(address(quoteToken), address(this)) {} catch (bytes memory reason) {
                receiveErr = reason;
            }
        }
    }

    function testLimitOrderReentrant() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.limitOrder(address(this), 10, 0, 1000, 0, abi.encodePacked(bytes32("limitOrder")));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.limitOrder(address(this), 10, 0, 1000, 0, abi.encodePacked(bytes32("marketOrder")));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.limitOrder(address(this), 10, 0, 1000, 0, abi.encodePacked(bytes32("claim")));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.limitOrder(address(this), 10, 0, 1000, 0, abi.encodePacked(bytes32("cancel")));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.limitOrder(address(this), 10, 0, 1000, 0, abi.encodePacked(bytes32("flash")));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.limitOrder(address(this), 10, 0, 1000, 0, abi.encodePacked(bytes32("collectFees")));
    }

    function testMarketOrderReentrant() public {
        // bid
        market.limitOrder(address(this), 10, 1000, 0, 1, abi.encodePacked(bytes32("pass")));

        uint8 options = 2; // ASK, with base
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.marketOrder(address(this), 0, 0, 10, options, abi.encodePacked(bytes32("limitOrder")));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.marketOrder(address(this), 0, 0, 10, options, abi.encodePacked(bytes32("marketOrder")));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.marketOrder(address(this), 0, 0, 10, options, abi.encodePacked(bytes32("claim")));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.marketOrder(address(this), 0, 0, 10, options, abi.encodePacked(bytes32("cancel")));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.marketOrder(address(this), 0, 0, 10, options, abi.encodePacked(bytes32("flash")));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.marketOrder(address(this), 0, 0, 10, options, abi.encodePacked(bytes32("collectFees")));
    }

    function testClaimReentrant() public {
        // bid
        market.limitOrder{value: 3 gwei}(address(this), 10000, 1000, 0, 1, abi.encodePacked(bytes32("pass")));
        // ask
        market.limitOrder(address(this), 9999, 0, type(uint88).max, 0, abi.encodePacked(bytes32("pass")));

        uint16[] memory ids = new uint16[](1);
        ids[0] = 0;
        OrderKey memory orderKey = OrderKey(true, 10000, 0);
        OrderKey[] memory orderKeys = new OrderKey[](1);
        orderKeys[0] = orderKey;

        for (uint256 status = 1; status < 7; status++) {
            uint256 id = vm.snapshot();
            receiveStatus = status;
            assertEq("", receiveErr);
            market.claim(address(this), orderKeys);
            assertEq(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY), receiveErr);
            vm.revertTo(id);
        }
    }

    function testCancelReentrant() public {
        // bid
        market.limitOrder{value: 3 gwei}(address(this), 10000, 1000, 0, 1, abi.encodePacked(bytes32("pass")));

        OrderKey[] memory orderKeys = new OrderKey[](1);
        orderKeys[0] = OrderKey(true, 10000, 0);

        for (uint256 status = 1; status < 7; status++) {
            uint256 id = vm.snapshot();
            receiveStatus = status;
            assertEq("", receiveErr);
            market.cancel(address(this), orderKeys);
            assertEq(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY), receiveErr);
            vm.revertTo(id);
        }
    }

    function testFlashReentrant() public {
        quoteToken.mint(address(market), 100);
        baseToken.mint(address(market), 100);
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.flash(address(this), 1, 1, abi.encodePacked(bytes32("limitOrder")));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.flash(address(this), 1, 1, abi.encodePacked(bytes32("marketOrder")));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.flash(address(this), 1, 1, abi.encodePacked(bytes32("claim")));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.flash(address(this), 1, 1, abi.encodePacked(bytes32("cancel")));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.flash(address(this), 1, 1, abi.encodePacked(bytes32("flash")));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.flash(address(this), 1, 1, abi.encodePacked(bytes32("collectFees")));
    }

    function testCollectFeesReentrant() public {
        // generate protocol fees
        // bid
        market.limitOrder{value: 3 gwei}(address(this), 10000, 1000, 0, 1, abi.encodePacked(bytes32("pass")));
        // ask
        market.limitOrder(address(this), 9999, 0, type(uint88).max, 0, abi.encodePacked(bytes32("pass")));
        uint16[] memory ids = new uint16[](1);
        ids[0] = 0;
        OrderKey memory orderKey = OrderKey(true, 10000, 0);
        OrderKey[] memory orderKeys = new OrderKey[](1);
        orderKeys[0] = orderKey;
        market.claim(address(this), orderKeys);

        baseToken.startReentrant(address(market), bytes32("limitOrder"));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.collectFees(address(baseToken), address(this));
        baseToken.startReentrant(address(market), bytes32("marketOrder"));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.collectFees(address(baseToken), address(this));
        baseToken.startReentrant(address(market), bytes32("claim"));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.collectFees(address(baseToken), address(this));
        baseToken.startReentrant(address(market), bytes32("cancel"));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.collectFees(address(baseToken), address(this));
        baseToken.startReentrant(address(market), bytes32("flash"));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.collectFees(address(baseToken), address(this));
        baseToken.startReentrant(address(market), bytes32("collectFees"));
        vm.expectRevert(abi.encodeWithSelector(Errors.CloberError.selector, Errors.REENTRANCY));
        market.collectFees(address(baseToken), address(this));
    }
}
