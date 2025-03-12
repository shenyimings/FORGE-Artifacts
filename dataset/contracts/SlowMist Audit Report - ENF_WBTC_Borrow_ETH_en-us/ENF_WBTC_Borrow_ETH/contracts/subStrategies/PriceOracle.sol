// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IPriceOracle.sol";
import "./interfaces/IChainlink.sol";

contract PriceOracle is IPriceOracle {
    address public ethOracle;
    address public wbtcOracle;

    constructor(address _ethOracle, address _wbtcOracle) {
        ethOracle = _ethOracle;
        wbtcOracle = _wbtcOracle;
    }

    function getAssetPrice(address _asset) external view override returns (uint256) {
        (, int256 ethPrice, , , ) = IChainlink(ethOracle).latestRoundData();
        (, int256 wbtcPrice, , , ) = IChainlink(wbtcOracle).latestRoundData();

        return (uint256(wbtcPrice) * 1e18) / uint256(ethPrice);
    }
}
