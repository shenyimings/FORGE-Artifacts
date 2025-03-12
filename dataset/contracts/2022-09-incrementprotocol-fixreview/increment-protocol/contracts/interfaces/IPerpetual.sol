// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.16;

// interfaces
import {ICryptoSwap} from "./ICryptoSwap.sol";
import {IVault} from "./IVault.sol";
import {ICryptoSwap} from "./ICryptoSwap.sol";
import {IVBase} from "./IVBase.sol";
import {IVQuote} from "./IVQuote.sol";
import {IInsurance} from "./IInsurance.sol";
import {IClearingHouse} from "./IClearingHouse.sol";
import {ICurveCryptoViews} from "./ICurveCryptoViews.sol";

// libraries
import {LibPerpetual} from "../lib/LibPerpetual.sol";

interface IPerpetual {
    struct PerpetualParams {
        uint256 riskWeight;
        uint256 maxLiquidityProvided;
        uint256 twapFrequency;
        int256 sensitivity;
        uint256 maxBlockTradeAmount;
        int256 insuranceFee;
        int256 lpDebtCoef;
        uint256 lockPeriod;
    }

    /* ****************** */
    /*     Errors         */
    /* ****************** */

    /// @notice Emitted when trading expansion operations are paused
    error Perpetual_TradingExpansionPaused();

    /// @notice Emitted when the zero address is provided as a parameter in the constructor
    error Perpetual_ZeroAddressConstructor(uint256 paramIndex);

    /// @notice Emitted when the constructor fails to give approval of a virtual token to the market
    error Perpetual_VirtualTokenApprovalConstructor(uint256 tokenIndex);

    /// @notice Emitted when the curve admin fee is invalid
    error Perpetual_InvalidAdminFee();

    /// @notice Emitted when the sender is not the clearing house
    error Perpetual_SenderNotClearingHouse();

    /// @notice Emitted when the sender is not the clearing house owner
    error Perpetual_SenderNotClearingHouseOwner();

    /// @notice Emitted when the user attempts to reduce their position using extendPosition
    error Perpetual_AttemptReducePosition();

    /// @notice Emitted when the user attempts to reverse their position using changePosition
    error Perpetual_AttemptReversePosition();

    /// @notice Emitted when the price impact of a position is too high
    error Perpetual_ExcessiveBlockTradeAmount();

    /// @notice Emitted when the user does not have an open position
    error Perpetual_NoOpenPosition();

    /// @notice Emitted when the user attempts to withdraw more liquidity than they have deposited
    error Perpetual_LPWithdrawExceedsBalance();

    /// @notice Emitted when the proposed twap frequency is insufficient/excessive
    error Perpetual_TwapFrequencyInvalid(uint256 twapFrequency);

    /// @notice Emitted when the proposed funding rate sensitivity is insufficient/excessive
    error Perpetual_SensitivityInvalid(int256 sensitivity);

    /// @notice Emitted when the proposed maximum block trade amount is insufficient
    error Perpetual_MaxBlockAmountInvalid(uint256 maxBlockTradeAmount);

    /// @notice Emitted when the proposed insurance fee is insufficient/excessive
    error Perpetual_InsuranceFeeInvalid(int256 fee);

    /// @notice Emitted when the proposed lp debt coefficient is insufficient/excessive
    error Perpetual_LpDebtCoefInvalid(int256 lpDebtCoef);

    /// @notice Emitted when the proposed lp lock period is insufficient/excessive
    error Perpetual_LockPeriodInvalid(uint256 lockPeriod);

    /// @notice Emitted when the proposed market risk weight is insufficient/excessive
    error Perpetual_RiskWeightInvalid(uint256 riskWeight);

    /// @notice Emitted when a token balance of the market is lte 1
    error Perpetual_MarketBalanceTooLow();

    /// @notice Emitted when the liquidity provider has an open position
    error Perpetual_LPOpenPosition();

    /// @notice Emitted when the max tvl is reached
    error Perpetual_MaxLiquidityProvided();

    /// @notice Emitted when the position exceeds the max position size
    error Perpetual_MaxPositionSize();

    /// @notice Emitted when the user attempts provide liquidity with skewed ratios
    error Perpetual_LpAmountDeviation();

    /// @notice Emitted when the user attempts remove liquidity too early
    error Perpetual_LockPeriodNotReached(uint256 withdrawTime);

    /// @notice Emitted when the user attempts to open a too large short position
    error Perpetual_TooMuchExposure();

    /* ****************** */
    /*     Events         */
    /* ****************** */

    /// @notice Emitted when an admin pauses or unpause trading expansion operations
    /// @param admin Address of the admin who triggered this operation
    /// @param toPause To pause (true) or unpause (false) trading expansion operations
    event TradingExpansionPauseToggled(address admin, bool toPause);

    /// @notice Emitted when TWAP is updated
    /// @param newOracleTwap Latest oracle Time-weighted-average-price
    /// @param newMarketTwap Latest market Time-weighted-average-price
    event TwapUpdated(int256 newOracleTwap, int256 newMarketTwap);

    /// @notice Emitted when funding rate is updated
    /// @param cumulativeFundingRate Cumulative sum of all funding rate updates
    /// @param cumulativeFundingPerLpToken Cumulative sum of all funding per lp token updates
    /// @param fundingRate Latest fundingRate update
    event FundingRateUpdated(int256 cumulativeFundingRate, int256 cumulativeFundingPerLpToken, int256 fundingRate);

    /// @notice Emitted when swap with cryptoswap pool fails
    /// @param errorMessage Return error message
    event Log(string errorMessage);

    /// @notice Emitted when (base) dust is generated
    /// @param vBaseAmount Amount of dust
    event DustGenerated(int256 vBaseAmount);

    /// @notice Emitted when parameters are updated
    event PerpetualParametersChanged(
        uint256 newRiskWeight,
        uint256 newMaxLiquidityProvided,
        uint256 newTwapFrequency,
        int256 newSensitivity,
        uint256 newMaxBlockTradeAmount,
        int256 newInsuranceFee,
        int256 newLpDebtCoef,
        uint256 lockPeriod
    );

    /// @notice Emitted when funding payments are exchanged for a trader / lp
    event FundingPaid(
        address indexed account,
        int256 amount,
        int256 globalCumulativeFundingRate,
        int256 userCumulativeFundingRate,
        bool isTrader
    );

    /* ****************** */
    /*     Viewer         */
    /* ****************** */

    function isTradingExpansionAllowed() external view returns (bool);

    function market() external view returns (ICryptoSwap);

    function vBase() external view returns (IVBase);

    function vQuote() external view returns (IVQuote);

    function clearingHouse() external view returns (IClearingHouse);

    function curveCryptoViews() external view returns (ICurveCryptoViews);

    function maxLiquidityProvided() external view returns (uint256);

    function oracleCumulativeAmount() external view returns (int256);

    function oracleCumulativeAmountAtBeginningOfPeriod() external view returns (int256);

    function marketCumulativeAmount() external view returns (int256);

    function marketCumulativeAmountAtBeginningOfPeriod() external view returns (int256);

    function riskWeight() external view returns (uint256);

    function twapFrequency() external view returns (uint256);

    function sensitivity() external view returns (int256);

    function maxBlockTradeAmount() external view returns (uint256);

    function maxPosition() external view returns (uint256);

    function insuranceFee() external view returns (int256);

    function lpDebtCoef() external view returns (int256);

    function lockPeriod() external view returns (uint256);

    function oracleTwap() external view returns (int128);

    function marketTwap() external view returns (int128);

    function getTraderPosition(address account) external view returns (LibPerpetual.TraderPosition memory);

    function getLpPositionAfterWithdrawal(address account) external view returns (LibPerpetual.TraderPosition memory);

    function getLpLiquidity(address account) external view returns (uint256);

    function getLpPosition(address account) external view returns (LibPerpetual.LiquidityProviderPosition memory);

    function getGlobalPosition() external view returns (LibPerpetual.GlobalPosition memory);

    function getTraderUnrealizedPnL(address account) external view returns (int256);

    function getLpUnrealizedPnL(address account) external view returns (int256);

    function getLpTradingFees(address account) external view returns (uint256);

    function marketPrice() external view returns (uint256);

    function indexPrice() external view returns (int256);

    function getTotalLiquidityProvided() external view returns (uint256);

    function getPendingPnL(address account) external view returns (int256 pnL);

    function getUserDebt(address account) external view returns (int256 debt);

    function isTraderPositionOpen(address account) external view returns (bool);

    function isLpPositionOpen(address account) external view returns (bool);

    function getLpOpenNotional(address account) external view returns (int256);

    /* ************* */
    /*    Helpers    */
    /* ************* */

    function removeLiquiditySwap(
        address account,
        uint256 liquidityAmountToRemove,
        uint256[2] calldata minVTokenAmounts,
        bytes memory func
    ) external;

    /* ****************** */
    /*  State modifying   */
    /* ****************** */

    function changePosition(
        address account,
        uint256 amount,
        uint256 minAmount,
        LibPerpetual.Side direction,
        bool isLiquidation
    )
        external
        returns (
            int256 quoteProceeds,
            int256 baseProceeds,
            int256 profit,
            int256 tradingFeesPayed,
            bool isPositionIncreased,
            bool isPositionClosed
        );

    function provideLiquidity(address account, uint256[2] calldata amounts, uint256 minLpAmount)
        external
        returns (int256 tradingFees);

    function removeLiquidity(
        address account,
        uint256 liquidityAmountToRemove,
        uint256[2] calldata minVTokenAmounts,
        uint256 proposedAmount,
        uint256 minAmount,
        bool isLiquidation
    )
        external
        returns (
            int256 profit,
            int256 tradingFeesPayed,
            uint256 reductionRatio,
            int256 quoteProceeds,
            bool isPositionClosed
        );

    function settleTraderFunding(address account) external returns (int256 fundingPayments);

    function settleLpFunding(address account) external returns (int256 fundingPayments);

    function toggleTradingExpansionPause(bool toPause) external;

    function pause() external;

    function unpause() external;

    function setParameters(PerpetualParams memory params) external;

    function updateGlobalState() external;
}
