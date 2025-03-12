// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library SEvent {
    event SCDPDeposit(address indexed depositor, address indexed collateralAsset, uint256 amount);
    event SCDPWithdraw(address indexed withdrawer, address indexed collateralAsset, uint256 amount, uint256 feeAmount);
    event SCDPRepay(
        address indexed repayer,
        address indexed repayKreskoAsset,
        uint256 repayAmount,
        address indexed receiveKreskoAsset,
        uint256 receiveAmount
    );

    event SCDPLiquidationOccured(
        address indexed liquidator,
        address indexed repayKreskoAsset,
        uint256 repayAmount,
        address indexed seizeCollateral,
        uint256 seizeAmount
    );

    // Emitted when a swap pair is disabled / enabled.
    event PairSet(address indexed assetIn, address indexed assetOut, bool enabled);
    // Emitted when a kresko asset fee is updated.
    event FeeSet(address indexed _asset, uint256 openFee, uint256 closeFee, uint256 protocolFee);

    // Emitted when a collateral is updated.
    event SCDPCollateralUpdated(address indexed _asset, uint256 liquidationThreshold);

    // Emitted when a kresko asset is updated.
    event SCDPKrAssetUpdated(
        address indexed _asset,
        uint256 openFee,
        uint256 closeFee,
        uint256 protocolFee,
        uint256 maxDebtMinter
    );

    event Swap(address indexed who, address indexed assetIn, address indexed assetOut, uint256 amountIn, uint256 amountOut);
    event SwapFee(address indexed feeAsset, address indexed assetIn, uint256 feeAmount, uint256 protocolFeeAmount);

    event Income(address asset, uint256 amount);

    /**
     * @notice Emitted when the liquidation incentive multiplier is updated for a swappable krAsset.
     * @param symbol Asset symbol
     * @param asset The krAsset asset updated.
     * @param from Previous value.
     * @param to New value.
     */
    event SCDPLiquidationIncentiveUpdated(string indexed symbol, address indexed asset, uint256 from, uint256 to);

    /**
     * @notice Emitted when the minimum collateralization ratio is updated for the SCDP.
     * @param from Previous value.
     * @param to New value.
     */
    event SCDPMinCollateralRatioUpdated(uint256 from, uint256 to);

    /**
     * @notice Emitted when the liquidation threshold value is updated
     * @param from Previous value.
     * @param to New value.
     * @param mlr The new max liquidation ratio.
     */
    event SCDPLiquidationThresholdUpdated(uint256 from, uint256 to, uint256 mlr);

    /**
     * @notice Emitted when the max liquidation ratio is updated
     * @param from Previous value.
     * @param to New value.
     */
    event SCDPMaxLiquidationRatioUpdated(uint256 from, uint256 to);
}
