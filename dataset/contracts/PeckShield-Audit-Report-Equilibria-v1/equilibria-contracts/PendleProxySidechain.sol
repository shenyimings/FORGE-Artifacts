// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./PendleProxyBaseUpg.sol";

contract PendleProxySidechain is PendleProxyBaseUpg {
    function initialize() public initializer {
        __PendleProxyBaseUpg_init();
    }

    function setParams(
        address _pendleMarketFactory,
        address _booster
    ) external onlyOwner {
        _setParams(_pendleMarketFactory, _booster);
    }
}
