// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;
pragma abicoder v2;

import "../../../StatisticsBase.sol";

contract VenusStatistics is StatisticsBase {
    /**
     * @notice get USD price by Venus Oracle for xToken
     * @param xToken xToken address
     * @param comptroller comptroller address
     * @return priceUSD USD price for xToken (decimal = 18 + (18 - decimal of underlying))
     */
    function _getUnderlyingUSDPrice(address xToken, address comptroller)
        internal
        view
        override
        returns (uint256 priceUSD)
    {
        priceUSD = IOracleVenus(IComptrollerVenus(comptroller).oracle())
            .getUnderlyingPrice(xToken);
    }

    /**
     * @notice get rewards underlying token of startegy
     * @param comptroller comptroller address
     * @return rewardsToken rewards token address
     */
    function _getRewardsToken(address comptroller)
        internal
        view
        override
        returns (address rewardsToken)
    {
        rewardsToken = IComptrollerVenus(comptroller).getXVSAddress();
    }

    /**
     * @notice get rewards underlying token price
     * @param comptroller comptroller address
     * @param rewardsToken Address of rewards token
     * @return priceUSD usd amount : (decimal = 18 + (18 - decimal of rewards token))
     */
    function _getRewardsTokenPrice(address comptroller, address rewardsToken)
        internal
        view
        override
        returns (uint256 priceUSD)
    {
        priceUSD = IOracleVenus(IComptrollerVenus(comptroller).oracle())
            .getUnderlyingPrice(
                IComptrollerVenus(comptroller).getXVSVTokenAddress()
            );
    }

    /**
     * @notice Get Ola earned
     * @param logic Logic contract address
     * @param comptroller comptroller address
     * @return venusEarned
     */
    function _getStrategyEarned(address logic, address comptroller)
        internal
        view
        override
        returns (uint256 venusEarned)
    {
        uint256 index;
        venusEarned = 0;
        address[] memory xTokenList = _getAllMarkets(comptroller);
        uint224 venusInitialIndex = IComptrollerVenus(comptroller)
            .venusInitialIndex();

        for (index = 0; index < xTokenList.length; ) {
            address xToken = xTokenList[index];
            uint256 borrowIndex = IXToken(xToken).borrowIndex();
            (uint224 supplyIndex, ) = IComptrollerVenus(comptroller)
                .venusSupplyState(xToken);
            uint256 supplierIndex = IComptrollerVenus(comptroller)
                .venusSupplierIndex(xToken, logic);
            (uint224 borrowState, ) = IComptrollerVenus(comptroller)
                .venusBorrowState(xToken);
            uint256 borrowerIndex = IComptrollerVenus(comptroller)
                .venusBorrowerIndex(xToken, logic);

            if (supplierIndex == 0 && supplyIndex > 0)
                supplierIndex = venusInitialIndex;

            venusEarned +=
                (IERC20Upgradeable(xToken).balanceOf(logic) *
                    (supplyIndex - supplierIndex)) /
                10**36;

            if (borrowerIndex > 0) {
                uint256 borrowerAmount = (IXToken(xToken).borrowBalanceStored(
                    logic
                ) * 10**18) / borrowIndex;
                venusEarned +=
                    (borrowerAmount * (borrowState - borrowerIndex)) /
                    10**36;
            }

            unchecked {
                ++index;
            }
        }

        venusEarned += IComptrollerVenus(comptroller).venusAccrued(logic);

        // Convert to USD using Venus
        venusEarned =
            (venusEarned *
                _getRewardsTokenPrice(
                    comptroller,
                    _getRewardsToken(comptroller)
                )) /
            BASE;
    }

    /**
     * @notice Check xToken is for native token
     * @param xToken Address of xToken
     * @return isXNative true : xToken is for native token
     */
    function _isXNative(address xToken)
        internal
        view
        override
        returns (bool isXNative)
    {
        if (
            keccak256(bytes(IXToken(xToken).symbol())) ==
            keccak256(bytes("vBNB"))
        ) isXNative = true;
        else isXNative = false;
    }

    /**
     * @notice get collateralFactorMantissa of startegy
     * @param comptroller compotroller address
     * @return collateralFactorMantissa collateralFactorMantissa
     */
    function _getCollateralFactorMantissa(address xToken, address comptroller)
        internal
        view
        override
        returns (uint256 collateralFactorMantissa)
    {
        (, collateralFactorMantissa, ) = IComptrollerVenus(comptroller).markets(
            xToken
        );
    }

    /**
     * @notice get rewardsSpeed
     * @param _asset Address of asset
     * @param comptroller comptroller address
     */
    function _getRewardsSpeed(address _asset, address comptroller)
        internal
        view
        override
        returns (uint256)
    {
        return IComptrollerVenus(comptroller).venusBorrowSpeeds(_asset);
    }

    /**
     * @notice get rewardsSupplySpeed
     * @param _asset Address of asset
     * @param comptroller comptroller address
     */
    function _getRewardsSupplySpeed(address _asset, address comptroller)
        internal
        view
        override
        returns (uint256)
    {
        return IComptrollerVenus(comptroller).venusSupplySpeeds(_asset);
    }
}
