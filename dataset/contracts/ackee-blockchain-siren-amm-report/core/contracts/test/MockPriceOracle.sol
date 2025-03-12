// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.0;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "../series/PriceOracle.sol";

//Add chainlinkname at begining

/**
 * The MockPriceOracle exists to ease testing the AMM's interaction with the onchain price feed oracle.
 * During tests, this contract should be deployed and passed to the AMM .initialize method, and for each
 * test the .setLatestAnswer method may be used to change the price returned by the MockPriceOracle to
 * the AMM.
 */
contract MockPriceOracle is PriceOracle, AggregatorV3Interface {
    int256 public latestAnswer;

    uint8 internal priceDecimals;

    constructor(uint8 _priceDecimals) public {
        priceDecimals = _priceDecimals;
    }

    function setLatestAnswer(int256 _latestAnswer) public {
        latestAnswer = _latestAnswer;
    }

    function decimals() public view override returns (uint8) {
        return priceDecimals;
    }

    // just put something here, it's not used during tests
    function description() public view override returns (string memory) {
        return "BTC/USD";
    }

    // just put something here, it's not used during tests
    function version() public view override returns (uint256) {
        return 3;
    }

    // This function is never used for testing, so just use arbitrary return values. Only
    // latestRoundData gets used for testing
    function getRoundData(uint80 _roundId)
        public
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId, 42, 0, 1, _roundId);
    }

    function latestRoundData()
        public
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (1337, latestAnswer, 0, 1, 1337); // 1337 is an arbitrary value, it does not matter for testing
    }

    function setSettlementPriceOnDate(
        address underlyingToken,
        address priceToken,
        uint256 date,
        uint256 price
    ) external {
        require(
            oracles[underlyingToken][priceToken] != address(0x0),
            "no oracle address for this token pair"
        );

        // the given date must be aligned to 8am UTC and the correct offset, otherwise we will end up
        // setting a price on a un-aligned date
        require(
            date == get8amWeeklyOrDailyAligned(date),
            "date is not aligned"
        );

        // the settlement date must be in the past, otherwise any address will be able to set future settlement prices,
        // which we cannot allow
        require(date < block.timestamp, "date must be in the past");

        // we do not want to overwrite a settlement date that has already had its price set, so we end execution
        // early if we find that to be true
        if (settlementPrices[underlyingToken][priceToken][date] != 0) {
            return;
        }

        // fetch the current spot price for this pair's oracle, and set it as the price for the given date
        uint256 spotPrice = getCurrentPrice(underlyingToken, priceToken);
        settlementPrices[underlyingToken][priceToken][date] = price;

        emit SettlementPriceSet(underlyingToken, priceToken, date, spotPrice);
    }
}
