// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./IAmmDataProvider.sol";
import "./IMinterAmm.sol";
import "../token/IERC20Lib.sol";
import "../series/ISeriesController.sol";
import "../series/IPriceOracle.sol";
import "../series/SeriesLibrary.sol";
import "../libraries/Math.sol";
import "./IBlackScholes.sol";
import "../configuration/IAddressesProvider.sol";
import "./IWTokenVault.sol";

contract AmmDataProvider is IAmmDataProvider {
    ISeriesController public seriesController;
    IERC1155 public erc1155Controller;
    IAddressesProvider public addressesProvider;

    event AmmDataProviderCreated(
        ISeriesController seriesController,
        IERC1155 erc1155Controller,
        IAddressesProvider addressesProvider
    );

    constructor(
        ISeriesController _seriesController,
        IERC1155 _erc1155Controller,
        IAddressesProvider _addressProvider
    ) {
        require(
            address(_addressProvider) != address(0x0),
            "AmmDataProvider: _addressProvider cannot be the 0x0 address"
        );

        require(
            address(_seriesController) != address(0x0),
            "AmmDataProvider: _seriesController cannot be the 0x0 address"
        );
        require(
            address(_erc1155Controller) != address(0x0),
            "AmmDataProvider: _erc1155Controller cannot be the 0x0 address"
        );

        seriesController = _seriesController;
        erc1155Controller = _erc1155Controller;
        addressesProvider = _addressProvider;

        emit AmmDataProviderCreated(
            _seriesController,
            _erc1155Controller,
            _addressProvider
        );
    }

    /// This function determines reserves of a bonding curve for a specific series.
    /// Given price of bToken we determine what is the largest pool we can create such that
    /// the ratio of its reserves satisfy the given bToken price: Rb / Rw = (1 - Pb) / Pb
    function getVirtualReserves(
        uint64 seriesId,
        address ammAddress,
        uint256 collateralTokenBalance,
        uint256 bTokenPrice
    ) public view override returns (uint256, uint256) {
        // Get residual balances
        uint256 bTokenBalance = 0; // no bTokens are allowed in the pool
        uint256 wTokenBalance = erc1155Controller.balanceOf(
            ammAddress,
            SeriesLibrary.wTokenIndex(seriesId)
        );

        ISeriesController.Series memory series = seriesController.series(
            seriesId
        );

        // For put convert token balances into collateral locked in them
        uint256 lockedUnderlyingValue = 1e18;
        if (series.isPutOption) {
            wTokenBalance = seriesController.getCollateralPerOptionToken(
                seriesId,
                wTokenBalance
            );
            // TODO: this logic causes the underlying price to be fetched twice from the oracle. Can be optimized.
            lockedUnderlyingValue =
                (lockedUnderlyingValue * series.strikePrice) /
                IPriceOracle(addressesProvider.getPriceOracle())
                    .getCurrentPrice(
                        seriesController.underlyingToken(seriesId),
                        seriesController.priceToken(seriesId)
                    );
        }

        // Max amount of tokens we can get by adding current balance plus what can be minted from collateral
        uint256 bTokenBalanceMax = bTokenBalance + collateralTokenBalance;
        uint256 wTokenBalanceMax = wTokenBalance + collateralTokenBalance;

        uint256 wTokenPrice = lockedUnderlyingValue - bTokenPrice;

        // Balance on higher reserve side is the sum of what can be minted (collateralTokenBalance)
        // plus existing balance of the token
        uint256 bTokenVirtualBalance;
        uint256 wTokenVirtualBalance;

        if (bTokenPrice <= wTokenPrice) {
            // Rb >= Rw, Pb <= Pw
            bTokenVirtualBalance = bTokenBalanceMax;
            wTokenVirtualBalance =
                (bTokenVirtualBalance * bTokenPrice) /
                wTokenPrice;

            // Sanity check that we don't exceed actual physical balances
            // In case this happens, adjust virtual balances to not exceed maximum
            // available reserves while still preserving correct price
            if (wTokenVirtualBalance > wTokenBalanceMax) {
                wTokenVirtualBalance = wTokenBalanceMax;
                bTokenVirtualBalance =
                    (wTokenVirtualBalance * wTokenPrice) /
                    bTokenPrice;
            }
        } else {
            // if Rb < Rw, Pb > Pw
            wTokenVirtualBalance = wTokenBalanceMax;
            bTokenVirtualBalance =
                (wTokenVirtualBalance * wTokenPrice) /
                bTokenPrice;

            // Sanity check
            if (bTokenVirtualBalance > bTokenBalanceMax) {
                bTokenVirtualBalance = bTokenBalanceMax;
                wTokenVirtualBalance =
                    (bTokenVirtualBalance * bTokenPrice) /
                    wTokenPrice;
            }
        }

        return (bTokenVirtualBalance, wTokenVirtualBalance);
    }

    /// @notice Calculate premium (i.e. the option price) to buy bTokenAmount bTokens for the
    /// given Series
    /// @notice The premium depends on the amount of collateral token in the pool, the reserves
    /// of bToken and wToken in the pool, and the current series price of the underlying
    /// @param seriesId The ID of the Series to buy bToken on
    /// @param ammAddress The AMM whose reserves we'll use
    /// @param bTokenAmount The amount of bToken to buy, which uses the same decimals as
    /// the underlying ERC20 token
    /// @return The amount of collateral token necessary to buy bTokenAmount worth of bTokens
    function bTokenGetCollateralIn(
        uint64 seriesId,
        address ammAddress,
        uint256 bTokenAmount,
        uint256 collateralTokenBalance,
        uint256 bTokenPrice
    ) public view override returns (uint256) {
        // Shortcut for 0 amount
        if (bTokenAmount == 0) return 0;

        bTokenAmount = seriesController.getCollateralPerOptionToken(
            seriesId,
            bTokenAmount
        );

        // For both puts and calls balances are expressed in collateral token
        (uint256 bTokenBalance, uint256 wTokenBalance) = getVirtualReserves(
            seriesId,
            ammAddress,
            collateralTokenBalance,
            bTokenPrice
        );

        uint256 sumBalance = bTokenBalance + wTokenBalance;
        uint256 toSquare;
        if (sumBalance > bTokenAmount) {
            toSquare = sumBalance - bTokenAmount;
        } else {
            toSquare = bTokenAmount - sumBalance;
        }

        // return the collateral amount
        return
            (((Math.sqrt((toSquare**2) + (4 * bTokenAmount * wTokenBalance)) +
                bTokenAmount) - bTokenBalance) - wTokenBalance) / 2;
    }

    /// @dev Calculates the amount of collateral token a seller will receive for selling their option tokens,
    /// taking into account the AMM's level of reserves
    /// @param seriesId The ID of the Series
    /// @param ammAddress The AMM whose reserves we'll use
    /// @param optionTokenAmount The amount of option tokens (either bToken or wToken) to be sold
    /// @param collateralTokenBalance The amount of collateral token held by this AMM
    /// @param bTokenPrice The price of 1 (human readable unit) bToken for this series, in units of collateral token
    /// @param isBToken true if the option token is bToken, and false if it's wToken. Depending on which
    /// of the two it is, the equation for calculating the final collateral token is a little different
    /// @return The amount of collateral token the seller will receive in exchange for their option token
    function optionTokenGetCollateralOut(
        uint64 seriesId,
        address ammAddress,
        uint256 optionTokenAmount,
        uint256 collateralTokenBalance,
        uint256 bTokenPrice,
        bool isBToken
    ) public view override returns (uint256) {
        // Shortcut for 0 amount
        if (optionTokenAmount == 0) return 0;

        optionTokenAmount = seriesController.getCollateralPerOptionToken(
            seriesId,
            optionTokenAmount
        );

        (uint256 bTokenBalance, uint256 wTokenBalance) = getVirtualReserves(
            seriesId,
            ammAddress,
            collateralTokenBalance,
            bTokenPrice
        );

        uint256 balanceFactor;
        if (isBToken) {
            balanceFactor = wTokenBalance;
        } else {
            balanceFactor = bTokenBalance;
        }
        uint256 toSquare = optionTokenAmount + wTokenBalance + bTokenBalance;
        uint256 collateralAmount = (toSquare -
            Math.sqrt(
                (toSquare**2) - (4 * optionTokenAmount * balanceFactor)
            )) / 2;

        return collateralAmount;
    }

    /// @dev Calculate the collateral amount receivable by redeeming the given
    /// Series' bTokens and wToken
    /// @param seriesId The index of the Series
    /// @param wTokenBalance The wToken balance for this Series owned by this AMM
    /// @return The total amount of collateral receivable by redeeming the Series' option tokens
    function getRedeemableCollateral(uint64 seriesId, uint256 wTokenBalance)
        public
        view
        override
        returns (uint256)
    {
        uint256 unredeemedCollateral = 0;
        if (wTokenBalance > 0) {
            (uint256 unclaimedCollateral, ) = seriesController.getClaimAmount(
                seriesId,
                wTokenBalance
            );
            unredeemedCollateral += unclaimedCollateral;
        }

        return unredeemedCollateral;
    }

    /// @notice Calculate the amount of collateral the AMM would received if all of the
    /// expired Series' wTokens and bTokens were to be redeemed for their underlying collateral
    /// value
    /// @return The amount of collateral token the AMM would receive if it were to exercise/claim
    /// all expired bTokens/wTokens
    function getCollateralValueOfAllExpiredOptionTokens(
        uint64[] memory openSeries,
        address ammAddress
    ) public view override returns (uint256) {
        IWTokenVault wTokenVault = IWTokenVault(
            addressesProvider.getWTokenVault()
        );

        uint256 unredeemedCollateral = 0;

        for (uint256 i = 0; i < openSeries.length; i++) {
            uint64 seriesId = openSeries[i];

            if (
                seriesController.state(seriesId) ==
                ISeriesController.SeriesState.EXPIRED
            ) {
                uint256 wTokenIndex = SeriesLibrary.wTokenIndex(seriesId);

                // Get wToken balance excluding locked tokens
                uint256 wTokenBalance = erc1155Controller.balanceOf(
                    ammAddress,
                    wTokenIndex
                ) - wTokenVault.getWTokenBalance(ammAddress, seriesId);

                // calculate the amount of collateral The AMM would receive by
                // redeeming this Series' bTokens and wTokens
                unredeemedCollateral += getRedeemableCollateral(
                    seriesId,
                    wTokenBalance
                );
            }
        }

        return unredeemedCollateral;
    }

    /// @notice Calculate sale value of pro-rata LP b/wTokens in units of collateral token
    function getOptionTokensSaleValue(
        uint256 lpTokenAmount,
        uint256 lpTokenSupply,
        uint64[] memory openSeries,
        address ammAddress,
        uint256 collateralTokenBalance,
        uint256 impliedVolatility
    ) public view override returns (uint256) {
        if (lpTokenAmount == 0) return 0;
        if (lpTokenSupply == 0) return 0;

        IWTokenVault wTokenVault = IWTokenVault(
            addressesProvider.getWTokenVault()
        );

        // Calculate the amount of collateral receivable by redeeming all the expired option tokens
        uint256 expiredOptionTokenCollateral = getCollateralValueOfAllExpiredOptionTokens(
                openSeries,
                ammAddress
            );

        // Calculate amount of collateral left in the pool to sell tokens to
        uint256 totalCollateral = expiredOptionTokenCollateral +
            collateralTokenBalance;

        // Subtract pro-rata collateral amount to be withdrawn
        totalCollateral =
            (totalCollateral * (lpTokenSupply - lpTokenAmount)) /
            lpTokenSupply;

        // Given remaining collateral calculate how much all tokens can be sold for
        uint256 collateralLeft = totalCollateral;
        for (uint256 i = 0; i < openSeries.length; i++) {
            uint64 seriesId = openSeries[i];

            if (
                seriesController.state(seriesId) ==
                ISeriesController.SeriesState.OPEN
            ) {
                // Get wToken balance excluding locked tokens
                uint256 wTokenToSell = ((erc1155Controller.balanceOf(
                    ammAddress,
                    SeriesLibrary.wTokenIndex(seriesId)
                ) - wTokenVault.getWTokenBalance(ammAddress, seriesId)) *
                    lpTokenAmount) / lpTokenSupply;

                uint256 bTokenPrice = getPriceForSeries(
                    seriesId,
                    impliedVolatility
                );

                uint256 collateralAmountW = optionTokenGetCollateralOut(
                    seriesId,
                    ammAddress,
                    wTokenToSell,
                    collateralLeft,
                    bTokenPrice,
                    false
                );
                collateralLeft -= collateralAmountW;
            }
        }

        return totalCollateral - collateralLeft;
    }

    /// @notice Get the bToken price for given Series, in units of the collateral token
    /// and normalized to 1e18. We use a normalization factor of 1e18 because we need
    /// to represent fractional values, yet Solidity does not support floating point numerics.
    /// @notice For example, if this is a WBTC Call option pool and so
    /// the collateral token is WBTC, then a return value of 0.5e18 means X units of bToken
    /// have a price of 0.5 * X units of WBTC. Another example; if this were a WBTC Put
    /// option pool, and so the collateral token is USDC, then a return value of 0.1e18 means
    /// X units of bToken have a price of 0.1 * X * strikePrice units of USDC.
    /// @notice This value will always be between 0 and 1e18, so you can think of it as
    /// representing the price as a fraction of 1 collateral token unit
    /// @dev This function assumes that it will only be called on an OPEN Series; if the
    /// Series is EXPIRED, then the expirationDate - block.timestamp will throw an underflow error
    function getPriceForSeries(uint64 seriesId, uint256 annualVolatility)
        public
        view
        override
        returns (uint256)
    {
        ISeriesController.Series memory series = seriesController.series(
            seriesId
        );
        uint256 underlyingPrice = IPriceOracle(
            addressesProvider.getPriceOracle()
        ).getCurrentPrice(
                seriesController.underlyingToken(seriesId),
                seriesController.priceToken(seriesId)
            );

        return
            getPriceForSeriesInternal(
                series,
                underlyingPrice,
                annualVolatility
            );
    }

    function getPriceForSeriesInternal(
        ISeriesController.Series memory series,
        uint256 underlyingPrice,
        uint256 annualVolatility
    ) private view returns (uint256) {
        // Note! This function assumes the underlyingPrice is a valid series
        // price in units of underlyingToken/priceToken. If the onchain price
        // oracle's value were to drift from the true series price, then the bToken price
        // we calculate here would also drift, and will result in undefined
        // behavior for any functions which call getPriceForSeriesInternal
        (uint256 call, uint256 put) = IBlackScholes(
            addressesProvider.getBlackScholes()
        ).optionPrices(
                series.expirationDate - block.timestamp,
                annualVolatility,
                underlyingPrice,
                series.strikePrice,
                0
            );
        if (series.isPutOption == true) {
            return ((put * 1e18) / underlyingPrice);
        } else {
            return ((call * 1e18) / underlyingPrice);
        }
    }

    /// Get value of all assets in the pool in units of this AMM's collateralToken.
    /// Can specify whether to include the value of expired unclaimed tokens
    function getTotalPoolValue(
        bool includeUnclaimed,
        uint64[] memory openSeries,
        uint256 collateralBalance,
        address ammAddress,
        uint256 impliedVolatility
    ) public view override returns (uint256) {
        // Note! This function assumes the underlyingPrice is a valid series
        // price in units of underlyingToken/priceToken. If the onchain price
        // oracle's value were to drift from the true series price, then the bToken price
        // we calculate here would also drift, and will result in undefined
        // behavior for any functions which call getTotalPoolValue
        uint256 underlyingPrice;
        if (openSeries.length > 0) {
            // we assume the openSeries are all from the same AMM, and thus all its Series
            // use the same underlying and price tokens, so we can arbitrarily choose the first
            // when fetching the necessary token addresses
            underlyingPrice = IPriceOracle(addressesProvider.getPriceOracle())
                .getCurrentPrice(
                    seriesController.underlyingToken(openSeries[0]),
                    seriesController.priceToken(openSeries[0])
                );
        }

        IWTokenVault wTokenVault = IWTokenVault(
            addressesProvider.getWTokenVault()
        );

        // First, determine the value of all residual b/wTokens
        uint256 activeTokensValue = 0;
        uint256 expiredTokensValue = 0;
        for (uint256 i = 0; i < openSeries.length; i++) {
            uint64 seriesId = openSeries[i];
            ISeriesController.Series memory series = seriesController.series(
                seriesId
            );

            // Get wToken balance excluding locked tokens
            uint256 wTokenBalance = erc1155Controller.balanceOf(
                ammAddress,
                SeriesLibrary.wTokenIndex(seriesId)
            ) - wTokenVault.getWTokenBalance(ammAddress, seriesId);

            if (
                seriesController.state(seriesId) ==
                ISeriesController.SeriesState.OPEN
            ) {
                // value all active bTokens and wTokens at current prices
                uint256 bPrice = getPriceForSeriesInternal(
                    series,
                    underlyingPrice,
                    impliedVolatility
                );
                // wPrice = 1 - bPrice
                uint256 lockedUnderlyingValue = 1e18;
                if (series.isPutOption) {
                    lockedUnderlyingValue =
                        (lockedUnderlyingValue * series.strikePrice) /
                        underlyingPrice;
                }

                // uint256 wPrice = lockedUnderlyingValue - bPrice;
                uint256 tokensValueCollateral = seriesController
                    .getCollateralPerUnderlying(
                        seriesId,
                        wTokenBalance * (lockedUnderlyingValue - bPrice),
                        underlyingPrice
                    ) / 1e18;

                activeTokensValue += tokensValueCollateral;
            } else if (
                includeUnclaimed &&
                seriesController.state(seriesId) ==
                ISeriesController.SeriesState.EXPIRED
            ) {
                // Get collateral token locked in the series
                expiredTokensValue += getRedeemableCollateral(
                    seriesId,
                    wTokenBalance
                );
            }
        }

        // Add value of OPEN Series, EXPIRED Series, and collateral token
        return activeTokensValue + expiredTokensValue + collateralBalance;
    }

    // View functions for front-end //

    /// Get value of all assets in the pool in units of this AMM's collateralToken.
    /// Can specify whether to include the value of expired unclaimed tokens
    function getTotalPoolValueView(address ammAddress, bool includeUnclaimed)
        external
        view
        override
        returns (uint256)
    {
        IMinterAmm amm = IMinterAmm(ammAddress);

        return
            getTotalPoolValue(
                includeUnclaimed,
                amm.getAllSeries(),
                amm.collateralBalance(),
                ammAddress,
                amm.getBaselineVolatility()
            );
    }

    /// @notice Calculate premium (i.e. the option price) to buy bTokenAmount bTokens for the
    /// given Series
    /// @notice The premium depends on the amount of collateral token in the pool, the reserves
    /// of bToken and wToken in the pool, and the current series price of the underlying
    /// @param seriesId The ID of the Series to buy bToken on
    /// @param bTokenAmount The amount of bToken to buy, which uses the same decimals as
    /// the underlying ERC20 token
    /// @return The amount of collateral token necessary to buy bTokenAmount worth of bTokens
    /// NOTE: This returns the collateral + fee amount
    function bTokenGetCollateralInView(
        address ammAddress,
        uint64 seriesId,
        uint256 bTokenAmount
    ) external view override returns (uint256) {
        IMinterAmm amm = IMinterAmm(ammAddress);

        uint256 collateralWithoutFees = bTokenGetCollateralIn(
            seriesId,
            ammAddress,
            bTokenAmount,
            amm.collateralBalance(),
            getPriceForSeries(seriesId, amm.getVolatility(seriesId))
        );
        uint256 tradeFee = amm.calculateFees(
            bTokenAmount,
            collateralWithoutFees
        );
        return collateralWithoutFees + tradeFee;
    }

    /// @notice Calculate the amount of collateral token the user will receive for selling
    /// bTokenAmount worth of bToken to the pool. This is the option's sell price
    /// @notice The sell price depends on the amount of collateral token in the pool, the reserves
    /// of bToken and wToken in the pool, and the current series price of the underlying
    /// @param seriesId The ID of the Series to sell bToken on
    /// @param bTokenAmount The amount of bToken to sell, which uses the same decimals as
    /// the underlying ERC20 token
    /// @return The amount of collateral token the user will receive upon selling bTokenAmount of
    /// bTokens to the pool minus any trade fees
    /// NOTE: This returns the collateral - fee amount
    function bTokenGetCollateralOutView(
        address ammAddress,
        uint64 seriesId,
        uint256 bTokenAmount
    ) external view override returns (uint256) {
        IMinterAmm amm = IMinterAmm(ammAddress);

        uint256 collateralWithoutFees = optionTokenGetCollateralOut(
            seriesId,
            ammAddress,
            bTokenAmount,
            amm.collateralBalance(),
            getPriceForSeries(seriesId, amm.getVolatility(seriesId)),
            true
        );

        uint256 tradeFee = amm.calculateFees(
            bTokenAmount,
            collateralWithoutFees
        );
        return collateralWithoutFees - tradeFee;
    }

    /// @notice Calculate amount of collateral in exchange for selling wTokens
    function wTokenGetCollateralOutView(
        address ammAddress,
        uint64 seriesId,
        uint256 wTokenAmount
    ) external view override returns (uint256) {
        IMinterAmm amm = IMinterAmm(ammAddress);

        return
            optionTokenGetCollateralOut(
                seriesId,
                ammAddress,
                wTokenAmount,
                amm.collateralBalance(),
                getPriceForSeries(seriesId, amm.getVolatility(seriesId)),
                false
            );
    }

    /// @notice Calculate the amount of collateral the AMM would received if all of the
    /// expired Series' wTokens and bTokens were to be redeemed for their underlying collateral
    /// value
    /// @return The amount of collateral token the AMM would receive if it were to exercise/claim
    /// all expired bTokens/wTokens
    function getCollateralValueOfAllExpiredOptionTokensView(address ammAddress)
        external
        view
        override
        returns (uint256)
    {
        IMinterAmm amm = IMinterAmm(ammAddress);

        return
            getCollateralValueOfAllExpiredOptionTokens(
                amm.getAllSeries(),
                ammAddress
            );
    }

    /// @notice Calculate sale value of pro-rata LP wTokens in units of collateral token
    function getOptionTokensSaleValueView(
        address ammAddress,
        uint256 lpTokenAmount
    ) external view override returns (uint256) {
        IMinterAmm amm = IMinterAmm(ammAddress);

        uint256 lpTokenSupply = IERC20Lib(address(amm.lpToken())).totalSupply();

        return
            getOptionTokensSaleValue(
                lpTokenAmount,
                lpTokenSupply,
                amm.getAllSeries(),
                ammAddress,
                amm.collateralBalance(),
                amm.getBaselineVolatility()
            );
    }
}
