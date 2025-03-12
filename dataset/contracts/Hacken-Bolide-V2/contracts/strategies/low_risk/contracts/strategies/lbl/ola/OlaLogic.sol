// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;
pragma abicoder v2;

import "../../../LendingLogic.sol";
import "../../../interfaces/ICompound.sol";

contract OlaLogic is LendingLogic {
    function _checkMarkets(address xToken)
        internal
        view
        override
        returns (bool isUsedXToken)
    {
        (isUsedXToken, , , , , ) = IComptrollerOla(comptroller).markets(xToken);
    }

    function _claim(address[] memory xTokens) internal override {
        IDistributionOla(rainMaker).claimComp(address(this), xTokens);
    }

    function _rewardToken() internal view override returns (address) {
        return
            IDistributionOla(IComptrollerOla(comptroller).rainMaker())
                .lnIncentiveTokenAddress();
    }

    function _getUnderlyingPrice(address xToken)
        internal
        view
        override
        returns (uint256)
    {
        return
            IComptrollerOla(comptroller).getUnderlyingPriceInLen(
                IXToken(xToken).underlying()
            );
    }

    function _getUnderlying(address xToken)
        internal
        view
        override
        returns (address)
    {
        address underlying = IXToken(xToken).underlying();
        if (underlying == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
            underlying = ZERO_ADDRESS;

        return underlying;
    }

    function _getCollateralFactor(address xToken)
        internal
        view
        override
        returns (uint256 collateralFactor)
    {
        // get collateralFactor from market
        (, collateralFactor, , , , ) = IComptrollerOla(comptroller).markets(
            xToken
        );
    }

    function _accrueInterest(address xToken) internal override {
        IXToken(xToken).accrueInterest();
    }
}
