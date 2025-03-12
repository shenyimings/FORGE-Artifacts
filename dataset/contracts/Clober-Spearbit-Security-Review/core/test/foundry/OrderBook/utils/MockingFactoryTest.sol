// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

abstract contract MockingFactoryTest {
    address public daoTreasury = address(0xdead); // default treasury address
    address internal _host = address(this);

    // mocking factory's getMarketHost
    function getMarketHost(address market) external view returns (address) {
        market;
        return _host;
    }
}
