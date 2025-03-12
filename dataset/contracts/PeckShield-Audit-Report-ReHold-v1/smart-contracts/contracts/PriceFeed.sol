// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./interfaces/IPriceFeed.sol";

contract PriceFeed is AccessControl, IPriceFeed {
  uint256 private constant DECIMALS = 18;

  mapping(address => Aggregator) private _aggregators;
  address[] private _tokens;

  constructor() {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  function currentCrossPrice(address baseToken, address quoteToken) public view returns (uint256) {
    Aggregator memory basePriceFeed = _aggregators[baseToken];
    Aggregator memory quotePriceFeed = _aggregators[quoteToken];

    uint256 basePrice = uint256(basePriceFeed.aggregator.latestAnswer());
    uint256 quotePrice = uint256(quotePriceFeed.aggregator.latestAnswer());

    return _crossPrice(basePrice, basePriceFeed, quotePrice, quotePriceFeed);
  }

  function historicalCrossPrice(
    address baseToken,
    uint80 baseRoundId,
    address quoteToken,
    uint80 quoteRoundId,
    uint256 timestamp
  ) public view returns (uint256 price) {
    Aggregator memory basePriceFeed = _aggregators[baseToken];
    Aggregator memory quotePriceFeed = _aggregators[quoteToken];

    (, int256 basePrice, uint256 baseStartedAt, , ) = basePriceFeed.aggregator.getRoundData(baseRoundId);
    (, int256 quotePrice, uint256 quoteStartedAt, , ) = quotePriceFeed.aggregator.getRoundData(quoteRoundId);

    uint256 nextBaseStartedAt = basePriceFeed.aggregator.getTimestamp(baseRoundId + 1);
    uint256 nextQuoteStartedAt = quotePriceFeed.aggregator.getTimestamp(quoteRoundId + 1);

    require(
      baseStartedAt != 0 &&
      quoteStartedAt != 0 &&
      baseStartedAt <= timestamp &&
      quoteStartedAt <= timestamp &&
      (nextBaseStartedAt == 0 || nextBaseStartedAt >= timestamp) &&
      (nextQuoteStartedAt == 0 || nextQuoteStartedAt >= timestamp),
      "PriceFeed: Out of range"
    );

    return _crossPrice(uint256(basePrice), basePriceFeed, uint256(quotePrice), quotePriceFeed);
  }

  function _crossPrice(
    uint256 basePrice,
    Aggregator memory basePriceFeed,
    uint256 quotePrice,
    Aggregator memory quotePriceFeed
  ) private pure returns (uint256) {

    basePrice = _scalePrice(basePrice, basePriceFeed.decimals);
    quotePrice = _scalePrice(quotePrice, quotePriceFeed.decimals);

    return (basePrice * 10 ** quotePriceFeed.tokenDecimals) / quotePrice;
  }

  function _scalePrice(uint256 price, uint256 priceDecimals) private pure returns (uint256) {
    if (priceDecimals < DECIMALS) {
      return price * (10 ** (DECIMALS - priceDecimals));
    }

    return price;
  }

  function updateAggregator(address token, address _aggregator) public onlyRole(DEFAULT_ADMIN_ROLE) {
    if (address(_aggregators[token].aggregator) == address(0x0)) _tokens.push(token);

    Aggregator storage agg = _aggregators[token];

    agg.aggregator = AggregatorV2V3Interface(_aggregator);
    agg.tokenDecimals = ERC20(token).decimals();
    agg.decimals = agg.aggregator.decimals();
  }

  function aggregator(address token) public view returns (AggregatorV2V3Interface) {
    return _aggregators[token].aggregator;
  }

  function aggregators() public view returns (TokenAggregator[] memory tokenAggregators) {
    tokenAggregators = new TokenAggregator[](_tokens.length);

    for (uint32 i = 0; i < _tokens.length; i++) {
      TokenAggregator memory ta;

      ta.token = _tokens[i];
      ta.aggregator = address(_aggregators[ta.token].aggregator);

      tokenAggregators[i] = ta;
    }
  }
}
