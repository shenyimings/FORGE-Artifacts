// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC20Mock.sol";

contract ERC20MockUpgraded is ERC20Mock {
    uint256 public importantVariable;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimalPlaces
    ) ERC20Mock(name, symbol, decimalPlaces) {}

    function doUpgrade(uint256 value) external {
        importantVariable = value;
    }

    function addedFunction() external pure returns (uint256) {
        return 42;
    }
}
