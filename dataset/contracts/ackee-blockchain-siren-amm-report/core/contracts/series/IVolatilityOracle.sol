// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.0;

interface IVolatilityOracle {
    function vol(address underlyingToken, address priceToken)
        external
        view
        returns (uint256 standardDeviation);

    function annualizedVol(address underlyingToken, address priceToken)
        external
        view
        returns (uint256 annualStdev);

    function commit(address underlyingToken, address priceToken) external;

    function addTokenPair(address underlyingToken, address priceToken) external;

    function setAccumulator(
        address underlyingToken,
        address priceToken,
        uint8 currentObservationIndex,
        uint32 lastTimestamp,
        int96 mean,
        uint256 dsq
    ) external;

    function setLastPrice(
        address underlyingToken,
        address priceToken,
        uint256 price
    ) external;
}
