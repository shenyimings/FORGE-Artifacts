// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {Zap} from "../../../src/Zap.sol";

/// @title Exposed Zap contract used for testing and in the deploy script
/// @dev although it is used in the deploy script, it is
/// *not* safe and *not* meant for mainnet
/// @author JaredBorders (jaredborders@pm.me)
contract ZapExposed is Zap {
    function expose_HASHED_SUSDC_NAME() public pure returns (bytes32) {
        return _HASHED_SUSDC_NAME;
    }

    function expose_USDC() public view returns (address) {
        return address(_USDC);
    }

    function expose_SUSD() public view returns (address) {
        return address(_SUSD);
    }

    function expose_SUSDC() public view returns (address) {
        return address(_SUSDC);
    }

    function expose_SUSDC_SPOT_MARKET_ID() public view returns (uint128) {
        return _SUSDC_SPOT_MARKET_ID;
    }

    function expose_SPOT_MARKET_PROXY() public view returns (address) {
        return address(_SPOT_MARKET_PROXY);
    }

    function expose_DECIMALS_FACTOR() public view returns (uint256) {
        return _DECIMALS_FACTOR;
    }

    constructor(
        address _usdc,
        address _susd,
        address _spotMarketProxy,
        uint128 _sUSDCId
    ) Zap(_usdc, _susd, _spotMarketProxy, _sUSDCId) {}

    function expose_zapIn(uint256 _amount) public {
        _zapIn(_amount);
    }

    function expose_zapOut(uint256 _amount) public {
        _zapOut(_amount);
    }
}
