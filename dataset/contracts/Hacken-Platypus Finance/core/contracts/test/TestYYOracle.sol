// SPDX-License-Identifier: MIT

import '../interfaces/IyyAvax.sol';

pragma solidity 0.8.9;

contract TestYYOracle is IyyAvax {
    uint256 rate = 1e18;

    function pricePerShare() external view returns (uint256) {
        return rate;
    }

    function setRate(uint256 _rate) external {
        rate = _rate;
    }
}
