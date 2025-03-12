// SPDX-License-Identifier: MIT

import '../interfaces/IaAvaxc.sol';

pragma solidity 0.8.9;

contract TestAAvaxC is IaAvaxc {
    uint256 rate = 1e18;

    function ratio() external view returns (uint256) {
        return rate;
    }

    function setRate(uint256 _rate) external {
        rate = _rate;
    }
}
