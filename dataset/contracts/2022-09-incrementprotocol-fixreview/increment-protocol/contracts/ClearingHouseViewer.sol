// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.16;

// contracts
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

// interfaces
import {IERC20Metadata} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IClearingHouse} from "./interfaces/IClearingHouse.sol";
import {IClearingHouseViewer} from "./interfaces/IClearingHouseViewer.sol";
import {ICryptoSwap} from "./interfaces/ICryptoSwap.sol";
import {ICurveCryptoViews} from "./interfaces/ICurveCryptoViews.sol";

import {IPerpetual} from "./interfaces/IPerpetual.sol";

// libraries
import {LibMath} from "./lib/LibMath.sol";
import {LibPerpetual} from "./lib/LibPerpetual.sol";

/// @title Clearing House Helper Contract
/// @notice Utility functions to easily extract data from Perpetual Contracts
contract ClearingHouseViewer is IClearingHouseViewer {
    using LibMath for uint256;
    using LibMath for int256;
    using SafeERC20 for IERC20Metadata;

    // constants
    uint256 internal constant VQUOTE_INDEX = 0; // index of quote asset in curve pool
    uint256 internal constant VBASE_INDEX = 1; // index of base asset in curve pool

    // dependencies
    IClearingHouse public override clearingHouse;

    constructor(IClearingHouse _clearingHouse) {
        if (address(_clearingHouse) == address(0)) revert ClearingHouseViewer_ZeroAddressConstructor(0);
        clearingHouse = _clearingHouse;
    }

    /* ****************** */
    /*   Market viewer    */
    /* ****************** */

    /// @notice Return amount for vBase one would receive for exchanging `vQuoteAmountToSpend` in a select market (excluding slippage)
    /// @dev It's up to the client to apply a reduction of this amount (e.g. -1%) to then use it as a reasonable value for `minAmount` in `extendPosition`
    /// @param idx Index of the perpetual market
    /// @param vQuoteAmountToSpend Amount of vQuote to be exchanged against some vBase. 18 decimals
    function getExpectedVBaseAmountExFees(uint256 idx, uint256 vQuoteAmountToSpend) public view returns (uint256) {
        return clearingHouse.perpetuals(idx).curveCryptoViews().get_dy_no_fee_deduct(
            getMarket(idx), VQUOTE_INDEX, VBASE_INDEX, vQuoteAmountToSpend
        );
    }

    /// @notice Return amount for vQuote one would receive for exchanging `vBaseAmountToSpend` in a select market (excluding slippage)
    /// @dev It's up to the client to apply a reduction of this amount (e.g. -1%) to then use it as a reasonable value for `minAmount` in `extendPosition`
    /// @param idx Index of the perpetual market
    /// @param vBaseAmountToSpend Amount of vBase to be exchanged against some vQuote. 18 decimals
    function getExpectedVQuoteAmountExFees(uint256 idx, uint256 vBaseAmountToSpend) external view returns (uint256) {
        return clearingHouse.perpetuals(idx).curveCryptoViews().get_dy_no_fee_deduct(
            getMarket(idx), VBASE_INDEX, VQUOTE_INDEX, vBaseAmountToSpend
        );
    }

    function getExpectedVQuoteAmountToReceiveExFees(uint256 idx, uint256 vBaseAmountToReceive)
        public
        view
        returns (uint256)
    {
        return clearingHouse.perpetuals(idx).curveCryptoViews().get_dx_ex_fees(
            getMarket(idx), VQUOTE_INDEX, VBASE_INDEX, vBaseAmountToReceive
        );
    }

    function getExpectedVBaseToReceiveAmountExFees(uint256 idx, uint256 vQuoteAmountToReceive)
        public
        view
        returns (uint256)
    {
        return clearingHouse.perpetuals(idx).curveCryptoViews().get_dx_ex_fees(
            getMarket(idx), VQUOTE_INDEX, VBASE_INDEX, vQuoteAmountToReceive
        );
    }

    /// @notice Return amount for vBase / vQuote one would receive for exchanging `proposedAmount` in a select market (excluding slippage)
    /// @dev Wrapper around getExpectedVBaseAmount and getExpectedVQuoteAmount
    /// @param idx Index of the perpetual market
    /// @param proposedAmount Amount of vQuote/vBAse to trade in. 18 decimals
    /// @param direction If Long, vQuote should be traded for vBase otherwise vBase should be traded for vQuote
    /// @return proceeds received from the curve pool after fees applied
    function getTraderDy(uint256 idx, uint256 proposedAmount, LibPerpetual.Side direction)
        public
        view
        returns (uint256)
    {
        if (direction == LibPerpetual.Side.Long) {
            return getExpectedVBaseAmount(idx, proposedAmount);
        } else {
            return getExpectedVQuoteAmount(idx, proposedAmount);
        }
    }

    /// @notice Return amount for vBase one would receive for exchanging `vQuoteAmountToSpend` in a select market (excluding slippage)
    /// @dev It's up to the client to apply a reduction of this amount (e.g. -1%) to then use it as a reasonable value for `minAmount` in `extendPosition`
    /// @param idx Index of the perpetual market
    /// @param vQuoteAmountToSpend Amount of vQuote to be exchanged against some vBase. 18 decimals
    function getExpectedVBaseAmount(uint256 idx, uint256 vQuoteAmountToSpend) public view override returns (uint256) {
        return clearingHouse.perpetuals(idx).market().get_dy(VQUOTE_INDEX, VBASE_INDEX, vQuoteAmountToSpend);
    }

    /// @notice Return amount for vQuote one would receive for exchanging `vBaseAmountToSpend` in a select market (excluding slippage)
    /// @dev It's up to the client to apply a reduction of this amount (e.g. -1%) to then use it as a reasonable value for `minAmount` in `extendPosition`
    /// @param idx Index of the perpetual market
    /// @param vBaseAmountToSpend Amount of vBase to be exchanged against some vQuote. 18 decimals
    function getExpectedVQuoteAmount(uint256 idx, uint256 vBaseAmountToSpend) public view override returns (uint256) {
        return clearingHouse.perpetuals(idx).market().get_dy(VBASE_INDEX, VQUOTE_INDEX, vBaseAmountToSpend);
    }

    /// @notice Return amount of LP tokens one would receive from exchanging `amounts` in a selected market
    /// @dev Given that the estimated amount might be slightly off (slippage) and that the market may move a bit
    ///      between this call and the next, users should apply a small reduction on the returned amount.
    /// @param idx Index of the perpetual market
    /// @param amounts Array of 2 amounts, a vQuote and a vBase amount
    function getExpectedLpTokenAmount(uint256 idx, uint256[2] calldata amounts)
        external
        view
        override
        returns (uint256)
    {
        return clearingHouse.perpetuals(idx).market().calc_token_amount(amounts);
    }

    /// @notice Return estimation of quote and base tokens one LP should get in exchange for LP tokens
    /// @dev Apply a small reduction to the token amounts to ensure that the call to `removeLiquidity` passes
    /// @dev Does not burn the fee proportion of the lp tokens
    /// @param idx Index of the perpetual market
    /// @param account Address of the LP account
    /// @param lpTokenAmountToWithdraw Amount of LP tokens to return to the market
    function getExpectedVirtualTokenAmountsFromLpTokenAmount(
        uint256 idx,
        address account,
        uint256 lpTokenAmountToWithdraw
    ) external view override returns (uint256[2] memory) {
        if (getLpPosition(idx, account).liquidityBalance < lpTokenAmountToWithdraw) {
            revert ClearingHouseViewer_LpTokenAmountPassedLargerThanBalance();
        }

        uint256 lpTotalSupply = totalLpTokenSupply(idx);

        uint256 eQuoteTokenWithdrawn = (
            (lpTokenAmountToWithdraw - 1) * clearingHouse.perpetuals(idx).market().balances(VQUOTE_INDEX)
        ) / lpTotalSupply;

        uint256 eBaseTokenWithdrawn = (
            (lpTokenAmountToWithdraw - 1) * clearingHouse.perpetuals(idx).market().balances(VBASE_INDEX)
        ) / lpTotalSupply;

        return [eQuoteTokenWithdrawn, eBaseTokenWithdrawn];
    }

    /// @notice Return the last traded price (used for TWAP)
    /// @param idx Index of the perpetual market
    function marketPrice(uint256 idx) public view override returns (uint256) {
        return clearingHouse.perpetuals(idx).marketPrice();
    }

    /// @notice Return the current off-chain exchange rate for vBase/vQuote
    /// @param idx Index of the perpetual market
    function indexPrice(uint256 idx) public view override returns (int256) {
        return clearingHouse.perpetuals(idx).indexPrice();
    }

    /// @notice Return the total supply of LP tokens in the market
    /// @param idx Index of the perpetual market
    function totalLpTokenSupply(uint256 idx) public view override returns (uint256) {
        return IERC20Metadata(clearingHouse.perpetuals(idx).market().token()).totalSupply();
    }

    /// @notice Return a the GlobalPosition struct of a given market
    /// @param idx Index of the perpetual market
    function getGlobalPosition(uint256 idx) public view override returns (LibPerpetual.GlobalPosition memory) {
        return clearingHouse.perpetuals(idx).getGlobalPosition();
    }

    /// @notice Return the address of the curve market from a perpetual index
    /// @param idx Index of the perpetual market
    function getMarket(uint256 idx) public view override returns (ICryptoSwap) {
        return clearingHouse.perpetuals(idx).market();
    }

    /// @notice Return the address of the curve market from a perpetual index
    /// @param idx Index of the perpetual market
    function perpetual(uint256 idx) public view override returns (IPerpetual) {
        return clearingHouse.perpetuals(idx);
    }

    /// @notice Return the insurance fee of a perpetual market
    /// @param idx Index of the perpetual market
    function insuranceFee(uint256 idx) external view override returns (int256) {
        return clearingHouse.perpetuals(idx).insuranceFee();
    }

    /// @notice Return the total supply of base tokens provided to a perpetual market
    /// @param idx Index of the perpetual market
    function getBaseBalance(uint256 idx) external view override returns (uint256) {
        return clearingHouse.perpetuals(idx).vBase().totalSupply();
    }

    /// @notice Return the total supply of quote tokens provided to a perpetual market
    /// @param idx Index of the perpetual market
    function getQuoteBalance(uint256 idx) external view override returns (uint256) {
        return clearingHouse.perpetuals(idx).vQuote().totalSupply();
    }

    /// @notice Return the total supply of liquidity tokens in a perpetual market
    /// @param idx Index of the perpetual market
    function getTotalLiquidityProvided(uint256 idx) public view override returns (uint256) {
        return clearingHouse.perpetuals(idx).getTotalLiquidityProvided();
    }

    /* ****************** */
    /*   User viewer      */
    /* ****************** */

    /// @notice Get free collateral of a user, with a given ratio applied on his debts
    /// @dev free collateral = profit + discounted collaterals USD value
    function getFreeCollateralByRatio(address account, int256 ratio) external view returns (int256 freeCollateral) {
        int256 pnl = clearingHouse.getPnLAcrossMarkets(account);
        int256 fundingPayments = getFundingPaymentsAcrossMarkets(account);

        int256 userDebt = clearingHouse.getDebtAcrossMarkets(account);
        int256 marginRequired = userDebt.wadMul(ratio);

        // if no trading or LP position open on any market, margin ratio is 100%
        if (userDebt == 0) {
            marginRequired = 0;
        }
        int256 reserveValue = getReserveValue(account, false);

        // We define freeCollateral as follows:
        // freeCollateral = min(totalCollateralValue, totalCollateralValue + pnl) - marginRequired)
        // This is a conservative approach when compared to
        // freeCollateral = totalCollateralValue + pnl - marginRequired
        // since the unrealized pnl depends on the index price
        // where a deviation could allow a trader to empty the vault

        return reserveValue.min(reserveValue + pnl) + fundingPayments - marginRequired;
    }

    /// @notice Approximately determine whether or not a position is valid for a given margin ratio
    /// @dev Differ from `ClearingHouse._isPositionValid` in that it includes an estimate of pending funding payments,
    ///      also `_isPositionValid` formula is arranged differently
    /// @param account Account of the position to get the margin ratio from
    /// @param ratio Proposed ratio to compare the position against
    function isMarginValid(address account, int256 ratio) external view override returns (bool) {
        return marginRatio(account) >= ratio;
    }

    /// @notice Get the margin ratio of a user, i.e. all trading and LP positions across all markets
    /// @dev Unlike ClearingHouse.getFreeCollateralByRatio, ClearingHouseViewer.marginRatio includes fundingPayments
    ///      and formula is arranged differently
    /// @param account Account of the position to get the margin ratio from
    function marginRatio(address account) public view override returns (int256) {
        // margin ratio = (collateral + unrealizedPositionPnl) / trader.openNotional
        // all amounts must be expressed in vQuote (e.g. USD), otherwise the end result doesn't make sense

        int256 unrealizedPositionPnl = clearingHouse.getPnLAcrossMarkets(account);
        int256 userDebt = clearingHouse.getDebtAcrossMarkets(account);
        int256 fundingPayments = getFundingPaymentsAcrossMarkets(account);

        // if no trading or LP position open on any market, margin ratio is 100%
        if (userDebt == 0) {
            return 1e18;
        }

        int256 collateral = getReserveValue(account, false);

        return _computeMarginRatio(collateral, unrealizedPositionPnl, fundingPayments, userDebt);
    }

    /// @notice Get the account leverage across markets
    /// @param account User to get the account leverage from
    function accountLeverage(address account) external view override returns (int256) {
        int256 unrealizedPositionPnl = clearingHouse.getPnLAcrossMarkets(account);
        int256 userDebt = clearingHouse.getDebtAcrossMarkets(account);
        int256 fundingPayments = getFundingPaymentsAcrossMarkets(account);

        // if no trading or LP position open on any market, margin ratio is 100%
        if (userDebt == 0) {
            return 0;
        }

        int256 collateral = getReserveValue(account, false);

        return _computeLeverage(collateral, unrealizedPositionPnl, fundingPayments, userDebt);
    }

    /// @notice Get the account leverage for an market
    /// @param idx Index of the perpetual market
    /// @param account User to get the account leverage from
    function marketLeverage(uint256 idx, address account) external view override returns (int256) {
        IPerpetual perp = clearingHouse.perpetuals(idx);
        int256 unrealizedPositionPnl = perp.getPendingPnL(account);
        int256 userDebt = perp.getUserDebt(account).wadMul(perp.riskWeight().toInt256());
        int256 fundingPayments = getFundingPayments(idx, account);

        // if no trading or LP position open on any market, margin ratio is 100%
        if (userDebt == 0) {
            return 0;
        }

        int256 collateral = getReserveValue(account, false);

        return _computeLeverage(collateral, unrealizedPositionPnl, fundingPayments, userDebt);
    }

    /// @notice Get the updated funding payments of an user across all perpetual markets
    /// @param account User to get the funding payments of
    function getFundingPaymentsAcrossMarkets(address account) public view returns (int256 fundingPayments) {
        for (uint256 i = 0; i < clearingHouse.getNumMarkets(); i++) {
            fundingPayments += getFundingPayments(clearingHouse.id(i), account);
        }
    }

    /// @notice Get the updated funding payments of an user one a market
    /// @param idx Index of the perpetual market
    /// @param account User to get the funding payments of
    function getFundingPayments(uint256 idx, address account) public view returns (int256 pendingFunding) {
        LibPerpetual.TraderPosition memory trader = getTraderPosition(idx, account);
        LibPerpetual.LiquidityProviderPosition memory lp = getLpPosition(idx, account);

        (int256 cumFundingRate, int256 cumFundingPerLpToken) = getUpdatedFundingRate(idx);

        return _getTraderFundingPayments(
            trader.positionSize >= 0, trader.cumFundingRate, cumFundingRate, int256(trader.positionSize).abs()
        ) + _getLpFundingPayments(lp.cumFundingPerLpToken, cumFundingPerLpToken, lp.liquidityBalance);
    }

    /// @notice Calculate missed funding payments
    /// @param idx Index of the perpetual market
    /// @param account User to get the funding payments of
    function getTraderFundingPayments(uint256 idx, address account) public view returns (int256 pendingFunding) {
        LibPerpetual.TraderPosition memory trader = getTraderPosition(idx, account);

        (int256 cumFundingRate,) = getUpdatedFundingRate(idx);

        return _getTraderFundingPayments(
            trader.positionSize >= 0, trader.cumFundingRate, cumFundingRate, int256(trader.positionSize).abs()
        );
    }

    /// @notice Calculate missed funding payments
    /// @param idx Index of the perpetual market
    /// @param account User to get the funding payments of
    function getLpFundingPayments(uint256 idx, address account) public view returns (int256 pendingFunding) {
        LibPerpetual.LiquidityProviderPosition memory lp = getLpPosition(idx, account);

        (, int256 cumFundingPerLpToken) = getUpdatedFundingRate(idx);

        return _getLpFundingPayments(lp.cumFundingPerLpToken, cumFundingPerLpToken, lp.liquidityBalance);
    }

    /// @notice Calculate missed funding payments
    /// @param idx Index of the perpetual market
    /// @param account Trader to get the unrealized PnL from
    function getTraderUnrealizedPnL(uint256 idx, address account) external view override returns (int256) {
        if (!isTraderPositionOpen(idx, account)) {
            return 0;
        }

        return clearingHouse.perpetuals(idx).getTraderUnrealizedPnL(account);
    }

    /// @notice Get the portfolio value of a trader / lp
    /// @param account Address to get the portfolio value from
    /// @param isDiscounted Whether or not the reserve value should be discounted by the weight of the collateral
    /// @return reserveValue Value of collaterals in USD. 18 decimals
    function getReserveValue(address account, bool isDiscounted) public view override returns (int256) {
        return clearingHouse.vault().getReserveValue(account, isDiscounted);
    }

    /// @notice Get the withdraw allowance of an account for a given user & token
    /// @param user address of the user to withdraw from
    /// @param receiver address of the receiver of tokens for a withdrawal
    /// @param tokenIdx Index of the token
    function getAllowance(address user, address receiver, uint256 tokenIdx) external view override returns (uint256) {
        return clearingHouse.vault().getAllowance(user, receiver, tokenIdx);
    }

    /// @notice Get User Collateral balance
    /// @param user User to get the balance of
    /// @param tokenIdx Token to get the balance of
    function getBalance(address user, uint256 tokenIdx) external view override returns (int256) {
        return clearingHouse.vault().getBalance(user, tokenIdx);
    }

    /// @notice Get trader position
    /// @param idx Index of the perpetual market
    /// @param account Address to get the trading position from
    function getTraderPosition(uint256 idx, address account)
        public
        view
        override
        returns (LibPerpetual.TraderPosition memory)
    {
        return clearingHouse.perpetuals(idx).getTraderPosition(account);
    }

    /// @notice Whether a given trader position is open
    /// @param idx Index of the perpetual market
    /// @param account Address of the trading account
    function isTraderPositionOpen(uint256 idx, address account) public view override returns (bool) {
        return clearingHouse.perpetuals(idx).isTraderPositionOpen(account);
    }

    /// @notice Whether a given LP position is open
    /// @param idx Index of the perpetual market
    /// @param account Address of the LP account
    function isLpPositionOpen(uint256 idx, address account) public view override returns (bool) {
        return clearingHouse.perpetuals(idx).isLpPositionOpen(account);
    }

    /// @notice Whether any trader/lp position is open
    /// @param account Address of the user account
    function isPositionOpen(address account) external view override returns (bool) {
        uint256 numMarkets = clearingHouse.getNumMarkets();
        for (uint256 i = 0; i < numMarkets;) {
            uint256 idx = clearingHouse.id(i);
            if (isTraderPositionOpen(idx, account) || isLpPositionOpen(idx, account)) return true;

            unchecked {
                ++i;
            }
        }
        return false;
    }

    /// @param idx Index of the perpetual market
    /// @param account Lp to get the unrealized PnL from
    function getLpUnrealizedPnL(uint256 idx, address account) public view override returns (int256) {
        if (!isLpPositionOpen(idx, account)) {
            return 0;
        }

        return clearingHouse.perpetuals(idx).getLpUnrealizedPnL(account);
    }

    /// @param idx Index of the perpetual market
    /// @param account Lp to get the trading fees earned from
    /// @return tradingFeesEarned Trading fees earned by the Liquidity Provider. 18 decimals
    function getLpTradingFees(uint256 idx, address account) public view override returns (uint256) {
        if (!isLpPositionOpen(idx, account)) {
            return 0;
        }

        return clearingHouse.perpetuals(idx).getLpTradingFees(account);
    }

    /// @notice Get the unrealized profit and Loss and the trading fees earned of a  Liquidity Provider
    /// @param  account Lp to get the pnl and trading fees earned from
    /// @return pnl Unrealized profit and loss and trading fees earned. 18 decimals
    function getLpEstimatedPnl(uint256 idx, address account) external view override returns (int256) {
        if (!isLpPositionOpen(idx, account)) {
            return 0;
        }

        return getLpUnrealizedPnL(idx, account) + getLpTradingFees(idx, account).toInt256();
    }

    /// @notice Get the (active) position of a liquidity provider after withdrawing liquidity
    /// @param account Liquidity Provider
    /// @return (Active) Liquidity Provider position
    function getLpPositionAfterWithdrawal(uint256 idx, address account)
        public
        view
        override
        returns (LibPerpetual.TraderPosition memory)
    {
        return clearingHouse.perpetuals(idx).getLpPositionAfterWithdrawal(account);
    }

    /// @notice Get Lp position
    /// @param idx Index of the perpetual market
    /// @param account Address to get the LP position from
    function getLpPosition(uint256 idx, address account)
        public
        view
        override
        returns (LibPerpetual.LiquidityProviderPosition memory)
    {
        return clearingHouse.perpetuals(idx).getLpPosition(account);
    }

    /// @notice Get the current (base) dust balance
    /// @return Base balance of Governance. 18 decimals
    function getBaseDust(uint256 idx) external view override returns (int256) {
        return getTraderPosition(idx, address(clearingHouse)).positionSize;
    }

    /// @notice Get the proposed amount needed to close a trader position
    /// @dev Static Wrapper around getTraderProposedAmountStruct
    /// @param idx Index of the perpetual market
    /// @param user Account
    /// @param reductionRatio Percentage of the position that the user wishes to close. Min: 0. Max: 1e18
    /// @param iter Maximum iterations
    /// @param minAmount Minimum amount that the user is willing to accept. 18 decimals
    /// @return proposedAmount Amount of tokens to swap. 18 decimals
    function getTraderProposedAmount(uint256 idx, address user, uint256 reductionRatio, uint256 iter, uint256 minAmount)
        external
        view
        returns (uint256 proposedAmount)
    {
        // slither-disable-next-line missing-zero-check,low-level-calls
        (bool status, bytes memory value) = address(this).staticcall(
            abi.encodeCall(
                this.getTraderProposedAmountStruct,
                TraderProposedAmountArgs(idx, user, reductionRatio, iter, minAmount, 1e17)
            )
        );

        // bubble up error message
        if (!status) {
            // slither-disable-next-line assembly
            assembly {
                revert(add(value, 0x20), mload(value))
            }
        }

        return uint256(bytes32(value));
    }

    function getTraderProposedAmountStruct(TraderProposedAmountArgs calldata args)
        external
        returns (uint256 proposedAmount)
    {
        int256 positionSize = getTraderPosition(args.idx, args.user).positionSize;

        if (args.reductionRatio > 1e18) revert ClearingHouseViewer_ReductionRatioTooLarge();
        int256 targetPositionSize = positionSize.wadMul(args.reductionRatio.toInt256());

        uint256 dy = 0;
        if (positionSize >= 0) {
            proposedAmount = targetPositionSize.toUint256();
        } else {
            uint256 targetPositionAbs = (-targetPositionSize).toUint256();

            // initial estimate
            proposedAmount = getExpectedVBaseToReceiveAmountExFees(args.idx, targetPositionAbs);
            dy = getExpectedVBaseAmountExFees(args.idx, proposedAmount);

            // binary search as fallback
            int256 netBasePosition = dy.toInt256() + targetPositionSize;
            if (netBasePosition.wadMul(indexPrice(args.idx)).abs().toUint256() > args.precision) {
                bytes memory getDyCall = abi.encodeCall(
                    ICurveCryptoViews.get_dy_no_fee_deduct,
                    (getMarket(args.idx), VQUOTE_INDEX, VBASE_INDEX, proposedAmount) // proposed amount is looped over in binary search
                );

                proposedAmount = this.binarySearch(
                    address(clearingHouse.perpetuals(args.idx).curveCryptoViews()),
                    getDyCall,
                    targetPositionAbs,
                    proposedAmount,
                    args.iter
                );
            }
        }

        dy = clearingHouse.perpetuals(args.idx).curveCryptoViews().get_dy_no_fee_deduct(
            getMarket(args.idx),
            positionSize >= 0 ? VBASE_INDEX : VQUOTE_INDEX,
            positionSize >= 0 ? VQUOTE_INDEX : VBASE_INDEX,
            proposedAmount
        );

        // so proposed amount function can not be frontun
        if (dy < args.minAmount) revert("Amount is too small");

        return proposedAmount;
    }

    /// @notice Get the proposed amount needed to close a LP position
    function getLpProposedAmount(
        uint256 idx,
        address user,
        uint256 reductionRatio,
        uint256 iter,
        uint256[2] calldata minVTokenAmounts,
        uint256 minAmount
    ) external override returns (uint256 proposedAmount) {
        return this.getLpProposedAmountStruct(
            LpProposedAmountArgs(idx, user, reductionRatio, iter, minVTokenAmounts, minAmount, 1e17)
        );
    }

    // use structure to avoid any stack too deep errors
    function getLpProposedAmountStruct(LpProposedAmountArgs calldata args)
        external
        override
        returns (uint256 proposedAmount)
    {
        int256 positionSize = getLpPositionAfterWithdrawal(args.idx, args.user).positionSize;

        if (args.reductionRatio > 1e18) revert ClearingHouseViewer_ReductionRatioTooLarge();
        int256 targetPositionSize = positionSize.wadMul(args.reductionRatio.toInt256());

        uint256 liquidityAmountToRemove =
            uint256(getLpPosition(args.idx, args.user).liquidityBalance).wadMul(args.reductionRatio);
        if (targetPositionSize >= 0) {
            proposedAmount = targetPositionSize.toUint256();
        } else {
            // initial estimate
            proposedAmount = getLpDx(args.idx, args.user, args.reductionRatio, args.minVTokenAmounts);
            uint256 dy = getLpDy(args.idx, args.user, args.reductionRatio, args.minVTokenAmounts, proposedAmount);

            // binary search as fallback
            int256 netBasePosition = dy.toInt256() + targetPositionSize;
            if (netBasePosition.wadMul(indexPrice(args.idx)).abs().toUint256() >= args.precision) {
                bytes memory getDyCall = abi.encodeCall(
                    ICurveCryptoViews.get_dy_no_fee_deduct,
                    (getMarket(args.idx), VQUOTE_INDEX, VBASE_INDEX, proposedAmount) // proposed amount is looped over in binary search
                );
                bytes memory removeLiquidityCall = abi.encodeCall(
                    IPerpetual.removeLiquiditySwap,
                    (args.user, liquidityAmountToRemove, args.minVTokenAmounts, getDyCall)
                );

                proposedAmount = this.binarySearch(
                    address(clearingHouse.perpetuals(args.idx)),
                    removeLiquidityCall,
                    proposedAmount,
                    targetPositionSize.abs().toUint256(),
                    args.iter
                );
            }
        }
        uint256 out = removeLiquiditySwap(
            args.idx,
            args.user,
            liquidityAmountToRemove,
            args.minVTokenAmounts,
            proposedAmount,
            targetPositionSize > 0 ? LibPerpetual.Side.Short : LibPerpetual.Side.Long,
            false
        );

        // so proposed amount function can not be frontun
        if (out < args.minAmount) revert("Amount is too small");

        return proposedAmount;
    }

    /// @notice ONLY STATIC CALL
    /// @notice Returns amount of swapping after removing liquidity
    /// @notice Used to estimate proposedAmount for removing liquidity
    /// @dev Wrapper around removeLiquiditySwap
    /// @param idx Index of the perpetual market
    /// @param user Account
    /// @param reductionRatio Percentage of the position that the user wishes to close. Min: 0. Max: 1e18
    /// @param minVTokenAmounts Minimum amount of virtual tokens [vQuote, vBase] withdrawn from the curve pool. 18 decimals
    /// @param proposedAmount Amount at which to get the LP position (in vBase if LONG, in vQuote if SHORT). 18 decimals
    function getLpDy(
        uint256 idx,
        address user,
        uint256 reductionRatio,
        uint256[2] calldata minVTokenAmounts,
        uint256 proposedAmount
    ) public returns (uint256 proceeds) {
        int256 positionSize = getLpPositionAfterWithdrawal(idx, user).positionSize;
        uint256 liquidityAmountToRemove = uint256(getLpPosition(idx, user).liquidityBalance).wadMul(reductionRatio);
        return removeLiquiditySwap(
            idx,
            user,
            liquidityAmountToRemove,
            minVTokenAmounts,
            proposedAmount,
            positionSize > 0 ? LibPerpetual.Side.Short : LibPerpetual.Side.Long,
            false
        );
    }

    /* ******************** */
    /*    Static Helpers    */
    /* ******************** */

    /// @notice Returns the updated TWAPs
    /// @dev Needed as the global state is only updated by users / keeper
    /// @dev Re-implementation of of Perpetual._updateTwap
    /// @param idx Index of the perpetual market
    /// @return oracleTwap Oracle / Index Time Weighted Average Price
    /// @return marketTwap Market Time Weighted Average Price
    function getUpdatedTwap(uint256 idx) public view returns (int256 oracleTwap, int256 marketTwap) {
        uint256 currentTime = block.timestamp;
        LibPerpetual.GlobalPosition memory globalPosition = getGlobalPosition(idx);

        uint256 timeElapsedSinceBeginningOfPeriod = block.timestamp - globalPosition.timeOfLastTwapUpdate;

        if (timeElapsedSinceBeginningOfPeriod >= perpetual(idx).twapFrequency()) {
            // update intermediary input
            // @dev: reference the perpetual contract for more details
            int256 timeElapsed = (currentTime - globalPosition.timeOfLastTrade).toInt256();

            int256 latestChainlinkPrice = indexPrice(idx);
            int256 oracleCumulativeAmount = perpetual(idx).oracleCumulativeAmount() + latestChainlinkPrice * timeElapsed;

            int256 latestMarketPrice = marketPrice(idx).toInt256();
            int256 marketCumulativeAmount = perpetual(idx).marketCumulativeAmount() + latestMarketPrice * timeElapsed;

            // update twap
            oracleTwap = (oracleCumulativeAmount - perpetual(idx).oracleCumulativeAmountAtBeginningOfPeriod())
                / timeElapsedSinceBeginningOfPeriod.toInt256();

            marketTwap = (marketCumulativeAmount - perpetual(idx).marketCumulativeAmountAtBeginningOfPeriod())
                / timeElapsedSinceBeginningOfPeriod.toInt256();
        } else {
            oracleTwap = perpetual(idx).oracleTwap();
            marketTwap = perpetual(idx).marketTwap();
        }
    }

    /// @notice Returns the updated funding rate
    /// @dev Needed as the global state is only updated by users / keeper
    /// @dev Re-implementation of of Perpetual._updateFundingRate
    /// @param idx Index of the perpetual market
    /// @return cumFundingRate Cumulative funding rate
    /// @return cumFundingPerLpToken Cumulative funding per LP token
    function getUpdatedFundingRate(uint256 idx)
        public
        view
        returns (int256 cumFundingRate, int256 cumFundingPerLpToken)
    {
        LibPerpetual.GlobalPosition memory globalPosition = getGlobalPosition(idx);
        uint256 currentTime = block.timestamp;

        if (currentTime > globalPosition.timeOfLastTrade) {
            (int256 oracleTwap, int256 marketTwap) = getUpdatedTwap(idx);

            int256 currentTraderPremium = marketTwap - oracleTwap;
            int256 timePassedSinceLastTrade = (currentTime - globalPosition.timeOfLastTrade).toInt256();

            int256 fundingRate =
                ((perpetual(idx).sensitivity().wadMul(currentTraderPremium) * timePassedSinceLastTrade) / 1 days); // @dev: in fixed number x seconds / seconds = fixed number

            cumFundingRate = globalPosition.cumFundingRate + fundingRate;

            int256 tokenSupply =
                getTotalLiquidityProvided(idx).toInt256() > 0 ? getTotalLiquidityProvided(idx).toInt256() : int256(1e18);

            int256 totalTraderPositionSize =
                uint256(globalPosition.traderLongs).toInt256() - uint256(globalPosition.traderShorts).toInt256();

            cumFundingPerLpToken += totalTraderPositionSize > 0
                ? -fundingRate.wadMul(totalTraderPositionSize).wadDiv(tokenSupply) // long pay funding
                : fundingRate.wadMul(totalTraderPositionSize).wadDiv(tokenSupply); // short receives funding
        } else {
            cumFundingRate = globalPosition.cumFundingRate;
            cumFundingPerLpToken = globalPosition.cumFundingPerLpToken;
        }
    }

    function getLpDx(uint256 idx, address user, uint256 reductionRatio, uint256[2] calldata minVTokenAmounts)
        public
        returns (uint256 proceeds)
    {
        int256 positionSize = getLpPositionAfterWithdrawal(idx, user).positionSize;
        uint256 liquidityAmountToRemove = uint256(getLpPosition(idx, user).liquidityBalance).wadMul(reductionRatio);

        bytes memory innerCall = abi.encodeCall(
            ICurveCryptoViews.get_dx_ex_fees,
            (getMarket(idx), VQUOTE_INDEX, VBASE_INDEX, positionSize.abs().toUint256())
        );

        try clearingHouse.perpetuals(idx).removeLiquiditySwap(
            user, liquidityAmountToRemove, minVTokenAmounts, innerCall
        ) {
            // slither-disable-next-line uninitialized-local,variable-scope
        } catch (bytes memory errorMessage) {
            // slither-disable-next-line variable-scope
            return abi.decode(errorMessage, (uint256));
        }
    }

    /* ******************** */
    /*    Static Helpers    */
    /* ******************** */
    /* ******************** */
    /*    Static Helpers    */
    /* ******************** */

    /// @notice ONLY STATIC CALL
    /// @notice Returns amount of swapping after removing liquidity
    /// @notice Used to estimate proposedAmount for removing liquidity
    /// @param idx Index of the perpetual market
    /// @param liquidityAmountToRemove Amount of liquidity (in LP tokens) to be removed from the pool. 18 decimals
    /// @param minVTokenAmounts Minimum amount of virtual tokens [vQuote, vBase] withdrawn from the curve pool. 18 decimals
    /// @param proposedAmount Amount at which to get the LP position (in vBase if LONG, in vQuote if SHORT). 18 decimals
    /// @param direction If Long, vQuote should be traded for vBase otherwise vBase should be traded for vQuote
    /// @param withCurveTradingFees Whether or not Curve trading fees should be included
    /// @return proceeds received from swapping after removing liquidity
    function removeLiquiditySwap(
        uint256 idx,
        address user,
        uint256 liquidityAmountToRemove,
        uint256[2] calldata minVTokenAmounts,
        uint256 proposedAmount,
        LibPerpetual.Side direction,
        bool withCurveTradingFees
    ) public override returns (uint256 proceeds) {
        bytes memory encodedCall = abi.encodeCall(
            withCurveTradingFees ? ICurveCryptoViews.get_dy_no_fee_deduct : ICurveCryptoViews.get_dy,
            (
                getMarket(idx),
                direction == LibPerpetual.Side.Long ? VQUOTE_INDEX : VBASE_INDEX,
                direction == LibPerpetual.Side.Long ? VBASE_INDEX : VQUOTE_INDEX,
                proposedAmount
            )
        );

        try clearingHouse.perpetuals(idx).removeLiquiditySwap(
            user, liquidityAmountToRemove, minVTokenAmounts, encodedCall
        ) {
            // slither-disable-next-line uninitialized-local,variable-scope
        } catch (bytes memory errorMessage) {
            // slither-disable-next-line variable-scope
            return abi.decode(errorMessage, (uint256));
        }
    }

    /* ****************** */
    /*   Internal util  */
    /* ****************** */

    function binarySearch(
        address targetContract,
        bytes calldata data,
        uint256 proposedAmount, // initial estimate
        uint256 target,
        uint256 iter
    ) public returns (uint256) {
        // binary search in [initialEstimate * 0.5, initialEstimate * 1.5]
        uint256 maxVal = (proposedAmount * 15) / 10;
        uint256 minVal = (proposedAmount * 5) / 10;
        uint256 amountOut;

        bytes memory sliced = data[0:data.length - 32 - 28];

        // find the best estimate with binary search
        for (uint256 i = 0; i < iter;) {
            /*

            Data has the following layout

            .                                ┐
            .                                │
            4 bytes of function selector     │ sliced
            .                                │
            .                                ┘

            32 bytes for proposed amount     ┐
                                             │ appended
            28 bytes for padding             ┘

            We must replace the proposed amount and keep the padding.


           */

            proposedAmount = (maxVal + minVal) / 2;

            // slither-disable-next-line missing-zero-check,low-level-calls
            (bool status, bytes memory result) =
                targetContract.call(bytes.concat(sliced, bytes32(proposedAmount), bytes28(0)));

            amountOut = abi.decode(result, (uint256));

            if (status) revert("binary search call should have failed");

            if (amountOut == target) {
                break;
            } else if (amountOut < target) {
                minVal = proposedAmount;
            } else {
                maxVal = proposedAmount;
            }

            unchecked {
                ++i;
            }
        }

        return proposedAmount;
    }

    /* ****************** */
    /*   Internal viewer  */
    /* ****************** */
    function _computeMarginRatio(
        int256 collateral,
        int256 unrealizedPositionPnl,
        int256 fundingPayments,
        int256 userDebt
    ) internal pure returns (int256) {
        return (collateral + unrealizedPositionPnl.min(0) + fundingPayments).wadDiv(userDebt.abs());
    }

    function _computeLeverage(int256 collateral, int256 unrealizedPositionPnl, int256 fundingPayments, int256 userDebt)
        internal
        pure
        returns (int256)
    {
        return (userDebt.abs()).wadDiv(collateral + unrealizedPositionPnl.min(0) + fundingPayments);
    }

    /// @notice Calculate missed funding payments
    function _getTraderFundingPayments(
        bool isLong,
        int256 userCumFundingRate,
        int256 globalCumFundingRate,
        int256 vBaseAmountToSettle
    ) internal pure returns (int256 upcomingFundingPayment) {
        /* Funding rates (as defined in our protocol) are paid from longs to shorts

            case 1: user is long  => has missed making funding payments (positive or negative)
            case 2: user is short => has missed receiving funding payments (positive or negative)

            comment: Making an negative funding payment is equivalent to receiving a positive one.
        */
        if (userCumFundingRate != globalCumFundingRate) {
            int256 upcomingFundingRate =
                isLong ? userCumFundingRate - globalCumFundingRate : globalCumFundingRate - userCumFundingRate;

            // fundingPayments = fundingRate * vBaseAmountToSettle * basePrice
            upcomingFundingPayment = upcomingFundingRate.wadMul(vBaseAmountToSettle);
        }
    }

    function _getLpFundingPayments(
        int256 userCumFundingPerLpToken,
        int256 globalCumFundingPerLpToken,
        uint256 userLiquidityBalance
    ) internal pure returns (int256 upcomingFundingPayment) {
        upcomingFundingPayment =
            (globalCumFundingPerLpToken - userCumFundingPerLpToken).wadMul(userLiquidityBalance.toInt256());
    }
}
