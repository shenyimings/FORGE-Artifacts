// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../interfaces/IRateProvider.sol";
import "../interfaces/IFxStateChildTunnel.sol";

/**
 * @title RateProvider
 */
contract RateProvider is IRateProvider {
    IFxStateChildTunnel public fxChild;

    constructor(IFxStateChildTunnel _fxChild) {
        fxChild = _fxChild;
    }

    function getRate() external override view returns (uint256) {
        (uint256 matic, uint256 stMatic) = fxChild.getReserves();
        return stMatic * 1 ether / matic;
    }
}
