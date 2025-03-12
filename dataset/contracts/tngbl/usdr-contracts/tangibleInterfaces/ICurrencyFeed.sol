// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface ICurrencyFeed {
    function currencyPriceFeeds(string memory currency)
        external
        view
        returns (AggregatorV3Interface priceFeed);

    function conversionPremiums(string memory currency)
        external
        view
        returns (uint256 conversionPremium);
}
