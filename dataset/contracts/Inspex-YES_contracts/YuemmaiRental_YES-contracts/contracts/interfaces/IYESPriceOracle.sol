//SPDX-License-Identifier: MIT
pragma solidity >= 0.5.0;

import "./IPriceOracle.sol";

interface IYESPriceOracle is IPriceOracle {
    event StableCoinAdded(address stableCoin, uint index);
    event StableCoinRemoved(address stableCoin, uint index);

    function getYESPrice() external view returns (uint);
}