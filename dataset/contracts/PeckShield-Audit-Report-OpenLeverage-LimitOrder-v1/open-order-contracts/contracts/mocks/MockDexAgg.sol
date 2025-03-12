// SPDX-License-Identifier: BUSL-1.1
pragma solidity >0.7.6;

import "../interfaces/OpenLevInterface.sol";
import "../interfaces/DexAggregatorInterface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma experimental ABIEncoderV2;

contract MockDexAgg is DexAggregatorInterface {
    uint8 private constant _decimals = 18;
    uint256 private _price;
    uint256 private _cAvgPrice;
    uint256 private _hAvgPrice;
    uint256 private _timestamp;
    uint256 private _timeWindow;

    function setPrice(
        uint256 price_,
        uint256 cAvgPrice_,
        uint256 hAvgPrice_,
        uint256 timestamp_
    ) external {
        _price = price_;
        _cAvgPrice = cAvgPrice_;
        _hAvgPrice = hAvgPrice_;
        _timestamp = timestamp_;
    }

    function getPrice(
        address desToken,
        address quoteToken,
        bytes memory data
    ) external view override returns (uint256 price, uint8 decimals) {
        desToken;
        quoteToken;
        data;
        price = _price;
        decimals = _decimals;
    }

    function getPriceCAvgPriceHAvgPrice(
        address desToken,
        address quoteToken,
        uint32 secondsAgo,
        bytes memory dexData
    )
        external
        view
        override
        returns (
            uint256 price,
            uint256 cAvgPrice,
            uint256 hAvgPrice,
            uint8 decimals,
            uint256 timestamp
        )
    {
        desToken;
        quoteToken;
        secondsAgo;
        dexData;
        price = _price;
        cAvgPrice = _cAvgPrice;
        hAvgPrice = _hAvgPrice;
        decimals = _decimals;
        timestamp = _timestamp;
    }

    function updatePriceOracle(
        address desToken,
        address quoteToken,
        uint32 timeWindow,
        bytes memory data
    ) external override returns (bool) {
        desToken;
        quoteToken;
        data;
        _timeWindow = timeWindow;
        return true;
    }
}
