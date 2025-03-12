pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;

import "../oracle/IPriceConsumerV3.sol";

contract MockSettablePriceConsumerV3 is IPriceConsumerV3 {
    int256 internal _price;

    function set(int256 price) external {
        _price = price;
    }

    function getLatestPrice() public view override returns (int256 price) {
        return _price;
    }
}
