// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../core/network-properties/BSCProperties.sol";

contract NetworkPropertiesMock is BSCProperties {
    function changeWeth(address newAddress) external {
        weth = IWETH(newAddress);
    }
}
