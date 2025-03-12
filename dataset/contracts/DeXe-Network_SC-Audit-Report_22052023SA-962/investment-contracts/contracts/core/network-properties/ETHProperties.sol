// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./NetworkProperties.sol";

contract ETHProperties is NetworkProperties {
    uint256 private constant ETH_SUPPLY = 120_000_000 * 10 ** 18;

    function getNativeSupply() external view override returns (uint256) {
        return ETH_SUPPLY;
    }
}
