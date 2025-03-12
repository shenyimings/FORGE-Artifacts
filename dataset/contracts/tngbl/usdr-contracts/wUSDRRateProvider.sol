// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC4626Upgradeable.sol";

import "./interfaces/IRateProvider.sol";

contract WrappedUSDRRateProvider is IRateProvider {
    address public immutable USDR;
    address public immutable wUSDR;

    constructor(address wUSDR_) {
        USDR = IERC4626Upgradeable(wUSDR_).asset();
        wUSDR = wUSDR_;
    }

    /**
     * @return the value of wUSDR in terms of USDR
     */
    function getRate() external view override returns (uint256) {
        uint256 oneWUSDR = 10**IERC20MetadataUpgradeable(wUSDR).decimals();
        return IERC4626Upgradeable(wUSDR).previewRedeem(oneWUSDR);
    }
}
