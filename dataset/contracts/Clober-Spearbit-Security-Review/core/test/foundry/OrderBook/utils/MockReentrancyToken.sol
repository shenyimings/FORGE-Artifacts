// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "../../../../contracts/mocks/MockERC20.sol";
import "../../../../contracts/interfaces/CloberOrderBook.sol";

contract MockReentrancyToken is MockERC20("name", "SYMBOL", 18) {
    CloberOrderBook market;
    bytes32 callType;

    function startReentrant(address market_, bytes32 _callType) public {
        market = CloberOrderBook(market_);
        callType = _callType;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (callType != bytes32(0)) {
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
                // argument is not important
                market.collectFees(address(0), address(0));
            }
        }
        return super.transfer(to, amount);
    }
}
