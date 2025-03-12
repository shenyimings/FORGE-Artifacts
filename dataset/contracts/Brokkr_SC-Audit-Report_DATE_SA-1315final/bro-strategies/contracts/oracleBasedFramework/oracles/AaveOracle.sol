// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/IPriceOracle.sol";
import "../libraries/InvestableLib.sol";
import "../libraries/Math.sol";
import "../../dependencies/aave/IPriceOracleGetter.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

contract AaveOracle is OwnableUpgradeable, UUPSUpgradeable, IPriceOracle {
    IPriceOracleGetter public vendorFeed;
    IERC20Upgradeable internal baseToken;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address vendorFeed_, IERC20Upgradeable baseToken_)
        external
        initializer
    {
        __Ownable_init();
        __UUPSUpgradeable_init();
        setVendorFeed(vendorFeed_);
        baseToken = baseToken_;
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner {}

    function setVendorFeed(address vendorFeed_) public onlyOwner {
        vendorFeed = IPriceOracleGetter(vendorFeed_);
    }

    function getPrice(
        IERC20Upgradeable token,
        bool,
        bool
    ) external view returns (uint256) {
        if (token == baseToken) return 10**InvestableLib.PRICE_PRECISION_DIGITS;

        // vendor returns prices in usd in 8 decimal point precision
        uint256 tokenPriceInUsd = vendorFeed.getAssetPrice(address(token));
        uint256 usdcPriceInUsd = vendorFeed.getAssetPrice(address(baseToken));

        if (tokenPriceInUsd == 0 || usdcPriceInUsd == 0)
            revert InvalidAssetPrice();

        // returns prices in usd in 6 decimal point precision
        return
            InvestableLib.convertPricePrecision(
                ((tokenPriceInUsd * Math.LONG_FIXED_DECIMAL_FACTOR) /
                    usdcPriceInUsd),
                Math.LONG_FIXED_DECIMAL_FACTOR,
                InvestableLib.PRICE_PRECISION_FACTOR
            );
    }
}
