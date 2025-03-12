// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/ComptrollerInterface.sol";

contract MockComptroller is ComptrollerInterface {
    struct AccountLiquidity {
        uint error;
        uint shortfall;
    }
    mapping(address => AccountLiquidity) private _accounts;
    mapping(address => bool) private _marketMap;
    address[] private _markets;
    address private _liquidityMining;

    function addMarket(address market) external {
        _markets.push(market);
        _marketMap[market] = true;
    }

    function getAllMarkets() external override view returns (address[] memory) {
        return _markets;
    }

    function markets(address market) external override view returns (bool, uint, uint) {
        return (_marketMap[market], uint(0), uint(0));
    }

    function getAccountLiquidity(address account) external override view returns (uint, uint, uint) {
        return (_accounts[account].error, uint(0), _accounts[account].shortfall); // liquidity is not important
    }

    function setLiquidityMining(address liquidityMining) external {
        _liquidityMining = liquidityMining;
    }

    function setAccountLiquidity(address account, uint error, uint shortfall) external {
        _accounts[account] = AccountLiquidity({
            error: error,
            shortfall: shortfall
        });
    }
}

