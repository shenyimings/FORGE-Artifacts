// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "./interfaces/CloberMarketDeployer.sol";
import "./OrderBook.sol";

contract MarketDeployer is CloberMarketDeployer {
    address private immutable _factory;

    constructor(address factory_) {
        _factory = factory_;
    }

    function deploy(
        address orderToken,
        address quoteToken,
        address baseToken,
        bytes32 salt,
        uint96 quoteUnit,
        int24 makerFee,
        uint24 takerFee,
        address priceBook
    ) external returns (address market) {
        if (msg.sender != _factory) {
            revert Errors.CloberError(Errors.ACCESS);
        }
        market = address(
            new OrderBook{salt: salt}(
                orderToken,
                quoteToken,
                baseToken,
                quoteUnit,
                makerFee,
                takerFee,
                _factory,
                priceBook
            )
        );
        emit Deploy(market);
    }
}
