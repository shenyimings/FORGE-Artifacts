// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

import { IChainlinkAggregatorV3 } from "../dependencies/IChainlinkAggregatorV3.sol";
import { IIndexOracle } from "../interfaces/IIndexOracle.sol";
import { Errors } from "../libraries/Errors.sol";

contract OracleArbitrum is
    ContextUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    IIndexOracle
{
    mapping(address => IChainlinkAggregatorV3) public priceFeeds;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address wETH, address wETHPriceFeed)
        external
        initializer
    {
        __Context_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        setPriceFeed(wETH, wETHPriceFeed);
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner {}

    function decimals() external pure returns (uint8) {
        return 8;
    }

    function getPrice(
        address token,
        bool maximize,
        bool includeAmmPrice
    ) public view returns (uint256) {
        int256 chainlinkPrice = _getChainlinkPrice(token);

        if (!includeAmmPrice) {
            if (chainlinkPrice < 0) {
                revert Errors.Oracle_TokenNotSupported(token); // Token price must be nonnegative.
            }

            return uint256(chainlinkPrice);
        }

        int256 ammPrice = -1;

        int256 price;

        if (!maximize && chainlinkPrice >= 0 && ammPrice >= 0) {
            price = chainlinkPrice > ammPrice ? ammPrice : chainlinkPrice;
        } else {
            price = chainlinkPrice > ammPrice ? chainlinkPrice : ammPrice;
        }

        if (price < 0) {
            revert Errors.Oracle_TokenNotSupported(token); // Token price must be nonnegative.
        }

        return uint256(price);
    }

    function getPrices(
        address[] calldata tokens,
        bool maximize,
        bool includeAmmPrice
    ) external view returns (uint256[] memory prices) {
        prices = new uint256[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            prices[i] = getPrice(tokens[i], maximize, includeAmmPrice);
        }
    }

    function setPriceFeed(address token, address priceFeed) public onlyOwner {
        if (token == address(0)) {
            revert Errors.Oracle_ZeroAddress();
        }

        priceFeeds[token] = IChainlinkAggregatorV3(priceFeed);
    }

    function _getChainlinkPrice(address token)
        internal
        view
        returns (int256 price)
    {
        if (address(priceFeeds[token]) == address(0)) {
            return -1;
        }

        (, price, , , ) = priceFeeds[token].latestRoundData();
    }
}
