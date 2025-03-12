//SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.0;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Welford} from "../libraries/Welford.sol";
import {DSMath} from "../libraries/DSMath.sol";
import {VolatilityOracle} from "../series/VolatilityOracle.sol";
import {Math} from "../libraries/Math.sol";
import {PRBMathSD59x18} from "../libraries/PRBMathSD59x18.sol";
import "../series/IPriceOracle.sol";

contract MockVolatilityOracle is DSMath, VolatilityOracle {
    using SafeMath for uint256;
    uint256 private _price;

    mapping(address => mapping(address => uint256)) public _annualizedVol;

    constructor(
        uint32 _period,
        IPriceOracle _priceOracle,
        uint256 _windowInDays
    ) VolatilityOracle(_period, _priceOracle, _windowInDays) {}

    function setPrice(uint256 price) public {
        _price = price;
    }

    /**
     * @notice create token pair for testing so include data not just the token pair
     */
    function addTokenPairAndLastPrice(
        address underlyingToken,
        address priceToken,
        uint256 lastPrice,
        uint32 lastTimestamp,
        int96 mean,
        uint256 dsq,
        int256 logReturn
    ) external {
        require(
            observations[underlyingToken][priceToken].length < 1,
            "Pool initialized"
        );
        observations[underlyingToken][priceToken][0] = logReturn;
        lastPrices[underlyingToken][priceToken] = lastPrice;
        accumulators[underlyingToken][priceToken].currentObservationIndex = 0;
        accumulators[underlyingToken][priceToken].lastTimestamp = lastTimestamp;
        accumulators[underlyingToken][priceToken].mean = mean;
        accumulators[underlyingToken][priceToken].dsq = dsq;
    }

    function annualizedVol(address underlyingToken, address priceToken)
        public
        view
        override
        returns (uint256)
    {
        return _annualizedVol[underlyingToken][priceToken];
    }

    function setAnnualizedVol(
        address underlyingToken,
        address priceToken,
        uint256 volatility
    ) external {
        _annualizedVol[underlyingToken][priceToken] = volatility;
    }
}
