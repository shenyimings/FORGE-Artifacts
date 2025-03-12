// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./NetworkProperties.sol";

contract DevProperties is NetworkProperties {
    uint256 private constant BNB_SUPPLY = 100 * 10 ** 18;

    function getNativeSupply() external view override returns (uint256) {
        return BNB_SUPPLY;
    }
}
