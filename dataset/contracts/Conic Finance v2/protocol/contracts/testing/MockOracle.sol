// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../interfaces/IOracle.sol";

contract MockOracle is IOracle {
    mapping(address => uint256) internal _prices;

    function setPrice(address token, uint256 price) external {
        _prices[token] = price;
    }

    function getUSDPrice(address token) external view override returns (uint256) {
        return _prices[token];
    }

    function isTokenSupported(address token) external view returns (bool) {
        return _prices[token] > 0;
    }
}
