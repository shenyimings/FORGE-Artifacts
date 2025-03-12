// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.16;

// interfaces
import {IClearingHouse} from "./IClearingHouse.sol";
import {IPerpetual} from "./IPerpetual.sol";
import {IVault} from "./IVault.sol";
import {ICryptoSwap} from "./ICryptoSwap.sol";
import {IInsurance} from "./IInsurance.sol";

// libraries
import {LibPerpetual} from "../lib/LibPerpetual.sol";

interface IClearingHouseViewer {
    // to avoid stack to deep errors
    struct LpProposedAmountArgs {
        uint256 idx;
        address user;
        uint256 reductionRatio;
        uint256 iter;
        uint256[2] minVTokenAmounts;
        uint256 minAmount;
        uint256 precision;
    }

    struct TraderProposedAmountArgs {
        uint256 idx;
        address user;
        uint256 reductionRatio;
        uint256 iter;
        uint256 minAmount;
        uint256 precision;
    }

    /* ****************** */
    /*    Errors          */
    /* ****************** */

    /// @notice Emitted when the zero address is provided as a parameter in the constructor
    error ClearingHouseViewer_ZeroAddressConstructor(uint8 paramIndex);

    /// @notice Emitted when the amount of LP tokens passed is larger than the user LP token balance
    error ClearingHouseViewer_LpTokenAmountPassedLargerThanBalance();

    /// @notice Emitted when the reduction ratio given is larger than 1e18
    error ClearingHouseViewer_ReductionRatioTooLarge();

    /* ****************** */
    /*    Global Getters  */
    /* ****************** */

    function clearingHouse() external view returns (IClearingHouse);

    function perpetual(uint256 idx) external view returns (IPerpetual);

    function getExpectedVBaseAmount(uint256 idx, uint256 vQuoteAmountToSpend) external view returns (uint256);

    function getExpectedVQuoteAmount(uint256 idx, uint256 vBaseAmountToSpend) external view returns (uint256);

    function getExpectedLpTokenAmount(uint256 idx, uint256[2] calldata amounts) external view returns (uint256);

    function getExpectedVirtualTokenAmountsFromLpTokenAmount(
        uint256 idx,
        address account,
        uint256 lpTokenAmountToWithdraw
    ) external view returns (uint256[2] memory);

    function marketPrice(uint256 idx) external view returns (uint256);

    function indexPrice(uint256 idx) external view returns (int256);

    function totalLpTokenSupply(uint256 idx) external view returns (uint256);

    function getGlobalPosition(uint256 idx) external view returns (LibPerpetual.GlobalPosition memory);

    function getBaseDust(uint256 idx) external view returns (int256);

    function getMarket(uint256 idx) external view returns (ICryptoSwap);

    function insuranceFee(uint256 idx) external view returns (int256);

    function getBaseBalance(uint256 idx) external view returns (uint256);

    function getQuoteBalance(uint256 idx) external view returns (uint256);

    function getTotalLiquidityProvided(uint256 idx) external view returns (uint256);

    /* ****************** */
    /*    User Getters    */
    /* ****************** */

    function isMarginValid(address account, int256 ratio) external view returns (bool);

    function marginRatio(address account) external view returns (int256);

    function getFundingPaymentsAcrossMarkets(address account) external view returns (int256 fundingPayments);

    function getReserveValue(address account, bool isDiscounted) external view returns (int256);

    function getAllowance(address user, address receiver, uint256 tokenIdx) external view returns (uint256);

    function getBalance(address user, uint256 tokenIdx) external view returns (int256);

    function getTraderFundingPayments(uint256 idx, address account) external view returns (int256);

    function getTraderUnrealizedPnL(uint256 idx, address account) external view returns (int256);

    function getTraderPosition(uint256 idx, address account)
        external
        view
        returns (LibPerpetual.TraderPosition memory);

    function getFundingPayments(uint256 idx, address account) external view returns (int256 fundingPayments);

    function getLpFundingPayments(uint256 idx, address account) external view returns (int256);

    function getLpEstimatedPnl(uint256 idx, address account) external view returns (int256);

    function getLpTradingFees(uint256 idx, address account) external view returns (uint256);

    function getLpUnrealizedPnL(uint256 idx, address account) external view returns (int256);

    function accountLeverage(address account) external view returns (int256);

    function marketLeverage(uint256 idx, address account) external view returns (int256);

    function isTraderPositionOpen(uint256 idx, address account) external view returns (bool);

    function isLpPositionOpen(uint256 idx, address account) external view returns (bool);

    function isPositionOpen(address account) external view returns (bool);

    function getLpPositionAfterWithdrawal(uint256 idx, address account)
        external
        view
        returns (LibPerpetual.TraderPosition memory);

    function getLpPosition(uint256 idx, address account)
        external
        view
        returns (LibPerpetual.LiquidityProviderPosition memory);

    function getTraderProposedAmount(uint256 idx, address user, uint256 reductionRatio, uint256 iter, uint256 minAmount)
        external
        view
        returns (uint256 proposedAmount);

    function getLpProposedAmount(
        uint256 idx,
        address user,
        uint256 reductionRatio,
        uint256 iter,
        uint256[2] calldata minVTokenAmounts,
        uint256 minAmount
    ) external returns (uint256 proposedAmount);

    /* ******************** */
    /*    Static Helpers    */
    /* ******************** */

    function getTraderProposedAmountStruct(TraderProposedAmountArgs calldata args)
        external
        returns (uint256 proposedAmount);

    function getLpProposedAmountStruct(LpProposedAmountArgs calldata args) external returns (uint256 proposedAmount);

    function removeLiquiditySwap(
        uint256 idx,
        address user,
        uint256 liquidityAmountToRemove,
        uint256[2] calldata minVTokenAmounts,
        uint256 proposedAmount,
        LibPerpetual.Side direction,
        bool withCurveTradingFees
    ) external returns (uint256 proceeds);
}
