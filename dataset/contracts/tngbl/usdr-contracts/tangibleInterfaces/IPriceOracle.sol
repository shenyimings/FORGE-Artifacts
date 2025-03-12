// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IPriceOracle {
    function latestPrices() external view returns (uint256 value);

    function decimals() external view returns (uint8);

    function marketPriceNativeCurrency(uint256 fingerprint)
        external
        view
        returns (uint256 nativePrice, string memory currency);
}
