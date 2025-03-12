// SPDX-License-Identifier: MIT

import '../interfaces/IAnkrETHOracle.sol';

pragma solidity 0.8.9;

contract TestAnkrETHOracle is IAnkrETHOracle {
    uint256 rate = 1e18;

    function getRatioFor(address addr) external view returns (uint256) {
        require(addr == 0xE95A203B1a91a908F9B9CE46459d101078c2c3cb, 'TestAnkrETHOracle: invalid address');
        return rate;
    }

    function setRate(uint256 _rate) external {
        rate = _rate;
    }
}
