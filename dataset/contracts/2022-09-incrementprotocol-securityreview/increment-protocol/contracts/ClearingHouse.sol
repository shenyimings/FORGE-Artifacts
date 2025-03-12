// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.16;

// contracts
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "../lib/openzeppelin-contracts/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {IncreAccessControl} from "./utils/IncreAccessControl.sol";

// interfaces
import {IERC20Metadata} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IClearingHouse} from "./interfaces/IClearingHouse.sol";
import {IPerpetual} from "./interfaces/IPerpetual.sol";
import {IInsurance} from "./interfaces/IInsurance.sol";
import {IVault} from "./interfaces/IVault.sol";
import {ICryptoSwap} from "./interfaces/ICryptoSwap.sol";
import {IRewardContract} from "./interfaces/IRewardContract.sol";
import {IPausable} from "./interfaces/IPausable.sol";

// libraries
import {LibMath} from "./lib/LibMath.sol";
import {LibPerpetual} from "./lib/LibPerpetual.sol";
import {LibReserve} from "./lib/LibReserve.sol";

/// @notice Entry point for users to vault and perpetual markets
contract ClearingHouse is IClearingHouse, IncreAccessControl, Pausable, ReentrancyGuard {
    using LibMath for int256;
    using LibMath for uint256;
    using SafeERC20 for IERC20Metadata;

    // constants
    uint256 internal constant VQUOTE_INDEX = 0; // index of quote asset in curve pool
    uint256 internal constant VBASE_INDEX = 1; // index of base asset in curve pool

    // parameterization

    /// @notice minimum maintenance margin
    int256 public override minMargin;

    /// @notice minimum margin when opening a position
    int256 public override minMarginAtCreation;

    /// @notice minimum positive open notional when opening a position
    uint256 public override minPositiveOpenNotional;

    /// @notice liquidation reward paid to liquidators
    /// @dev Paid on dollar value of an trader position. important: liquidationReward < minMargin or liquidations will result in protocol losses
    uint256 public override liquidationReward;

    /// @notice Insurance ratio
    /// @dev Once the insurance reserve exceed this ratio of the tvl, governance can withdraw exceeding insurance fee
    uint256 public override insuranceRatio;

    /// @notice Portion of the liquidation reward that the insurance gets
    uint256 public override liquidationRewardInsuranceShare;

    /// @notice Discount on the collateral price for the liquidator
    uint256 public override liquidationDiscount;

    /// @notice Discount ratio to be applied on non-UA collaterals before seizing said collaterals for some UA
    /// @dev Must be lower than liquidationDiscount to ensure liquidations don't generate bad debt
    uint256 public override nonUACollSeizureDiscount;

    /// @notice UA debt amount at which non-UA collaterals can be seized to pay back UA debts
    int256 public override uaDebtSeizureThreshold;

    // dependencies

    /// @notice Vault contract
    IVault public override vault;

    /// @notice Insurance contract
    IInsurance public override insurance;

    /// @notice Reward distributor contract
    IRewardContract public override rewardContract;

    /// @notice Allowlisted Perpetual indices
    uint256[] public override id;

    /// @notice Allowlisted Perpetual contracts
    mapping(uint256 => IPerpetual) public override perpetuals;

    /// @notice Number of Allowlisted Perpetuals
    uint256 public override marketIds;

    constructor(IVault _vault, IInsurance _insurance, ClearingHouseParams memory _params) {
        if (address(_vault) == address(0)) revert ClearingHouse_ZeroAddress();
        if (address(_insurance) == address(0)) revert ClearingHouse_ZeroAddress();

        vault = _vault;
        insurance = _insurance;

        setParameters(_params);
    }

    /* **************************** */
    /*   Collateral operations      */
    /* **************************** */

    /// @notice Increase withdrawal approval for a receiving address on the vault
    /// @param receiver Address allowed to transfer `amount` of `token` of msg.sender from the vault
    /// @param addedAmount Amount to add to the current approved value. 18 decimals
    /// @param token Token to be withdrawn by the `to` address
    function increaseAllowance(address receiver, uint256 addedAmount, IERC20Metadata token) external override {
        vault.increaseAllowance(msg.sender, receiver, addedAmount, token);
    }

    /// @notice Decrease withdrawal approval for a receiving address on the vault
    /// @param receiver Address allowed to transfer `amount` of `token` of msg.sender from the vault
    /// @param subtractedAmount Amount to subtract from the current approved value. 18 decimals
    /// @param token Token to be withdrawn by the `to` address
    function decreaseAllowance(address receiver, uint256 subtractedAmount, IERC20Metadata token) external override {
        vault.decreaseAllowance(msg.sender, receiver, subtractedAmount, token);
    }

    /// @notice Deposit tokens into the vault
    /// @param amount Amount to be used as collateral. Might not be 18 decimals
    /// @param token Token to be used for the collateral
    function deposit(uint256 amount, IERC20Metadata token) external override nonReentrant whenNotPaused {
        _deposit(msg.sender, amount, token);
    }

    /// @notice Deposit tokens into the vault on behalf of another user
    /// @param user Address of user whose balance should be adjusted
    /// @param amount Amount to be used as collateral. Might not be 18 decimals
    /// @param token Token to be used for the collateral
    function depositFor(address user, uint256 amount, IERC20Metadata token)
        external
        override
        nonReentrant
        whenNotPaused
    {
        _deposit(user, amount, token);
    }

    /// @notice Withdraw tokens from the vault
    /// @param amount Amount of collateral to withdraw. Might not be 18 decimals (decimals of `token`)
    /// @param token Token of the collateral
    function withdraw(uint256 amount, IERC20Metadata token) external override nonReentrant whenNotPaused {
        vault.withdraw(msg.sender, amount, token);

        if (!_isPositionValid(msg.sender, minMarginAtCreation)) revert ClearingHouse_WithdrawInsufficientMargin();
    }

    /// @notice Withdraw tokens from the vault on behalf of a user
    /// @param user Account to withdraw collateral from
    /// @param amount Amount of collateral to withdraw. Might not be 18 decimals (decimals of `token`)
    /// @param token Token of the collateral
    function withdrawFrom(address user, uint256 amount, IERC20Metadata token)
        external
        override
        nonReentrant
        whenNotPaused
    {
        vault.withdrawFrom(user, msg.sender, amount, token);

        if (!_isPositionValid(user, minMarginAtCreation)) revert ClearingHouse_WithdrawInsufficientMargin();
    }

    /// @notice Withdraw all tokens from the vault
    /// @dev Should only be called by the trader
    /// @param token Token of the collateral
    function withdrawAll(IERC20Metadata token) external override nonReentrant whenNotPaused {
        vault.withdrawAll(msg.sender, token);

        if (!_isPositionValid(msg.sender, minMarginAtCreation)) revert ClearingHouse_WithdrawInsufficientMargin();
    }

    /* ****************** */
    /*   Trader flow      */
    /* ****************** */

    /// @notice Open or increase or reduce a position, either LONG or SHORT
    /// @dev No number for the leverage is given but the amount in the vault must be bigger than minMarginAtCreation
    /// @param idx Index of the perpetual market
    /// @param amount Amount in vQuote (if LONG) or vBase (if SHORT) to sell. 18 decimals
    /// @param minAmount Minimum amount that the user is willing to accept. 18 decimals
    /// @param direction Whether the trader wants to go in the LONG or SHORT direction overall
    function changePosition(uint256 idx, uint256 amount, uint256 minAmount, LibPerpetual.Side direction)
        external
        override
        nonReentrant
        whenNotPaused
    {
        _changePosition(idx, amount, minAmount, direction);
    }

    /// @notice Open a position in the opposite direction of the currently opened position
    /// @notice For example, a trader with a LONG position can switch to a SHORT position with just one call to this function
    /// @param idx Index of the perpetual market
    /// @param closeProposedAmount Amount in vQuote (if SHORT) or vBase (if LONG) to sell to close the position. 18 decimals
    /// @param closeMinAmount Minimum amount that the user is willing to accept when closing the position. 18 decimals
    /// @param openProposedAmount Amount in vQuote (if LONG) or vBase (if SHORT) to sell to open the reversed position. 18 decimals
    /// @param openMinAmount Minimum amount that the user is willing to accept when opening the reversed position. 18 decimals
    /// @param direction Whether the trader wants to go in the LONG or SHORT direction overall
    function openReversePosition(
        uint256 idx,
        uint256 closeProposedAmount,
        uint256 closeMinAmount,
        uint256 openProposedAmount,
        uint256 openMinAmount,
        LibPerpetual.Side direction
    ) external override nonReentrant whenNotPaused {
        _changePosition(idx, closeProposedAmount, closeMinAmount, direction);
        if (perpetuals[idx].isTraderPositionOpen(msg.sender)) revert ClearingHouse_ClosePositionStillOpen();
        _changePosition(idx, openProposedAmount, openMinAmount, direction);
    }

    /// @notice Single open position function, groups depositing collateral and extending position
    /// @param idx Index of the perpetual market
    /// @param user Address of user whose balance should be adjusted
    /// @param collateralAmount Amount to be used as the collateral of the position. Might not be 18 decimals
    /// @param token Token to be used for the collateral of the position
    /// @param positionAmount Amount to be sold, in vQuote (if LONG) or vBase (if SHORT). Must be 18 decimals
    /// @param direction Whether the position is LONG or SHORT
    /// @param minAmount Minimum amount that the user is willing to accept. 18 decimals
    function extendPositionWithCollateral(
        uint256 idx,
        address user,
        uint256 collateralAmount,
        IERC20Metadata token,
        uint256 positionAmount,
        LibPerpetual.Side direction,
        uint256 minAmount
    ) external override nonReentrant whenNotPaused {
        _deposit(user, collateralAmount, token);
        _changePosition(idx, positionAmount, minAmount, direction);
    }

    /// @notice Single close position function, groups closing position and withdrawing collateral
    /// @notice Important: `proposedAmount` must be large enough to close the entire position else the function call will fail
    /// @param idx Index of the perpetual market
    /// @param proposedAmount Amount of tokens to be sold, in vBase if LONG, in vQuote if SHORT. 18 decimals
    /// @param minAmount Minimum amount that the user is willing to accept, in vQuote if LONG, in vBase if SHORT. 18 decimals
    /// @param token Token used for the collateral
    function closePositionWithdrawCollateral(
        uint256 idx,
        uint256 proposedAmount,
        uint256 minAmount,
        IERC20Metadata token
    ) external override nonReentrant whenNotPaused {
        int256 traderPositionSize = _getTraderPosition(idx, msg.sender).positionSize;

        LibPerpetual.Side closeDirection = traderPositionSize > 0 ? LibPerpetual.Side.Short : LibPerpetual.Side.Long;

        _changePosition(idx, proposedAmount, minAmount, closeDirection);

        if (perpetuals[idx].isTraderPositionOpen(msg.sender)) revert ClearingHouse_ClosePositionStillOpen();

        // tentatively remove all liquidity of user
        // if user had just one position (trading or LP) in one market, it'll pass, else not
        vault.withdrawAll(msg.sender, token);

        if (!_isPositionValid(msg.sender, minMarginAtCreation)) revert ClearingHouse_WithdrawInsufficientMargin();
    }

    /* ****************** */
    /*  Liquidation flow  */
    /* ****************** */

    /// @notice Submit the address of an Trader whose position is worth liquidating for a reward
    /// @param idx Index of the perpetual market
    /// @param liquidatee Address of the account to liquidate
    /// @param proposedAmount Amount of tokens to be sold, in vBase if LONG, in vQuote if SHORT. 18 decimals
    /// @param minAmount Minimum amount that the user is willing to accept. 18 decimals
    function liquidateTrader(uint256 idx, address liquidatee, uint256 proposedAmount, uint256 minAmount)
        external
        override
        nonReentrant
        whenNotPaused
    {
        address liquidator = msg.sender;

        _settleUserFundingPayments(liquidatee);

        if (!perpetuals[idx].isTraderPositionOpen(liquidatee)) revert ClearingHouse_LiquidateInvalidPosition();
        if (_isPositionValid(liquidatee, minMargin)) revert ClearingHouse_LiquidateValidMargin();

        (int256 profit, int256 tradingFeesPayed, int256 positiveOpenNotional) =
            _liquidateTraderPosition(idx, liquidatee, proposedAmount, minAmount);
        int256 liquidateeProfit =
            _chargeAndDistributeLiquidationFee(liquidator, liquidatee, profit, positiveOpenNotional);

        emit LiquidationCall(
            idx, liquidatee, liquidator, positiveOpenNotional.toUint256(), liquidateeProfit, tradingFeesPayed, true
        );
    }

    /// @notice Submit the address of a LP whose position is worth liquidating for a reward
    /// @param idx Index of the perpetual market
    /// @param liquidatee Address of the account to liquidate
    /// @param proposedAmount Amount of tokens to be sold, in vBase if LONG, in vQuote if SHORT. 18 decimals
    /// @param minAmount Minimum amount that the user is willing to accept. 18 decimals
    function liquidateLp(
        uint256 idx,
        address liquidatee,
        uint256[2] calldata minVTokenAmounts,
        uint256 proposedAmount,
        uint256 minAmount
    ) external override nonReentrant whenNotPaused {
        address liquidator = msg.sender;

        _settleUserFundingPayments(liquidatee);

        if (!perpetuals[idx].isLpPositionOpen(liquidatee)) revert ClearingHouse_LiquidateInvalidPosition();
        if (_isPositionValid(liquidatee, minMargin)) revert ClearingHouse_LiquidateValidMargin();

        (int256 profit, int256 tradingFeesPayed, int256 positiveOpenNotional) =
            _liquidateLpPosition(idx, liquidatee, minVTokenAmounts, proposedAmount, minAmount);
        int256 liquidateeProfit =
            _chargeAndDistributeLiquidationFee(liquidator, liquidatee, profit, positiveOpenNotional);

        emit LiquidationCall(
            idx, liquidatee, liquidator, positiveOpenNotional.toUint256(), liquidateeProfit, tradingFeesPayed, false
        );
    }

    /// @notice Buy the non-UA collaterals of a user at a discounted UA price to settle the debt of said user
    /// @param liquidatee Address of the account to liquidate
    function seizeCollateral(address liquidatee) external override nonReentrant whenNotPaused {
        address liquidator = msg.sender;

        if (canSeizeCollateral(liquidatee)) {
            vault.settleLiquidationOnCollaterals(liquidator, liquidatee);

            emit SeizeCollateral(liquidatee, liquidator);
        } else {
            revert ClearingHouse_SufficientUserCollateral();
        }
    }

    /* ****************** */
    /*   Liquidity flow   */
    /* ****************** */

    /// @notice Provide liquidity to the pool, without depositing new capital in the vault
    /// @param idx Index of the perpetual market
    /// @param amounts Amount of virtual tokens ([vQuote, vBase]) provided. 18 decimals
    /// @param minLpAmount Minimum amount of Lp tokens minted. 18 decimals
    function provideLiquidity(uint256 idx, uint256[2] calldata amounts, uint256 minLpAmount)
        external
        override
        nonReentrant
        whenNotPaused
    {
        _provideLiquidity(idx, amounts, minLpAmount);
    }

    /// @notice Remove liquidity from the pool and account profit/loss in UA
    /// @param idx Index of the perpetual market
    /// @param liquidityAmountToRemove Amount of liquidity (in LP tokens) to be removed from the pool. 18 decimals
    /// @param minVTokenAmounts Minimum amount of virtual tokens [vQuote, vBase] to withdraw from the curve pool. 18 decimals
    /// @param proposedAmount Amount at which to sell the active LP position (in vBase if LONG, in vQuote if SHORT). 18 decimals
    /// @param minAmount Minimum amount that the user is willing to accept when closing his active position
    ///        generated after removing liquidity, in vQuote if LONG, in vBase if SHORT. 18 decimals
    function removeLiquidity(
        uint256 idx,
        uint256 liquidityAmountToRemove,
        uint256[2] calldata minVTokenAmounts,
        uint256 proposedAmount,
        uint256 minAmount
    ) external override nonReentrant whenNotPaused {
        _settleUserFundingPayments(msg.sender);

        (int256 profit, int256 tradingFeesPayed, uint256 reductionRatio, int256 quoteProceeds, bool isPositionClosed) =
        perpetuals[idx].removeLiquidity(
            msg.sender, liquidityAmountToRemove, minVTokenAmounts, proposedAmount, minAmount, false
        );

        // distribute rewards
        _distributeLpRewards(idx, msg.sender);

        // pay insurance fee on traded amount
        int256 insuranceFeeAmount = quoteProceeds.abs().wadMul(perpetuals[idx].insuranceFee());
        insurance.fundInsurance(insuranceFeeAmount.toUint256());

        profit = profit - insuranceFeeAmount;
        vault.settlePnL(msg.sender, profit);

        if (!_isOpenNotionalRequirementValid(idx, msg.sender, false)) {
            revert ClearingHouse_UnderOpenNotionalAmountRequired();
        }

        emit LiquidityRemoved(idx, msg.sender, reductionRatio, profit, tradingFeesPayed, isPositionClosed);
    }

    /* ****************** */
    /*     Governance     */
    /* ****************** */

    /// @notice Sell dust of a given market
    /// @dev Can only be called by Emergency Admin
    /// @param idx Index of the perpetual market to sell dust from
    /// @param proposedAmount Amount of tokens to be sold, in vBase if LONG, in vQuote if SHORT. 18 decimals
    /// @param minAmount Minimum amount that the user is willing to accept, in vQuote if LONG, in vBase if SHORT. 18 decimals
    function settleDust(uint256 idx, uint256 proposedAmount, uint256 minAmount, LibPerpetual.Side direction)
        external
        override
        nonReentrant
        onlyRole(EMERGENCY_ADMIN)
    {
        _settleUserFundingPayments(address(this));

        (,, int256 profit, int256 tradingFeesPayed,,) =
            perpetuals[idx].changePosition(address(this), proposedAmount, minAmount, direction, false);

        if (profit < 0) revert ClearingHouse_NegativeDustProceeds();

        // no Vault balance to reduce because the positions where dust have been taken out
        // have already been reduced (see `Perpetual._donate`)
        insurance.fundInsurance(profit.toUint256());

        emit DustSold(idx, profit, tradingFeesPayed);
    }

    /// @notice Pause the contract
    /// @dev Can only be called by Emergency Admin
    function pause() external override onlyRole(EMERGENCY_ADMIN) {
        _pause();
    }

    /// @notice Unpause the contract
    /// @dev Can only be called by Emergency Admin
    function unpause() external override onlyRole(EMERGENCY_ADMIN) {
        _unpause();
    }

    /// @notice Add one perpetual market to the list of markets
    /// @param perp Market to add to the list of supported markets
    function allowListPerpetual(IPerpetual perp) external override onlyRole(GOVERNANCE) {
        if (address(perp) == address(0)) revert ClearingHouse_ZeroAddress();

        for (uint256 i = 0; i < getNumMarkets(); i++) {
            if (perpetuals[id[i]] == perp) revert ClearingHouse_PerpetualMarketAlreadyAssigned();
        }
        // get upcoming idx
        uint256 listedIdx = marketIds;
        marketIds += 1;

        // list market
        perpetuals[listedIdx] = perp;
        id.push(listedIdx);

        emit MarketAdded(perp, listedIdx, getNumMarkets());
    }

    /// @notice Remove one perpetual market of the list of markets
    /// @param perp Market to remove from the list of supported markets
    function delistPerpetual(IPerpetual perp) external override onlyRole(GOVERNANCE) {
        // get idx of delisted market
        uint256 delistedIdx = 0;
        for (uint256 i = 0; i < getNumMarkets(); i++) {
            if (perpetuals[id[i]] == perp) {
                delistedIdx = i;
            }
        }
        if (perpetuals[id[delistedIdx]] != perp) revert ClearingHouse_MarketDoesNotExist();

        // delist market
        // @dev: replace removed idx by last element and delete last element
        delete perpetuals[id[delistedIdx]];
        id[delistedIdx] = id[id.length - 1];
        id.pop();

        emit MarketRemoved(perp, delistedIdx, getNumMarkets());
    }

    /// @notice Add a reward distributor contract
    /// @param rewardDistributor Reward distributor contract
    function addRewardContract(IRewardContract rewardDistributor) external override onlyRole(GOVERNANCE) {
        if (address(rewardDistributor) == address(0)) revert ClearingHouse_ZeroAddress();
        rewardContract = rewardDistributor;

        emit RewardContractChanged(rewardDistributor);
    }

    /// @notice Update the value of the param listed in `IClearingHouse.ClearingHouseParams`
    /// @param params New economic parameters
    function setParameters(ClearingHouseParams memory params) public override onlyRole(GOVERNANCE) {
        if (params.minMargin < 2e16 || params.minMargin > 2e17) revert ClearingHouse_InvalidMinMargin();
        if (params.minMarginAtCreation <= params.minMargin || params.minMarginAtCreation > 5e17) {
            revert ClearingHouse_InvalidMinMarginAtCreation();
        }
        if (params.minPositiveOpenNotional > 1000 * 1e18) revert ClearingHouse_ExcessivePositiveOpenNotional();
        if (params.liquidationReward < 1e16 || params.liquidationReward >= params.minMargin.toUint256()) {
            revert ClearingHouse_InvalidLiquidationReward();
        }
        if (params.liquidationDiscount < 7e17) revert ClearingHouse_ExcessiveLiquidationDiscount();
        if (params.nonUACollSeizureDiscount + 1e17 > params.liquidationDiscount) {
            revert ClearingHouse_InsufficientDiffBtwLiquidationDiscountAndNonUACollSeizureDiscount();
        } // even with an assets with a weight of 1 the nonUACollateralSeizeDiscount should be less than the liquidationDiscount
        if (params.uaDebtSeizureThreshold < 1e20) revert ClearingHouse_InsufficientUaDebtSeizureThreshold();
        if (params.insuranceRatio < 1e17 || params.insuranceRatio > 5e17) revert ClearingHouse_InvalidInsuranceRatio();
        if (params.liquidationRewardInsuranceShare > 1e18) {
            revert ClearingHouse_ExcessiveLiquidationRewardInsuranceShare();
        }

        minMargin = params.minMargin;
        minPositiveOpenNotional = params.minPositiveOpenNotional;
        liquidationReward = params.liquidationReward;
        liquidationDiscount = params.liquidationDiscount;
        nonUACollSeizureDiscount = params.nonUACollSeizureDiscount;
        uaDebtSeizureThreshold = params.uaDebtSeizureThreshold;
        insuranceRatio = params.insuranceRatio;
        minMarginAtCreation = params.minMarginAtCreation;
        liquidationRewardInsuranceShare = params.liquidationRewardInsuranceShare;

        emit ClearingHouseParametersChanged(
            params.minMargin,
            params.minMarginAtCreation,
            params.minPositiveOpenNotional,
            params.liquidationReward,
            params.insuranceRatio,
            params.liquidationRewardInsuranceShare,
            params.liquidationDiscount,
            params.nonUACollSeizureDiscount,
            params.uaDebtSeizureThreshold
        );
    }

    /* ****************** */
    /*        Misc        */
    /* ****************** */

    function updateGlobalState() external override {
        uint256 numMarkets = getNumMarkets();
        for (uint256 i = 0; i < numMarkets;) {
            if (!IPausable(address(perpetuals[id[i]])).paused()) {
                perpetuals[id[i]].updateGlobalState();
            }

            unchecked {
                ++i;
            }
        }
    }

    /* ****************** */
    /*   Market viewer    */
    /* ****************** */

    /// @notice Return the number of active markets
    function getNumMarkets() public view override returns (uint256) {
        return id.length;
    }

    /* ****************** */
    /*   User viewer      */
    /* ****************** */

    /// @notice Get user profit/loss across all perpetual markets
    /// @param account User address (trader and/or liquidity provider)
    function getPnLAcrossMarkets(address account) public view override returns (int256 unrealizedPositionPnl) {
        uint256 numMarkets = getNumMarkets();
        for (uint256 i = 0; i < numMarkets;) {
            unrealizedPositionPnl += perpetuals[id[i]].getPendingPnL(account);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Get user debt across all perpetual markets
    /// @param account User address (trader and/or liquidity provider)
    function getDebtAcrossMarkets(address account) public view override returns (int256 userDebt) {
        uint256 numMarkets = getNumMarkets();
        for (uint256 i = 0; i < numMarkets;) {
            uint256 weight = perpetuals[id[i]].riskWeight();
            userDebt += perpetuals[id[i]].getUserDebt(account).wadMul(weight.toInt256());

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Get the margin required to serve user debt at a chosen margin ratio
    /// @param account User address (trader and/or liquidity provider)
    /// @param ratio Margin ratio (minMargin or minMarginAtCreation)
    function getTotalMarginRequirement(address account, int256 ratio) public view returns (int256 requiredMargin) {
        int256 userDebt = getDebtAcrossMarkets(account);
        /*
            From the margin ratio formula we know:
            margin / userDebt = ratio

            So we can compute the required margin as:
            margin = userDebt * ratio
        */
        return userDebt.wadMul(ratio);
    }

    /// @notice Get free collateral of a user given a chosen margin ratio
    /// @param account User address (trader and/or liquidity provider)
    /// @param ratio Margin ratio (minMargin or minMarginAtCreation)
    function getFreeCollateralByRatio(address account, int256 ratio) public view returns (int256 freeCollateral) {
        int256 pnl = getPnLAcrossMarkets(account);
        int256 reserveValue = _getReserveValue(account, true);
        int256 marginRequired = getTotalMarginRequirement(account, ratio);

        // We define freeCollateral as follows:
        // freeCollateral = min(totalCollateralValue, totalCollateralValue + pnl) - marginRequired)
        // This is a conservative approach when compared to
        // freeCollateral = totalCollateralValue + pnl - marginRequired
        // since the unrealized pnl depends on the index price
        // where a deviation could allow a trader to empty the vault

        return reserveValue.min(reserveValue + pnl) - marginRequired;
    }

    function canSeizeCollateral(address liquidatee) public view override returns (bool) {
        bool isPositionOpened = false;
        uint256 numMarkets = getNumMarkets();
        for (uint256 i = 0; i < numMarkets;) {
            if (perpetuals[id[i]].isTraderPositionOpen(liquidatee) || perpetuals[id[i]].isLpPositionOpen(liquidatee)) {
                isPositionOpened = true;
                break;
            }

            unchecked {
                ++i;
            }
        }

        int256 uaBalance = vault.getBalance(liquidatee, 0);
        int256 discountedCollateralsBalance = vault.getReserveValue(liquidatee, true);
        int256 discountedCollateralsBalanceExUA = discountedCollateralsBalance - uaBalance;

        // user must have UA debt
        if (uaBalance >= 0) revert ClearingHouse_LiquidationDebtSizeZero();

        // for a user to have his non-UA collaterals seized, one of the following 2 conditions must be met:
        // 1) the aggregate value of non-UA collaterals discounted by their weights and the nonUACollSeizureDiscount
        //    ratio must be smaller than his UA debt
        // 2) UA debt must be larger than the threshold defined by uaDebtSeizureThreshold
        return (
            -uaBalance > discountedCollateralsBalanceExUA.wadMul((nonUACollSeizureDiscount).toInt256())
                && !isPositionOpened
        ) || -uaBalance > uaDebtSeizureThreshold;
    }

    /* ****************** */
    /*   Internal user    */
    /* ****************** */

    function _liquidateTraderPosition(uint256 idx, address liquidatee, uint256 proposedAmount, uint256 minAmount)
        internal
        returns (int256 profit, int256 tradingFeesPayed, int256 positiveOpenNotional)
    {
        (positiveOpenNotional) = int256(_getTraderPosition(idx, liquidatee).openNotional).abs();

        LibPerpetual.Side closeDirection =
            _getTraderPosition(idx, liquidatee).positionSize >= 0 ? LibPerpetual.Side.Short : LibPerpetual.Side.Long;

        // (liquidatee, proposedAmount)
        (,, profit, tradingFeesPayed,,) =
            perpetuals[idx].changePosition(liquidatee, proposedAmount, minAmount, closeDirection, true);

        // traders are allowed to reduce their positions partially, but liquidators have to close positions in full
        if (perpetuals[idx].isTraderPositionOpen(liquidatee)) {
            revert ClearingHouse_LiquidateInsufficientProposedAmount();
        }

        return (profit, tradingFeesPayed, positiveOpenNotional);
    }

    function _liquidateLpPosition(
        uint256 idx,
        address liquidatee,
        uint256[2] calldata minVTokenAmounts,
        uint256 proposedAmount,
        uint256 minAmount
    ) internal returns (int256 profit, int256 tradingFeesPayed, int256 positiveOpenNotional) {
        positiveOpenNotional = _getLpOpenNotional(idx, liquidatee).abs();

        // close lp
        (profit, tradingFeesPayed,,,) = perpetuals[idx].removeLiquidity(
            liquidatee, _getLpLiquidity(idx, liquidatee), minVTokenAmounts, proposedAmount, minAmount, true
        );

        // distribute rewards
        _distributeLpRewards(idx, liquidatee);

        return (profit, tradingFeesPayed, positiveOpenNotional);
    }

    function _chargeAndDistributeLiquidationFee(
        address liquidator,
        address liquidatee,
        int256 pnl,
        int256 positiveOpenNotional
    ) internal returns (int256 liquidateeProfit) {
        // take fee from liquidatee for liquidator and insurance
        uint256 liquidationRewardAmount = positiveOpenNotional.toUint256().wadMul(liquidationReward);
        uint256 insuranceLiquidationReward = liquidationRewardAmount.wadMul(liquidationRewardInsuranceShare);
        uint256 liquidatorLiquidationReward = liquidationRewardAmount - insuranceLiquidationReward;

        vault.settlePnL(liquidator, liquidatorLiquidationReward.toInt256());
        insurance.fundInsurance(insuranceLiquidationReward);

        liquidateeProfit = pnl - liquidationRewardAmount.toInt256();
        vault.settlePnL(liquidatee, liquidateeProfit);
    }

    function _deposit(address user, uint256 amount, IERC20Metadata token) internal {
        if (user == address(0)) revert ClearingHouse_DepositForZeroAddress();
        vault.deposit(msg.sender, user, amount, token);
    }

    function _changePosition(uint256 idx, uint256 amount, uint256 minAmount, LibPerpetual.Side direction) internal {
        if (amount == 0) revert ClearingHouse_ChangePositionZeroAmount();

        _settleUserFundingPayments(msg.sender);

        (
            int256 quoteProceeds,
            int256 baseProceeds,
            int256 profit,
            int256 tradingFeesPayed,
            bool isPositionIncreased,
            bool isPositionClosed
        ) = perpetuals[idx].changePosition(msg.sender, amount, minAmount, direction, false);

        // pay insurance fee
        int256 insuranceFeeAmount = 0;
        if (isPositionIncreased) {
            insuranceFeeAmount = quoteProceeds.abs().wadMul(perpetuals[idx].insuranceFee());
            insurance.fundInsurance(insuranceFeeAmount.toUint256());
        }

        int256 traderVaultDiff = profit - insuranceFeeAmount;
        vault.settlePnL(msg.sender, traderVaultDiff);

        if (!_isPositionValid(msg.sender, minMarginAtCreation)) revert ClearingHouse_ExtendPositionInsufficientMargin();
        if (!_isOpenNotionalRequirementValid(idx, msg.sender, true)) {
            revert ClearingHouse_UnderOpenNotionalAmountRequired();
        }

        emit ChangePosition(
            idx,
            msg.sender,
            direction,
            quoteProceeds,
            baseProceeds,
            traderVaultDiff,
            tradingFeesPayed,
            insuranceFeeAmount,
            isPositionIncreased,
            isPositionClosed
        );
    }

    function _provideLiquidity(uint256 idx, uint256[2] calldata amounts, uint256 minLpAmount) internal {
        if (amounts[VQUOTE_INDEX] == 0 && amounts[VBASE_INDEX] == 0) revert ClearingHouse_ProvideLiquidityZeroAmount();

        _settleUserFundingPayments(msg.sender);

        // check enough free collateral
        int256 freeCollateralUSD = getFreeCollateralByRatio(msg.sender, minMarginAtCreation);

        // compare the dollar value of quantities q1 & q2 with the free collateral
        if (
            amounts[VQUOTE_INDEX].toInt256() + amounts[VBASE_INDEX].toInt256().wadMul(perpetuals[idx].indexPrice())
                > freeCollateralUSD
        ) revert ClearingHouse_AmountProvidedTooLarge();

        int256 tradingFees = perpetuals[idx].provideLiquidity(msg.sender, amounts, minLpAmount);
        if (tradingFees != 0) vault.settlePnL(msg.sender, tradingFees);

        _distributeLpRewards(idx, msg.sender);

        if (!_isPositionValid(msg.sender, minMarginAtCreation)) revert ClearingHouse_AmountProvidedTooLarge();
        if (!_isOpenNotionalRequirementValid(idx, msg.sender, false)) {
            revert ClearingHouse_UnderOpenNotionalAmountRequired();
        }

        emit LiquidityProvided(idx, msg.sender, amounts[VQUOTE_INDEX], amounts[VBASE_INDEX], tradingFees);
    }

    /// @notice Settle funding payments of a user across all markets, on trading and liquidity positions
    function _settleUserFundingPayments(address account) internal {
        int256 fundingPayments = 0;
        uint256 numMarkets = getNumMarkets();
        for (uint256 i = 0; i < numMarkets;) {
            if (!IPausable(address(perpetuals[id[i]])).paused()) {
                fundingPayments +=
                    perpetuals[id[i]].settleTraderFunding(account) + perpetuals[id[i]].settleLpFunding(account);
            }

            unchecked {
                ++i;
            }
        }

        if (fundingPayments != 0) {
            vault.settlePnL(account, fundingPayments);
        }
    }

    /// @notice Distribute LP rewards
    function _distributeLpRewards(uint256 idx, address lp) internal {
        if (address(rewardContract) != address(0)) rewardContract.updatePosition(address(perpetuals[idx]), lp);
    }

    /* ****************** */
    /*   Internal getter  */
    /* ****************** */

    function _isOpenNotionalRequirementValid(uint256 idx, address account, bool isTrader)
        internal
        view
        returns (bool)
    {
        int256 openNotional =
            isTrader ? _getTraderPosition(idx, account).openNotional : _getLpOpenNotional(idx, account);
        uint256 absOpenNotional = openNotional.abs().toUint256();

        // we don't want the check to fail if the position has been closed (e.g. in `reducePosition`)
        if (absOpenNotional > 0) {
            return absOpenNotional >= minPositiveOpenNotional;
        }

        return true;
    }

    function _isPositionValid(address account, int256 ratio) internal view returns (bool) {
        return getFreeCollateralByRatio(account, ratio) >= 0;
    }

    function _getReserveValue(address account, bool isDiscounted) internal view returns (int256) {
        return vault.getReserveValue(account, isDiscounted);
    }

    function _getTraderPosition(uint256 idx, address account)
        internal
        view
        returns (LibPerpetual.TraderPosition memory)
    {
        return perpetuals[idx].getTraderPosition(account);
    }

    function _getLpLiquidity(uint256 idx, address account) internal view returns (uint256) {
        return perpetuals[idx].getLpLiquidity(account);
    }

    function _getLpOpenNotional(uint256 idx, address account) internal view returns (int256) {
        return perpetuals[idx].getLpOpenNotional(account);
    }
}
