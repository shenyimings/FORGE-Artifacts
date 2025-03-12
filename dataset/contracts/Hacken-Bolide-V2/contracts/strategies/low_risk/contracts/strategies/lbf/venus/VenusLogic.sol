// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;
pragma abicoder v2;

import "../../../LendingLogic.sol";
import "../../../interfaces/ICompound.sol";
import "../../../interfaces/ISwap.sol";
import "../../../interfaces/ILogicContract.sol";

contract VenusLogic is LendingLogic {
    /*** Override function ***/

    function _checkMarkets(address xToken)
        internal
        view
        override
        returns (bool isUsedXToken)
    {
        (isUsedXToken, , ) = IComptrollerVenus(comptroller).markets(xToken);
    }

    function _claim(address[] memory xTokens) internal override {
        IDistributionVenus(comptroller).claimVenus(address(this), xTokens);
    }

    function _rewardToken() internal view override returns (address) {
        return IComptrollerVenus(comptroller).getXVSAddress();
    }

    function _getUnderlyingPrice(address xToken)
        internal
        view
        override
        returns (uint256)
    {
        return
            IOracleVenus(IComptrollerVenus(comptroller).oracle())
                .getUnderlyingPrice(xToken);
    }

    function _getUnderlying(address xToken)
        internal
        view
        override
        returns (address)
    {
        address underlying;
        if (
            xToken == 0xA07c5b74C9B40447a954e1466938b865b6BBea36 ||
            xToken == 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5
        ) {
            underlying = ZERO_ADDRESS;
        } else {
            underlying = IXToken(xToken).underlying();
        }

        return underlying;
    }

    function _getCollateralFactor(address xToken)
        internal
        view
        override
        returns (uint256 collateralFactor)
    {
        // get collateralFactor from market
        (, collateralFactor, ) = IComptrollerVenus(comptroller).markets(xToken);
    }

    function _accrueInterest(address xToken) internal override {
        IXToken(xToken).accrueInterest();
    }
}
