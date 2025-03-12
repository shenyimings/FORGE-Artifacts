// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../libraries/ScaledMath.sol";
import "../oracles/GenericOracle.sol";

contract TestGenericOracle is GenericOracle {
    using ScaledMath for uint256;
    mapping(address => uint256) internal _prices;

    function setPrice(address token, uint256 price) external {
        _prices[token] = price;
    }

    function getUSDPrice(address token) public view override returns (uint256) {
        if (_prices[token] > 0) {
            return _prices[token];
        }
        if (_chainlinkOracle.isTokenSupported(token)) {
            return _chainlinkOracle.getUSDPrice(token);
        }
        return _curveLpOracle.getUSDPrice(token);
    }
}
