// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.16;

// interfaces
import {IClearingHouse} from "./IClearingHouse.sol";
import {IPerpetual} from "./IPerpetual.sol";
import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IVault} from "./IVault.sol";
import {IInsurance} from "./IInsurance.sol";
import {ICryptoSwap} from "./ICryptoSwap.sol";
import {IRewardContract} from "./IRewardContract.sol";

// libraries
import {LibPerpetual} from "../lib/LibPerpetual.sol";

interface IClearingHouse {
    struct ClearingHouseParams {
        int256 minMargin;
        int256 minMarginAtCreation;
        uint256 minPositiveOpenNotional;
        uint256 liquidationReward;
        uint256 insuranceRatio;
        uint256 liquidationRewardInsuranceShare;
        uint256 liquidationDiscount;
        uint256 nonUACollSeizureDiscount;
        int256 uaDebtSeizureThreshold;
    }

    /* ****************** */
    /*     Errors         */
    /* ****************** */

    /// @notice Emitted when the zero address is provided
    error ClearingHouse_ZeroAddress();

    /// @notice Emitted when passing the address of a perpetual market which has already been added
    error ClearingHouse_PerpetualMarketAlreadyAssigned();

    /// @notice Emitted when attempting to remove a perpetual market which does not exist
    error ClearingHouse_MarketDoesNotExist();

    /// @notice Emitted when there is not enough margin to withdraw the requested amount
    error ClearingHouse_WithdrawInsufficientMargin();

    /// @notice Emitted when the position is not reduced entirely using closePositionWithdrawCollateral
    error ClearingHouse_ClosePositionStillOpen();

    /// @notice Emitted when the liquidatee does not have an open position
    error ClearingHouse_LiquidateInvalidPosition();

    /// @notice Emitted when the margin of the liquidatee's position is still valid
    error ClearingHouse_LiquidateValidMargin();

    /// @notice Emitted when the attempted liquidation does not close the full position
    error ClearingHouse_LiquidateInsufficientProposedAmount();

    /// @notice Emitted when a user attempts to provide liquidity with amount equal to 0
    error ClearingHouse_ProvideLiquidityZeroAmount();

    /// @notice Emitted when a user attempts to provide liquidity with amount larger than his free collateral or collateral balance
    error ClearingHouse_AmountProvidedTooLarge();

    /// @notice Emitted when a user attempts to withdraw more liquidity than they have
    error ClearingHouse_RemoveLiquidityInsufficientFunds();

    /// @notice Emitted when the proposed minMargin is too low or too high
    error ClearingHouse_InvalidMinMargin();

    /// @notice Emitted when the proposed minimum open notional is too high
    error ClearingHouse_ExcessivePositiveOpenNotional();

    /// @notice Emitted when the proposed minMarginAtCreation is too low or too high
    error ClearingHouse_InvalidMinMarginAtCreation();

    /// @notice Emitted when the proposed liquidation reward is too low or too high
    error ClearingHouse_InvalidLiquidationReward();

    /// @notice Emitted when the proposed insurance ratio is too low or too high
    error ClearingHouse_InvalidInsuranceRatio();

    /// @notice Emitted when the proposed share of the liquidation reward for the insurance is too high
    error ClearingHouse_ExcessiveLiquidationRewardInsuranceShare();

    /// @notice Emitted when the difference between liquidationDiscount and nonUACollSeizureDiscount isn't large enough
    error ClearingHouse_InsufficientDiffBtwLiquidationDiscountAndNonUACollSeizureDiscount();

    /// @notice Emitted when the liquidationDiscount is too high
    error ClearingHouse_ExcessiveLiquidationDiscount();

    /// @notice Emitted when the proposed UA debt limit is lower than the minimum acceptable value
    error ClearingHouse_InsufficientUaDebtSeizureThreshold();

    /// @notice Emitted when a user attempts to extend their position with amount equal to 0
    error ClearingHouse_ExtendPositionZeroAmount();

    /// @notice Emitted when there is not enough margin to extend to the proposed position amount
    error ClearingHouse_ExtendPositionInsufficientMargin();

    /// @notice Emitted when a user attempts to reduce their position with amount equal to 0
    error ClearingHouse_ReducePositionZeroAmount();

    /// @notice Emitted when a user attempts to change his position with no amount
    error ClearingHouse_ChangePositionZeroAmount();

    /// @notice Emitted when a user tries to open a position with an incorrect open notional amount
    error ClearingHouse_UnderOpenNotionalAmountRequired();

    /// @notice Emitted when a collateral liquidation for a user with no UA debt is tried
    error ClearingHouse_LiquidationDebtSizeZero();

    /// @notice Emitted when a liquidator tries seizing collateral of user with sufficient collaterals level
    error ClearingHouse_SufficientUserCollateral();

    /// @notice Emitted when attempting to deposit to the zero address
    error ClearingHouse_DepositForZeroAddress();

    /// @notice Emitted when governance tries to sell dust with a negative balance
    error ClearingHouse_NegativeDustProceeds();

    /* ****************** */
    /*     Events         */
    /* ****************** */

    /// @notice Emitted when new perpetual market is added
    /// @param perpetual New perpetual market
    /// @param listedIdx Added Market Idx
    /// @param numPerpetuals New number of perpetual markets
    event MarketAdded(IPerpetual indexed perpetual, uint256 listedIdx, uint256 numPerpetuals);

    /// @notice Emitted when perpetual market is removed
    /// @param perpetual Removed perpetual market
    /// @param delistedIdx Removed Market Idx
    /// @param numPerpetuals New number of perpetual markets
    event MarketRemoved(IPerpetual indexed perpetual, uint256 delistedIdx, uint256 numPerpetuals);

    /// @notice Emitted when a position is opened/extended
    /// @param idx Index of the perpetual market
    /// @param user User who opened/extended a position
    /// @param direction Whether the position is LONG or SHORT
    /// @param addedOpenNotional Notional (USD assets/debt) added to the position
    /// @param addedPositionSize PositionSize (Base assets/debt) added to the position
    /// @param profit Sum of pnL + tradingFeesPayed - insurance fees
    /// @param tradingFeesPayed "tbd"
    /// @param insuranceFeesPayed "tbd"
    /// @param isPositionIncreased Whether the position was extended or reduced / reversed
    /// @param isPositionClosed Whether the position was closed
    event ChangePosition(
        uint256 indexed idx,
        address indexed user,
        LibPerpetual.Side direction,
        int256 addedOpenNotional,
        int256 addedPositionSize,
        int256 profit,
        int256 tradingFeesPayed,
        int256 insuranceFeesPayed,
        bool isPositionIncreased,
        bool isPositionClosed
    );

    /// @notice Emitted when an user position is liquidated
    /// @param idx Index of the perpetual market
    /// @param liquidatee User who gets liquidated
    /// @param liquidator User who is liquidating
    /// @param notional Notional amount of the liquidatee
    /// @param profit Profit of the trader
    /// @param isTrader Whether the user is a trader
    event LiquidationCall(
        uint256 indexed idx,
        address indexed liquidatee,
        address indexed liquidator,
        uint256 notional,
        int256 profit,
        int256 tradingFeesPayed,
        bool isTrader
    );

    /// @notice Emitted when an user non-UA collaterals are seized
    /// @param liquidatee User whose non-UA assets are seized
    /// @param liquidator User who is seizing the assets
    event SeizeCollateral(address indexed liquidatee, address indexed liquidator);

    /// @notice Emitted when (additional) liquidity is provided
    /// @param idx Index of the perpetual market
    /// @param liquidityProvider User who provides liquidity
    /// @param quoteAmount vQuote amount (i.e. USD amount) to be added to the targeted market
    /// @param baseAmount vBase amount (i.e. Base amount) to be added to the targeted market
    /// @param tradingFeesEarned Trading fees earned by the liquidity provider
    event LiquidityProvided(
        uint256 indexed idx,
        address indexed liquidityProvider,
        uint256 quoteAmount,
        uint256 baseAmount,
        int256 tradingFeesEarned
    );

    /// @notice Emitted when liquidity is removed
    /// @param idx Index of the perpetual market
    /// @param liquidityProvider User who provides liquidity
    /// @param profit Sum of pnL + Trading fees earned - Trading fees paid - Insurance fees paid
    /// @param tradingFeesPayed Trading fees paid for closing the active position
    /// @param reductionRatio Percentage of previous position reduced
    event LiquidityRemoved(
        uint256 indexed idx,
        address indexed liquidityProvider,
        uint256 reductionRatio,
        int256 profit,
        int256 tradingFeesPayed,
        bool isPositionClosed
    );

    /// @notice Emitted when dust is sold by governance
    /// @param idx Index of the perpetual market
    /// @param profit Amount of profit generated by the dust sale. 18 decimals
    /// @param tradingFeesPayed Trading fees paid on dust sell. 18 decimals
    event DustSold(uint256 indexed idx, int256 profit, int256 tradingFeesPayed);

    /// @notice Emitted when parameters are changed
    event ClearingHouseParametersChanged(
        int256 newMinMargin,
        int256 newMinMarginAtCreation,
        uint256 newMinPositiveOpenNotional,
        uint256 newLiquidationReward,
        uint256 newInsuranceRatio,
        uint256 newLiquidationRewardInsuranceShare,
        uint256 newLiquidationDiscount,
        uint256 nonUACollSeizureDiscount,
        int256 uaDebtSeizureThreshold
    );

    event RewardContractChanged(IRewardContract newRewardContract);

    /* ****************** */
    /*     Viewer         */
    /* ****************** */

    function vault() external view returns (IVault);

    function insurance() external view returns (IInsurance);

    function perpetuals(uint256 idx) external view returns (IPerpetual);

    function id(uint256 i) external view returns (uint256);

    function marketIds() external view returns (uint256);

    function rewardContract() external view returns (IRewardContract);

    function getNumMarkets() external view returns (uint256);

    function minMargin() external view returns (int256);

    function minMarginAtCreation() external view returns (int256);

    function minPositiveOpenNotional() external view returns (uint256);

    function liquidationReward() external view returns (uint256);

    function insuranceRatio() external view returns (uint256);

    function liquidationRewardInsuranceShare() external view returns (uint256);

    function liquidationDiscount() external view returns (uint256);

    function nonUACollSeizureDiscount() external view returns (uint256);

    function uaDebtSeizureThreshold() external view returns (int256);

    function getPnLAcrossMarkets(address account) external view returns (int256);

    function getDebtAcrossMarkets(address account) external view returns (int256);

    function canSeizeCollateral(address liquidatee) external view returns (bool);

    /* ****************** */
    /*  State modifying   */
    /* ****************** */

    function allowListPerpetual(IPerpetual perp) external;

    function delistPerpetual(IPerpetual perp) external;

    function pause() external;

    function unpause() external;

    function settleDust(uint256 idx, uint256 proposedAmount, uint256 minAmount, LibPerpetual.Side direction) external;

    function setParameters(ClearingHouseParams memory params) external;

    function updateGlobalState() external;

    function addRewardContract(IRewardContract rewardDistributor) external;

    function increaseAllowance(address receiver, uint256 addedAmount, IERC20Metadata token) external;

    function decreaseAllowance(address receiver, uint256 subtractedAmount, IERC20Metadata token) external;

    function deposit(uint256 amount, IERC20Metadata token) external;

    function depositFor(address user, uint256 amount, IERC20Metadata token) external;

    function withdraw(uint256 amount, IERC20Metadata token) external;

    function withdrawAll(IERC20Metadata token) external;

    function withdrawFrom(address user, uint256 amount, IERC20Metadata token) external;

    function changePosition(uint256 idx, uint256 amount, uint256 minAmount, LibPerpetual.Side direction) external;

    function extendPositionWithCollateral(
        uint256 idx,
        address user,
        uint256 collateralAmount,
        IERC20Metadata token,
        uint256 positionAmount,
        LibPerpetual.Side direction,
        uint256 minAmount
    ) external;

    function closePositionWithdrawCollateral(
        uint256 idx,
        uint256 proposedAmount,
        uint256 minAmount,
        IERC20Metadata token
    ) external;

    function openReversePosition(
        uint256 idx,
        uint256 closeProposedAmount,
        uint256 closeMinAmount,
        uint256 openProposedAmount,
        uint256 openMinAmount,
        LibPerpetual.Side direction
    ) external;

    function liquidateTrader(uint256 idx, address liquidatee, uint256 proposedAmount, uint256 minAmount) external;

    function liquidateLp(
        uint256 idx,
        address liquidatee,
        uint256[2] calldata minVTokenAmounts,
        uint256 proposedAmount,
        uint256 minAmount
    ) external;

    function seizeCollateral(address liquidatee) external;

    function provideLiquidity(uint256 idx, uint256[2] calldata amounts, uint256 minLpAmount) external;

    function removeLiquidity(
        uint256 idx,
        uint256 liquidityAmountToRemove,
        uint256[2] calldata minVTokenAmounts,
        uint256 proposedAmount,
        uint256 minAmount
    ) external;
}
