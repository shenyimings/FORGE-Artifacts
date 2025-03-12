// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../Interfaces/IOracle.sol";
import "../Interfaces/IStETH.sol";

/*
* PriceFeed placeholder for testnet and development. The price is simply set manually and saved in a state 
* variable. The contract does not connect to a live Chainlink price feed. 
*/
contract StETHOracleTestnet is IOracle {
    
    uint256 private _price = 200 * 1e18;

    IStETH internal stETH;

    constructor() {
        stETH = IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    }

    // --- Functions ---

    // View price getter for simplicity in tests
    function getPrice() external view returns (uint256) {
        return _price;
    }

    // function fetchPrice() external override returns (uint256) {
    //     // Fire an event just like the mainnet version would.
    //     // This lets the subgraph rely on events to get the latest price even when developing locally.
    //     emit LastGoodPriceUpdated(_price);
    //     return _price;
    // }

    function fetchPrice_view() external view override returns (uint) {
        return _price;
    }

    function fetchPrice() external view override returns (uint) {
        return _price;
    }

    // Manual external price setter.
    function setPrice(uint256 price) external returns (bool) {
        _price = price;
        return true;
    }
}
