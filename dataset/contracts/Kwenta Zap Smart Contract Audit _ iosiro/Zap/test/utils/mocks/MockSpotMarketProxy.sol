// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {ISpotMarketProxy} from "./../../../src/interfaces/ISpotMarketProxy.sol";

/// @title MockSpotMarketProxy contract for testing
/// @author JaredBorders (jaredborders@pm.me)
contract MockSpotMarketProxy is ISpotMarketProxy {
    function name(uint128 /* marketId */ )
        external
        pure
        override
        returns (string memory)
    {
        return "MockName";
    }

    function getSynth(uint128 /* marketId */ )
        external
        pure
        override
        returns (address)
    {
        return address(0x1);
    }

    function wrap(
        uint128, /* marketId */
        uint256 wrapAmount,
        uint256 /* minAmountReceived */
    ) external pure override returns (uint256 amountToMint, Data memory fees) {
        return (wrapAmount, Data(0, 0, 0, 0));
    }

    function unwrap(
        uint128, /* marketId */
        uint256 unwrapAmount,
        uint256 /* minAmountReceived */
    )
        external
        pure
        override
        returns (uint256 returnCollateralAmount, Data memory fees)
    {
        return (unwrapAmount, Data(0, 0, 0, 0));
    }

    function buy(
        uint128, /* marketId */
        uint256 usdAmount,
        uint256, /* minAmountReceived */
        address /* referrer */
    ) external pure override returns (uint256 synthAmount, Data memory fees) {
        return (usdAmount, Data(0, 0, 0, 0));
    }

    function sell(
        uint128, /* marketId */
        uint256 synthAmount,
        uint256, /* minAmountReceived */
        address /* referrer */
    )
        external
        pure
        override
        returns (uint256 usdAmountReceived, Data memory fees)
    {
        return (synthAmount, Data(0, 0, 0, 0));
    }
}
