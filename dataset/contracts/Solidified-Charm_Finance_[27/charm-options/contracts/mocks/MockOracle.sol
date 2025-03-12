// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "../../interfaces/IOracle.sol";

contract MockOracle is IOracle {
    uint256 public price;

    function getPrice() external override view returns (uint256) {
        return price;
    }

    function setPrice(uint256 _price) external {
        price = _price;
    }
}
