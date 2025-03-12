// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

interface IUniswapV2StyleStrategy {

    /**
     *  @dev View function that returns the router that is used by the strategy.
     */
    function ROUTER() external view returns (address router_);

    /**
     *  @dev   Function that calls `liquidatePortion` in the liquidator, flash-borrowing funds to swap.
     *  @param flashLender_        Address that will flash loan `collateralBorrowed_` of `collateralAsset`
     *  @param collateralBorrowed_ Amount of `collateralAsset_` to be swapped.
     *  @param maxReturnFunds_     Max amount of `fundsAsset` that can be returned to the liquidator contract.
     *  @param minFundsProfit_     Min profit in funds.
     *  @param collateralAsset_    Asset that is flash-borrowed.
     *  @param middleAsset_        Optional middle asset to add to `path` of the AMM.
     *  @param fundsAsset_         Asset to be swapped to.
     *  @param destination_        Address that remaining funds and collateral are sent to.
     */
    function flashBorrowLiquidation(
        address flashLender_,
        uint256 collateralBorrowed_,
        uint256 maxReturnFunds_,
        uint256 minFundsProfit_,
        address collateralAsset_,
        address middleAsset_,
        address fundsAsset_,
        address destination_
    ) external;

    /**
     *  @dev   Function that performs a `swapExactTokensForTokens` swap on a UniswapV2-style AMM, sending the remaining funds
     *         from the flash loan to the specified `profitDestination`.
     *  @param collateralBorrowed_ Amount of `collateralAsset_` to be swapped.
     *  @param minFundsOut_        Minimum amount of `fundsAsset_` to be returned from the swap.
     *  @param collateralAsset_    Asset that is swapped from.
     *  @param middleAsset_        Optional middle asset to add to `path` of the AMM.
     *  @param fundsAsset_         Asset to be swapped to.
     */
    function swap(
        uint256 collateralBorrowed_,
        uint256 minFundsOut_,
        address collateralAsset_,
        address middleAsset_,
        address fundsAsset_
    ) external;

}
