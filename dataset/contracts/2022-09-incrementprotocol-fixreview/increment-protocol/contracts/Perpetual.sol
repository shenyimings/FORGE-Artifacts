// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.16;

// contracts
import {Pausable} from "../lib/openzeppelin-contracts/contracts/security/Pausable.sol";
import {IncreAccessControl} from "./utils/IncreAccessControl.sol";

// interfaces
import {IPerpetual} from "./interfaces/IPerpetual.sol";
import {IVBase} from "./interfaces/IVBase.sol";
import {IVQuote} from "./interfaces/IVQuote.sol";
import {ICryptoSwap} from "./interfaces/ICryptoSwap.sol";
import {IClearingHouse} from "./interfaces/IClearingHouse.sol";
import {ICurveCryptoViews} from "./interfaces/ICurveCryptoViews.sol";
import {IERC20Metadata} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// libraries
import {LibMath} from "./lib/LibMath.sol";
import {LibPerpetual} from "./lib/LibPerpetual.sol";

/// @notice Handle all the logic involving the pool. Interact with the CryptoSwap pool
contract Perpetual is IPerpetual, Pausable, IncreAccessControl {
    using LibMath for int256;
    using LibMath for uint256;

    // constants
    uint256 internal constant VQUOTE_INDEX = 0; // index of quote asset in curve pool
    uint256 internal constant VBASE_INDEX = 1; // index of base asset in curve pool
    uint256 internal constant CURVE_TRADING_FEE_DECIMALS = 10; // curve trading fee decimals

    // parameters

    /// @notice wether opening and extending trading positions is allowed
    bool public override isTradingExpansionAllowed;

    /// @notice risk weight of the perpetual pair
    uint256 public override riskWeight;

    /// @notice maximum liquidity which can be provided to the pool
    uint256 public override maxLiquidityProvided;

    /// @notice period over which twap is calculated
    uint256 public override twapFrequency;

    /// @notice funding rate sensitivity to price deviations
    int256 public override sensitivity;

    /// @notice paid on dollar value of an opened position (used in ClearingHouse)
    int256 public override insuranceFee;

    /// @notice lp debt coefficient
    int256 public override lpDebtCoef;

    /// @notice max trade amount in one block
    uint256 public override maxBlockTradeAmount;

    /// @notice max position size (1/10 of maxBlockTradeAmount)
    uint256 public override maxPosition;

    /// @notice time when the liquidity provision has to be locked
    uint256 public override lockPeriod;

    // dependencies

    /// @notice vBase token (traded on CryptoSwap pool)
    IVBase public override vBase;

    /// @notice vQuote token (traded on CryptoSwap pool)
    IVQuote public override vQuote;

    /// @notice Clearing House contract
    IClearingHouse public override clearingHouse;

    /// @notice Curve CryptoSwap pool
    ICryptoSwap public override market;

    /// @notice Curve Crypto Views
    ICurveCryptoViews public override curveCryptoViews;

    // global state
    LibPerpetual.GlobalPosition internal globalPosition;

    // public state

    /// @dev: share storage slot

    /// @notice Oracle Time-weighted average price of base
    int128 public override oracleTwap;

    /// @notice Market Time-weighted average price of base
    int128 public override marketTwap;

    // internal state
    int256 public override oracleCumulativeAmount;
    int256 public override oracleCumulativeAmountAtBeginningOfPeriod;
    int256 public override marketCumulativeAmount;
    // slither-disable-next-line similar-names
    int256 public override marketCumulativeAmountAtBeginningOfPeriod;

    // user state
    mapping(address => LibPerpetual.TraderPosition) internal traderPosition;
    mapping(address => LibPerpetual.LiquidityProviderPosition) internal lpPosition;

    constructor(
        IVBase _vBase,
        IVQuote _vQuote,
        ICryptoSwap _market,
        IClearingHouse _clearingHouse,
        ICurveCryptoViews _views,
        bool _isTradingExpansionAllowed,
        PerpetualParams memory _params
    ) {
        if (address(_vBase) == address(0)) revert Perpetual_ZeroAddressConstructor(0);
        if (address(_vQuote) == address(0)) revert Perpetual_ZeroAddressConstructor(1);
        if (address(_market) == address(0)) revert Perpetual_ZeroAddressConstructor(2);
        if (address(_clearingHouse) == address(0)) revert Perpetual_ZeroAddressConstructor(3);
        if (address(_views) == address(0)) revert Perpetual_ZeroAddressConstructor(4);

        vBase = _vBase;
        vQuote = _vQuote;
        market = _market;
        clearingHouse = _clearingHouse;
        curveCryptoViews = _views;

        // approve all future transfers between Perpetual and market (curve pool)
        if (!vBase.approve(address(_market), type(uint256).max)) {
            revert Perpetual_VirtualTokenApprovalConstructor(VBASE_INDEX);
        }
        if (!vQuote.approve(address(_market), type(uint256).max)) {
            revert Perpetual_VirtualTokenApprovalConstructor(VQUOTE_INDEX);
        }

        // expected to be false to block trading operations till admin role activates them,
        // except for test deployments
        isTradingExpansionAllowed = _isTradingExpansionAllowed;

        // initialize global state
        // @dev: initiate the pool with the last_price
        _initGlobalState(_vBase.getIndexPrice(), _market.last_prices().toInt256());

        setParameters(
            PerpetualParams({
                riskWeight: _params.riskWeight,
                maxLiquidityProvided: _params.maxLiquidityProvided,
                twapFrequency: _params.twapFrequency,
                sensitivity: _params.sensitivity,
                maxBlockTradeAmount: _params.maxBlockTradeAmount,
                insuranceFee: _params.insuranceFee,
                lpDebtCoef: _params.lpDebtCoef,
                lockPeriod: _params.lockPeriod
            })
        );

        if (market.admin_fee() != 0) revert Perpetual_InvalidAdminFee();
    }

    modifier onlyClearingHouse() {
        if (msg.sender != address(clearingHouse)) revert Perpetual_SenderNotClearingHouse();
        _;
    }

    /* ****************** */
    /*   Trader flow      */
    /* ****************** */

    /// @notice Open or increase or reduce a position, either LONG or SHORT
    /// @dev Function can be used to extend or reduce a position. Reversing a position is prohibited.
    /// @param account Trader
    /// @param amount Amount in vQuote (if LONG) or vBase (if SHORT) to sell. 18 decimals
    /// @param minAmount Minimum amount that the user is willing to accept. 18 decimals
    /// @param direction Whether the trader wants to go in the LONG or SHORT direction overall
    /// @param isLiquidation Transaction is a liquidation (true) or a regular transaction (false)
    function changePosition(
        address account,
        uint256 amount,
        uint256 minAmount,
        LibPerpetual.Side direction,
        bool isLiquidation
    )
        external
        override
        whenNotPaused
        onlyClearingHouse
        returns (
            int256 quoteProceeds,
            int256 baseProceeds,
            int256 profit,
            int256 tradingFeesPayed,
            bool isPositionIncreased,
            bool isPositionClosed
        )
    {
        LibPerpetual.TraderPosition storage trader = traderPosition[account];

        int256 traderPositionSize = trader.positionSize;
        bool isNewPosition = !_isTraderPositionOpen(trader);

        if (isNewPosition || (traderPositionSize >= 0 ? LibPerpetual.Side.Long : LibPerpetual.Side.Short) == direction)
        {
            if (!isTradingExpansionAllowed) {
                revert Perpetual_TradingExpansionPaused();
            }

            (quoteProceeds, baseProceeds, tradingFeesPayed) = _extendPosition(account, amount, direction, minAmount);
            isPositionIncreased = true;
            profit = -tradingFeesPayed;
        } else {
            (quoteProceeds, baseProceeds, profit, tradingFeesPayed, isPositionClosed) =
                _reducePosition(account, amount, minAmount);
        }

        if (!isLiquidation) {
            // check max deviation
            _updateCurrentBlockTradeAmount(quoteProceeds.abs().toUint256());
            if (!_checkBlockTradeAmount()) revert Perpetual_ExcessiveBlockTradeAmount();
            if (globalPosition.traderShorts > globalPosition.totalBaseProvided) revert Perpetual_TooMuchExposure();
        }

        if (
            int256(trader.openNotional).abs().toUint256() > maxPosition
                || int256(trader.positionSize).abs().wadMul(indexPrice()).toUint256() > maxPosition
        ) revert Perpetual_MaxPositionSize();
    }

    /// @notice Settle funding payments for a trader
    /// @param account Trader
    /// @return fundingPayments Pending funding payments
    /// @notice Update the cumulative funding rate for the trader and return pending funding payments
    function settleTraderFunding(address account)
        public
        override
        onlyClearingHouse
        whenNotPaused
        returns (int256 fundingPayments)
    {
        LibPerpetual.TraderPosition storage trader = traderPosition[account];
        LibPerpetual.GlobalPosition storage globalP = globalPosition;

        _updateGlobalState();

        if (!_isTraderPositionOpen(trader)) {
            return 0;
        }

        fundingPayments = _getTraderFundingPayments(
            trader.positionSize >= 0, trader.cumFundingRate, globalP.cumFundingRate, int256(trader.positionSize).abs()
        );

        emit FundingPaid(account, fundingPayments, globalP.cumFundingRate, trader.cumFundingRate, true);

        trader.cumFundingRate = globalP.cumFundingRate;

        return fundingPayments;
    }

    /* ******************************/
    /*     Liquidity provider flow  */
    /* ******************************/

    /// @notice Provide liquidity to the pool
    /// @param account Liquidity provider
    /// @param amounts Amount of virtual tokens ([vQuote, vBase]) provided. 18 decimals
    /// @param minLpAmount Minimum amount of Lp tokens minted. 18 decimals
    /// @return tradingFees Generated profit generated from trading fees
    function provideLiquidity(address account, uint256[2] calldata amounts, uint256 minLpAmount)
        external
        override
        whenNotPaused
        onlyClearingHouse
        returns (int256 tradingFees)
    {
        // reflect the added liquidity on the LP position
        LibPerpetual.LiquidityProviderPosition storage lp = lpPosition[account];
        LibPerpetual.GlobalPosition storage globalP = globalPosition;

        // require a percentage deviation of quote to base amounts (in USD terms) to be lower than 10%
        // | (a - b) | / a  <= 10% <=>  | a - b | <= a * 10%, where a = amounts[0], b = amount[1] * p
        if (
            (amounts[VQUOTE_INDEX].toInt256() - amounts[VBASE_INDEX].toInt256().wadMul(indexPrice())).abs().toUint256()
                > (amounts[VQUOTE_INDEX].wadMul(1e17))
        ) revert Perpetual_LpAmountDeviation();

        uint256[2] memory providedLiquidity = amounts;

        // update when has provided liquidity before
        if (_isLpPositionOpen(lp)) {
            tradingFees = _settleLpTradingFees(lp, globalP).toInt256();

            // For LPs that have previously provided liquidity, we update the `totalBaseFeesGrowth` && `totalQuoteFeesGrowth`. fields in `update user status`.
            // That has the result that we set the trading fees in the curve pool so far to zero (as now globalP.totalQuoteFeesGrowth = lp.totalQuoteFeesGrowth)
            // So we underestimate the fees earned in the CryptoSwap contract now.
            // to counterbalance the effect we calculate the trading fees charged in the curve pool and subtract them from the additional liquidity provided.
            (uint256 baseFeesEarned, uint256 quoteFeesEarned) = _getVirtualTokensEarnedAsCurveTradingFees(lp, globalP);
            providedLiquidity[VQUOTE_INDEX] -= quoteFeesEarned;
            providedLiquidity[VBASE_INDEX] -= baseFeesEarned;
        }

        // supply liquidity to curve pool
        vQuote.mint(providedLiquidity[VQUOTE_INDEX]);
        vBase.mint(providedLiquidity[VBASE_INDEX]);
        uint256 liquidity = market.add_liquidity(providedLiquidity, minLpAmount);

        // update user state
        lpPosition[account] = LibPerpetual.LiquidityProviderPosition({
            openNotional: (lp.openNotional - amounts[VQUOTE_INDEX].toInt256()).toInt128(),
            positionSize: (lp.positionSize - amounts[VBASE_INDEX].toInt256()).toInt128(),
            totalTradingFeesGrowth: globalP.totalTradingFeesGrowth,
            totalBaseFeesGrowth: globalP.totalBaseFeesGrowth,
            totalQuoteFeesGrowth: globalP.totalQuoteFeesGrowth,
            liquidityBalance: (lp.liquidityBalance + liquidity).toUint128(),
            depositTime: block.timestamp.toUint64(),
            cumFundingPerLpToken: globalP.cumFundingPerLpToken
        });

        // update global state
        uint256 newLiquidityProvided = globalP.totalQuoteProvided + amounts[VQUOTE_INDEX];
        if (newLiquidityProvided > maxLiquidityProvided) revert Perpetual_MaxLiquidityProvided();
        globalP.totalQuoteProvided = newLiquidityProvided.toUint128();
        globalP.totalBaseProvided += amounts[VBASE_INDEX].toUint128();
    }

    /// @notice Remove liquidity from the pool
    /// @param account Account of the LP to remove liquidity from
    /// @param liquidityAmountToRemove Amount of liquidity to be removed from the pool. 18 decimals
    /// @param minVTokenAmounts Minimum amount of virtual tokens [vQuote, vBase] to withdraw from the curve pool. 18 decimals
    /// @param proposedAmount Amount of tokens to be sold, in vBase if LONG, in vQuote if SHORT. 18 decimals
    /// @param minAmount Minimum amount that the user is willing to accept, in vQuote if LONG, in vBase if SHORT. 18 decimals
    /// @param isLiquidation Transaction is a liquidation (true) or a regular transaction (false)
    /// @return profit Profit realized
    function removeLiquidity(
        address account,
        uint256 liquidityAmountToRemove,
        uint256[2] calldata minVTokenAmounts,
        uint256 proposedAmount,
        uint256 minAmount,
        bool isLiquidation
    )
        external
        override
        whenNotPaused
        onlyClearingHouse
        returns (
            int256 profit,
            int256 tradingFeesPayed,
            uint256 reductionRatio,
            int256 quoteProceeds,
            bool isPositionClosed
        )
    {
        LibPerpetual.LiquidityProviderPosition storage lp = lpPosition[account];
        // @dev No local variable for `globalPosition` to reduce nb of vars in the scope, else stack too deep error
        //      Yet, using `globalPosition` directly is equivalent to using a `storage` variable of it

        if (liquidityAmountToRemove > lp.liquidityBalance) revert Perpetual_LPWithdrawExceedsBalance();

        if (!isLiquidation && (block.timestamp < lp.depositTime + lockPeriod)) {
            revert Perpetual_LockPeriodNotReached(lp.depositTime + lockPeriod);
        }

        profit += _settleLpTradingFees(lp, globalPosition).toInt256();

        // 1) remove liquidity from the curve pool
        (uint256 quoteAmount, uint256 baseAmount) =
            _removeLiquidity(lp, globalPosition, liquidityAmountToRemove, minVTokenAmounts);

        // 2) settle trading position arising from change in pool ratio after removing liquidity
        reductionRatio = liquidityAmountToRemove.wadDiv(lp.liquidityBalance);

        {
            int256 pnl;
            LibPerpetual.TraderPosition memory positionToClose = LibPerpetual.TraderPosition({
                openNotional: (quoteAmount.toInt256() + int256(lp.openNotional).wadMul(reductionRatio.toInt256())).toInt128(
                ),
                positionSize: (baseAmount.toInt256() + int256(lp.positionSize).wadMul(reductionRatio.toInt256())).toInt128(),
                cumFundingRate: 0
            });
            (pnl, tradingFeesPayed, quoteProceeds) =
                _settleLpPosition(positionToClose, proposedAmount, minAmount, isLiquidation);
            profit += pnl;
        }

        // adjust balances to new position
        {
            lp.openNotional = (lp.openNotional + quoteAmount.toInt256()).toInt128();
            lp.positionSize = (lp.positionSize + baseAmount.toInt256()).toInt128();
            lp.liquidityBalance = (lp.liquidityBalance - liquidityAmountToRemove).toUint128();

            // if position has been closed entirely, delete it from the state
            if (!_isLpPositionOpen(lp)) {
                delete lpPosition[account];
                isPositionClosed = true;
            }

            globalPosition.totalQuoteProvided -= quoteAmount.toUint128();
            globalPosition.totalBaseProvided -= baseAmount.toUint128();
        }
    }

    /// @notice Settle funding payments for a liquidity provider
    /// @param account Liquidity Provider
    /// @return fundingPayments Pending funding payments
    /// @notice Update the cumulative funding rate for the LP and return pending funding payments
    function settleLpFunding(address account)
        external
        override
        whenNotPaused
        onlyClearingHouse
        returns (int256 fundingPayments)
    {
        LibPerpetual.LiquidityProviderPosition storage lp = lpPosition[account];
        LibPerpetual.GlobalPosition storage globalP = globalPosition;

        _updateGlobalState();

        if (!_isLpPositionOpen(lp)) {
            return 0;
        }

        // settle lp funding rate
        fundingPayments =
            _getLpFundingPayments(lp.cumFundingPerLpToken, globalP.cumFundingPerLpToken, lp.liquidityBalance);

        emit FundingPaid(account, fundingPayments, globalP.cumFundingPerLpToken, lp.cumFundingPerLpToken, false);

        lp.cumFundingPerLpToken = globalP.cumFundingPerLpToken;

        return fundingPayments;
    }

    /* ************* */
    /*    Helpers    */
    /* ************* */

    /// @notice Simulate removing liquidity from the curve pool to increase the slippage
    ///         and then performs a single swap on the curve pool. Returns the proceeds from the trade with revert message
    /// @dev Used to compute the proposedAmount parameter needed for removing liquidity
    /// @dev To be statically called from `ClearingHouseViewer.removeLiquiditySwap`
    /// @param account Liquidity Provider
    /// @param liquidityAmountToRemove Amount of liquidity to be removed from the pool. 18 decimals
    /// @param minVTokenAmounts Minimum amount of virtual tokens [vQuote, vBase] to withdraw from the curve pool. 18 decimals
    /// @param func Encoded function call to call on the curve viewer contract
    function removeLiquiditySwap(
        address account,
        uint256 liquidityAmountToRemove,
        uint256[2] calldata minVTokenAmounts,
        bytes calldata func
    ) external override {
        LibPerpetual.LiquidityProviderPosition storage lp = lpPosition[account];

        // increase slippage by removing liquidity & swap tokens
        _removeLiquidity(lp, globalPosition, liquidityAmountToRemove, minVTokenAmounts);

        // slither-disable-next-line low-level-calls
        (bool status, bytes memory response) = address(curveCryptoViews).staticcall(func);
        if (!status) revert("staticcall in perpetual contract failed");

        // response is uint256 not bytes
        uint256 proceeds = abi.decode(response, (uint256));

        // Revert with proceeds
        // adjusted from https://github.com/Uniswap/v3-periphery/blob/5bcdd9f67f9394f3159dad80d0dd01d37ca08c66/contracts/lens/Quoter.sol#L60-L64
        // slither-disable-next-line assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, proceeds)
            revert(ptr, 32)
        }
    }

    /// @notice Update the global state of the perpetual market
    /// @dev Can be called by offchain worker to update market conditions
    function updateGlobalState() external override whenNotPaused {
        _updateGlobalState();
    }

    /* ****************** */
    /*     Governance     */
    /* ****************** */

    /// @notice Allow/block trading operations tapping into the liquidity (i.e. opening and extending positions)
    /// @notice Meant to be called once an agreed uppon minimum liquidity level is reached (or dropped back to)
    /// @dev Can only be called by Emergency Admin
    /// @param toPause Whether to pause or not trading expansion operations
    function toggleTradingExpansionPause(bool toPause) external override onlyRole(EMERGENCY_ADMIN) {
        isTradingExpansionAllowed = toPause;

        emit TradingExpansionPauseToggled(msg.sender, toPause);
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

    /// @notice Update parameters listed in `IPerpetual.PerpetualParams`
    /// @dev Can only be called by Governance
    /// @param params New Economic parameters
    function setParameters(PerpetualParams memory params) public override onlyRole(GOVERNANCE) {
        if (params.sensitivity < 2e17 || params.sensitivity > 10e18) {
            revert Perpetual_SensitivityInvalid(params.sensitivity);
        }
        if (params.insuranceFee < 1e14 || params.insuranceFee > 1e16) {
            revert Perpetual_InsuranceFeeInvalid(params.insuranceFee);
        }
        if (params.lpDebtCoef < 1e18 || params.lpDebtCoef > 20e18) {
            revert Perpetual_LpDebtCoefInvalid(params.lpDebtCoef);
        }
        if (params.maxBlockTradeAmount < 100e18) revert Perpetual_MaxBlockAmountInvalid(params.maxBlockTradeAmount);
        if (params.twapFrequency < 1 minutes || params.twapFrequency > 60 minutes) {
            revert Perpetual_TwapFrequencyInvalid(params.twapFrequency);
        }
        if (params.lockPeriod < 10 minutes || params.lockPeriod > 30 days) {
            revert Perpetual_LockPeriodInvalid(params.lockPeriod);
        }
        if (params.riskWeight < 1e18 || params.riskWeight > 50e18) {
            revert Perpetual_RiskWeightInvalid(params.riskWeight);
        }

        riskWeight = params.riskWeight;
        maxLiquidityProvided = params.maxLiquidityProvided;
        sensitivity = params.sensitivity;
        insuranceFee = params.insuranceFee;
        lpDebtCoef = params.lpDebtCoef;
        twapFrequency = params.twapFrequency;
        maxBlockTradeAmount = params.maxBlockTradeAmount;
        lockPeriod = params.lockPeriod;
        maxPosition = maxBlockTradeAmount / 10;

        emit PerpetualParametersChanged(
            params.riskWeight,
            params.maxLiquidityProvided,
            params.twapFrequency,
            params.sensitivity,
            params.maxBlockTradeAmount,
            params.insuranceFee,
            params.lpDebtCoef,
            params.lockPeriod
        );
    }

    /* ****************** */
    /*   Global getter    */
    /* ****************** */

    /// @notice Get global market position
    function getGlobalPosition() external view override returns (LibPerpetual.GlobalPosition memory) {
        return globalPosition;
    }

    /// @notice Return the current off-chain exchange rate for vBase/vQuote
    function indexPrice() public view override returns (int256) {
        return vBase.getIndexPrice();
    }

    /// @notice Return the last traded price (used for TWAP)
    function marketPrice() public view override returns (uint256) {
        if (getTotalLiquidityProvided() == 0) {
            return market.last_prices();
        } else {
            // take the average of a small long / short trade
            // as a best estimate of the market (spot) price
            uint256 quoteAmountSold = 1e17;
            uint256 baseAmountSold = quoteAmountSold.wadDiv(indexPrice().toUint256());
            uint256 baseAmountBought =
                curveCryptoViews.get_dy_no_fee_deduct(market, VQUOTE_INDEX, VBASE_INDEX, quoteAmountSold);
            uint256 quoteAmountBought =
                curveCryptoViews.get_dy_no_fee_deduct(market, VBASE_INDEX, VQUOTE_INDEX, baseAmountSold);
            // return the average of the two prices
            return (quoteAmountBought.wadDiv(baseAmountSold) + quoteAmountSold.wadDiv(baseAmountBought)) / 2;
        }
    }

    /// @notice Get the market total liquidity provided to the Crypto Swap pool
    function getTotalLiquidityProvided() public view override returns (uint256) {
        return IERC20Metadata(market.token()).totalSupply();
    }

    /* ****************** */
    /*   User getter      */
    /* ****************** */

    // Trader

    /// @notice Get the unrealized profit and loss of a trader
    /// @param account Trader
    function getTraderUnrealizedPnL(address account) public view override returns (int256 pnl) {
        LibPerpetual.TraderPosition storage trader = traderPosition[account];
        return _getUnrealizedPnL(trader);
    }

    /// @notice Get the position of a trader
    /// @param account Address to get the trading position from
    function getTraderPosition(address account) external view override returns (LibPerpetual.TraderPosition memory) {
        return traderPosition[account];
    }

    /// @notice Get the Profit and Loss of a user
    /// @param account Address to get the pnL from
    function getPendingPnL(address account) external view override returns (int256 pnL) {
        LibPerpetual.TraderPosition storage trader = traderPosition[account];
        LibPerpetual.LiquidityProviderPosition storage lp = lpPosition[account];

        if (_isTraderPositionOpen(trader)) {
            pnL += getTraderUnrealizedPnL(account);
        }

        if (_isLpPositionOpen(lp)) {
            LibPerpetual.GlobalPosition storage globalP = globalPosition;
            LibPerpetual.TraderPosition memory activeLpPosition = _getLpPositionAfterWithdrawal(lp, globalP);
            pnL += _getUnrealizedPnL(activeLpPosition) + _getLpTradingFees(lp, globalP).toInt256();
        }

        return pnL;
    }

    /// @notice Get the user debt of an user
    /// @param account Address to get the pnL from
    function getUserDebt(address account) external view override returns (int256 debt) {
        LibPerpetual.TraderPosition storage trader = traderPosition[account];
        LibPerpetual.LiquidityProviderPosition storage lp = lpPosition[account];

        if (_isTraderPositionOpen(trader)) {
            debt += _getTraderDebt(trader).abs();
        }
        if (_isLpPositionOpen(lp)) {
            debt += _getLpDebt(lp).abs().wadMul(lpDebtCoef);
        }

        return debt;
    }

    /// @notice Whether a trader position is opened or not
    /// @param account Address of the trader
    function isTraderPositionOpen(address account) external view override returns (bool) {
        LibPerpetual.TraderPosition storage trader = traderPosition[account];
        return _isTraderPositionOpen(trader);
    }

    // LP

    /// @notice Get the trading fees earned by a LP
    /// @param account Address of the liquidity provider
    function getLpTradingFees(address account) external view override returns (uint256 tradingFeesEarned) {
        LibPerpetual.LiquidityProviderPosition storage lp = lpPosition[account];
        LibPerpetual.GlobalPosition storage globalP = globalPosition;

        return _getLpTradingFees(lp, globalP);
    }

    /// @notice Get the unrealized profit and loss of a LP
    /// @param account Address of the liquidity provider
    function getLpUnrealizedPnL(address account) external view override returns (int256 pnl) {
        LibPerpetual.LiquidityProviderPosition storage lp = lpPosition[account];
        LibPerpetual.GlobalPosition storage globalP = globalPosition;

        LibPerpetual.TraderPosition memory activeLpPosition = _getLpPositionAfterWithdrawal(lp, globalP);
        int256 activePositionPnL = _getUnrealizedPnL(activeLpPosition);

        return activePositionPnL;
    }

    /// @notice Get the (active) position of a liquidity provider after withdrawing liquidity
    /// @param account Address to get the LP position from
    function getLpPositionAfterWithdrawal(address account)
        external
        view
        override
        returns (LibPerpetual.TraderPosition memory)
    {
        LibPerpetual.LiquidityProviderPosition storage lp = lpPosition[account];
        LibPerpetual.GlobalPosition storage globalP = globalPosition;

        if (!_isLpPositionOpen(lp)) {
            return LibPerpetual.TraderPosition({openNotional: 0, positionSize: 0, cumFundingRate: 0});
        }

        return _getLpPositionAfterWithdrawal(lp, globalP);
    }

    /// @notice Get the position of a liquidity provider
    /// @param account Address to get the LP position from
    function getLpPosition(address account)
        external
        view
        override
        returns (LibPerpetual.LiquidityProviderPosition memory)
    {
        return lpPosition[account];
    }

    /// @notice Get the lp tokens owned by a Liquidity Provider
    /// @param account Liquidity Provider
    function getLpLiquidity(address account) external view override returns (uint256) {
        LibPerpetual.LiquidityProviderPosition storage lp = lpPosition[account];
        return lp.liquidityBalance;
    }

    /// @notice Get the dollar value of the liquidity provided by a liquidity Provider
    /// @param account Address of the LP
    function getLpOpenNotional(address account) external view override returns (int256) {
        LibPerpetual.LiquidityProviderPosition storage lp = lpPosition[account];

        return int256(lp.openNotional);
    }

    /// @notice Whether or not a LP position is opened
    /// @param account Address of the LP
    function isLpPositionOpen(address account) external view override returns (bool) {
        LibPerpetual.LiquidityProviderPosition storage lp = lpPosition[account];
        return _isLpPositionOpen(lp);
    }

    /* ****************** */
    /*   Internal (Gov)   */
    /* ****************** */

    function _initGlobalState(int256 lastChainlinkPrice, int256 lastMarketPrice) internal {
        // initialize twap
        oracleTwap = lastChainlinkPrice.toInt128();
        marketTwap = lastMarketPrice.toInt128();

        // initialize funding
        globalPosition = LibPerpetual.GlobalPosition({
            timeOfLastTrade: block.timestamp.toUint64(),
            timeOfLastTwapUpdate: block.timestamp.toUint64(),
            cumFundingRate: 0,
            currentBlockTradeAmount: 0,
            totalTradingFeesGrowth: 0,
            totalQuoteProvided: 0,
            totalBaseProvided: 0,
            totalBaseFeesGrowth: 0,
            totalQuoteFeesGrowth: 0,
            traderLongs: 0,
            traderShorts: 0,
            cumFundingPerLpToken: 0
        });
    }

    /* ****************** */
    /*  Internal (Trading) */
    /* ****************** */

    function _extendPosition(address account, uint256 amount, LibPerpetual.Side direction, uint256 minAmount)
        internal
        returns (int256 quoteProceeds, int256 baseProceeds, int256 tradingFees)
    {
        /*
            if direction = LONG

                trader accrues openNotional debt
                trader receives positionSize assets

                quoteProceeds = vQuote traded to market    ( < 0)
                positionSize = vBase received from market ( > 0)

            else direction = SHORT

                trader receives openNotional assets
                trader accrues positionSize debt

                openNotional = vQuote received from market ( > 0)
                positionSize = vBase traded to market      ( < 0)

            @dev: When we extend a position - no pnl is settled.
                  We only charge trading fees on the notional amount of its trade.

        */

        LibPerpetual.TraderPosition storage trader = traderPosition[account];
        bool isLong = direction == LibPerpetual.Side.Long;

        (quoteProceeds, baseProceeds, tradingFees) = _extendPositionOnMarket(amount, isLong, minAmount);

        // update position
        trader.openNotional = (trader.openNotional + quoteProceeds).toInt128();
        trader.positionSize = (trader.positionSize + baseProceeds).toInt128();
        trader.cumFundingRate = globalPosition.cumFundingRate;

        return (quoteProceeds, baseProceeds, tradingFees);
    }

    function _extendPositionOnMarket(uint256 proposedAmount, bool isLong, uint256 minAmount)
        internal
        returns (int256 quoteProceeds, int256 baseProceeds, int256 tradingFees)
    {
        /*  if long:
                quoteProceeds = vQuote traded   to market   (or "- vQuote")
                baseProceeds = vBase  received from market (or "+ vBase")
            if short:
                quoteProceeds = vQuote received from market (or "+ vQuote")
                baseProceeds = vBase  traded   to market   (or "- vBase")
        */
        uint256 feePer;
        uint256 bought;
        if (isLong) {
            quoteProceeds = -proposedAmount.toInt256();
            (bought, feePer) = _quoteForBase(proposedAmount, minAmount);
            baseProceeds = bought.toInt256();
            globalPosition.traderLongs += bought.toUint128();
        } else {
            (bought, feePer) = _baseForQuote(proposedAmount, minAmount);
            baseProceeds = -proposedAmount.toInt256();
            quoteProceeds = bought.toInt256();
            globalPosition.traderShorts += proposedAmount.toUint128();
        }

        tradingFees = _chargeQuoteFees(quoteProceeds, feePer.toInt256());

        return (quoteProceeds, baseProceeds, tradingFees);
    }

    function _reducePosition(address account, uint256 proposedAmount, uint256 minAmount)
        internal
        returns (int256 quoteProceeds, int256 baseProceeds, int256 pnl, int256 tradingFeesPayed, bool isPositionClosed)
    {
        /*
        after opening the position:
            trader has long position:
                openNotional = vQuote traded   to market   (< 0)
                positionSize = vBase  received from market (> 0)
            trader has short position
                openNotional = vQuote received from market (> 0)
                positionSize = vBase  traded   to market   (< 0)

        to close the position:

            trader has long position:
                @proposedAmount := amount of vBase used to reduce the position
                => user trades the vBase tokens with the curve pool for vQuote tokens

            trader has short position:
                @proposedAmount := amount of vQuote required to repay the vBase debt
                => user incurred vBase debt when opening a position and must now trade enough
                  vQuote with the curve pool to repay his vBase debt in full

        */

        LibPerpetual.TraderPosition storage trader = traderPosition[account];
        if (!_isTraderPositionOpen(trader)) revert Perpetual_NoOpenPosition();

        int256 addedOpenNotional;
        (baseProceeds, quoteProceeds, addedOpenNotional, pnl, tradingFeesPayed) = _reducePositionOnMarket(
            trader,
            !(trader.positionSize >= 0), /* trade direction is reversed to current position */
            proposedAmount,
            minAmount
        );

        // adjust trader position
        trader.openNotional = (trader.openNotional + addedOpenNotional).toInt128();
        trader.positionSize = (trader.positionSize + baseProceeds).toInt128();

        // if position has been closed entirely, delete it from the state
        if (!_isTraderPositionOpen(trader)) {
            delete traderPosition[account];
            isPositionClosed = true;
        }

        return (quoteProceeds, baseProceeds, pnl, tradingFeesPayed, isPositionClosed);
    }

    /// @dev Used both by traders closing their own positions and liquidators liquidating other people's positions
    /// @notice Profit is the sum of funding payments and the position PnL
    /// @param proposedAmount Amount of tokens to be sold, in vBase if LONG, in vQuote if SHORT. 18 decimals
    /// @param isLong Whether the trade is Long or Short
    /// @param minAmount Minimum amount that the user is willing to accept, in vQuote if LONG, in vBase if SHORT. 18 decimals
    function _reducePositionOnMarket(
        LibPerpetual.TraderPosition memory user,
        bool isLong,
        uint256 proposedAmount,
        uint256 minAmount
    )
        internal
        returns (
            int256 baseProceeds,
            int256 quoteProceeds,
            int256 addedOpenNotional,
            int256 pnl,
            int256 tradingFeesPayed
        )
    {
        int256 positionSize = int256(user.positionSize);

        uint256 feePer;
        {
            uint256 bought;
            if (isLong) {
                quoteProceeds = -(proposedAmount.toInt256());
                (bought, feePer) = _quoteForBase(proposedAmount, minAmount);
                baseProceeds = bought.toInt256();
                globalPosition.traderShorts -= bought.min(globalPosition.traderShorts).toUint128(); // TODO: get rid of when we only enforce upper bound on settlement
            } else {
                (bought, feePer) = _baseForQuote(proposedAmount, minAmount);
                quoteProceeds = bought.toInt256();
                baseProceeds = -(proposedAmount.toInt256());
                globalPosition.traderLongs -= proposedAmount.min(globalPosition.traderLongs).toUint128();
            }

            int256 netBasePosition = baseProceeds + positionSize;
            if (netBasePosition.wadMul(indexPrice()).abs() <= 1e17) {
                _roundDust(netBasePosition);
                baseProceeds -= netBasePosition;
            }
        }

        bool isReducingPosition =
            positionSize > 0 ? (baseProceeds + positionSize) >= 0 : (baseProceeds + positionSize) <= 0;

        if (!isReducingPosition) revert Perpetual_AttemptReversePosition();

        // calculate reduction ratio
        uint256 realizedReductionRatio = (baseProceeds.abs().wadDiv(positionSize.abs())).toUint256();
        tradingFeesPayed = _chargeQuoteFees(quoteProceeds, feePer.toInt256());

        addedOpenNotional = int256(-user.openNotional).wadMul(realizedReductionRatio.toInt256());
        pnl = quoteProceeds - addedOpenNotional - tradingFeesPayed;
    }

    function _quoteForBase(uint256 quoteAmount, uint256 minAmount)
        internal
        returns (uint256 vBaseExFees, uint256 feePer)
    {
        // get swap excluding fees
        vBaseExFees = curveCryptoViews.get_dy_no_fee_deduct(market, VQUOTE_INDEX, VBASE_INDEX, quoteAmount);

        // perform swap

        vQuote.mint(quoteAmount);
        uint256 vBaseReceived = market.exchange(VQUOTE_INDEX, VBASE_INDEX, quoteAmount, minAmount);
        vBase.burn(vBaseReceived);

        // adjust for fees
        uint256 feesGrowth = vBaseExFees - vBaseReceived;
        globalPosition.totalBaseFeesGrowth =
            (globalPosition.totalBaseFeesGrowth + feesGrowth.wadDiv(vBase.totalSupply())).toUint128();
        feePer = feesGrowth.wadDiv(vBaseExFees);
    }

    function _baseForQuote(uint256 baseAmount, uint256 minAmount)
        internal
        returns (uint256 vQuoteExFees, uint256 feePer)
    {
        // get swap excluding fees
        vQuoteExFees = curveCryptoViews.get_dy_no_fee_deduct(market, VBASE_INDEX, VQUOTE_INDEX, baseAmount);

        // perform swap

        vBase.mint(baseAmount);
        uint256 vQuoteReceived = market.exchange(VBASE_INDEX, VQUOTE_INDEX, baseAmount, minAmount);
        vQuote.burn(vQuoteReceived);

        // adjust for fees
        uint256 feesGrowth = vQuoteExFees - vQuoteReceived;
        globalPosition.totalQuoteFeesGrowth =
            (globalPosition.totalQuoteFeesGrowth + feesGrowth.wadDiv(vQuote.totalSupply())).toUint128(); // @dev: totalSupply is safer than balanceOf
        feePer = feesGrowth.wadDiv(vQuoteExFees);
    }

    /// @notice charge trading fee on notional amount
    function _chargeQuoteFees(int256 quoteProceeds, int256 feePer) internal returns (int256) {
        int256 feesPayed = quoteProceeds.abs().wadMul(feePer);
        globalPosition.totalTradingFeesGrowth += (feesPayed.toUint256().wadDiv(getTotalLiquidityProvided())).toUint128(); // rate of return of this trade

        return feesPayed;
    }

    /* ****************** */
    /*  Internal (Liquidity) */
    /* ****************** */

    function _removeLiquidity(
        LibPerpetual.LiquidityProviderPosition memory lp,
        LibPerpetual.GlobalPosition memory globalP,
        uint256 liquidityAmountToRemove,
        uint256[2] calldata minVTokenAmounts
    ) internal returns (uint256 quoteAmount, uint256 baseAmount) {
        // remove liquidity
        uint256 vQuoteBalanceBefore = vQuote.balanceOf(address(this));
        uint256 vBaseBalanceBefore = vBase.balanceOf(address(this));

        market.remove_liquidity(liquidityAmountToRemove, minVTokenAmounts);

        if (vQuote.balanceOf(address(market)) <= 1 || vBase.balanceOf(address(market)) <= 1) {
            revert Perpetual_MarketBalanceTooLow();
        }

        uint256 vQuoteBalanceAfter = vQuote.balanceOf(address(this));
        uint256 vBaseBalanceAfter = vBase.balanceOf(address(this));

        uint256 quoteAmountInclFees = vQuoteBalanceAfter - vQuoteBalanceBefore;
        uint256 baseAmountInclFees = vBaseBalanceAfter - vBaseBalanceBefore;

        vQuote.burn(quoteAmountInclFees);
        vBase.burn(baseAmountInclFees);

        // remove fee component from quoteAmount
        quoteAmount = quoteAmountInclFees.wadDiv(1e18 + globalP.totalQuoteFeesGrowth - lp.totalQuoteFeesGrowth);
        baseAmount = baseAmountInclFees.wadDiv(1e18 + globalP.totalBaseFeesGrowth - lp.totalBaseFeesGrowth);
    }

    function _settleLpPosition(
        LibPerpetual.TraderPosition memory positionToClose,
        uint256 proposedAmount,
        uint256 minAmount,
        bool isLiquidation
    ) internal returns (int256 pnl, int256 tradingFeesPayed, int256 quoteProceeds) {
        int256 baseProceeds;
        int256 addedOpenNotional;

        (baseProceeds, quoteProceeds, addedOpenNotional, pnl, tradingFeesPayed) =
            _reducePositionOnMarket(positionToClose, !(positionToClose.positionSize >= 0), proposedAmount, minAmount);

        if (!isLiquidation) {
            // check max deviation
            _updateCurrentBlockTradeAmount(quoteProceeds.abs().toUint256());
            if (!_checkBlockTradeAmount()) revert Perpetual_ExcessiveBlockTradeAmount();
        }
        positionToClose.positionSize = (positionToClose.positionSize + baseProceeds).toInt128();
        positionToClose.openNotional = (positionToClose.openNotional + addedOpenNotional).toInt128();

        if (_isTraderPositionOpen(positionToClose)) revert Perpetual_LPOpenPosition();
    }

    function _settleLpTradingFees(
        LibPerpetual.LiquidityProviderPosition storage lp,
        LibPerpetual.GlobalPosition storage globalP
    ) internal returns (uint256 tradingFeesEarned) {
        // settle lp trading fees
        tradingFeesEarned = _getLpTradingFees(lp, globalP);

        lp.totalTradingFeesGrowth = globalP.totalTradingFeesGrowth;

        return tradingFeesEarned;
    }

    /* ************************ */
    /*  Internal (global state) */
    /* ************************ */
    function _updateFundingRate() internal {
        LibPerpetual.GlobalPosition storage globalP = globalPosition;
        uint256 currentTime = block.timestamp;

        int256 currentTraderPremium = marketTwap - oracleTwap;
        int256 timePassedSinceLastTrade = (currentTime - globalP.timeOfLastTrade).toInt256();

        int256 fundingRate = ((sensitivity.wadMul(currentTraderPremium) * timePassedSinceLastTrade) / 1 days); // @dev: in fixed number x seconds / seconds = fixed number

        globalP.cumFundingRate = globalP.cumFundingRate + fundingRate.toInt128();
        globalP.timeOfLastTrade = currentTime.toUint64();

        int256 tokenSupply =
            getTotalLiquidityProvided().toInt256() > 0 ? getTotalLiquidityProvided().toInt256() : int256(1e18);

        int256 totalTraderPositionSize =
            uint256(globalP.traderLongs).toInt256() - uint256(globalP.traderShorts).toInt256();
        globalP.cumFundingPerLpToken += totalTraderPositionSize >= 0
            ? -fundingRate.wadMul(totalTraderPositionSize).wadDiv(tokenSupply).toInt128() // long pay funding
            : fundingRate.wadMul(totalTraderPositionSize).wadDiv(tokenSupply).toInt128(); // short receives funding

        emit FundingRateUpdated(globalP.cumFundingRate, globalP.cumFundingPerLpToken, fundingRate);
    }

    function _updateCurrentBlockTradeAmount(uint256 vQuoteAmount) internal {
        globalPosition.currentBlockTradeAmount = (globalPosition.currentBlockTradeAmount + vQuoteAmount).toUint128();
    }

    function _resetCurrentBlockTradeAmount() internal {
        globalPosition.currentBlockTradeAmount = 0;
    }

    function _updateTwap() internal {
        /*
        @dev: To update the twap we multiply a 18 decimals fixed point number with a time variable (in seconds).
        */
        uint256 currentTime = block.timestamp;
        int256 timeElapsed = (currentTime - globalPosition.timeOfLastTrade).toInt256();

        /*
            priceCumulative1 = priceCumulative0 + price1 * timeElapsed
        */

        // will overflow in ~3000 years
        // update cumulative chainlink price feed
        int256 latestChainlinkPrice = indexPrice();
        oracleCumulativeAmount += latestChainlinkPrice * timeElapsed; // @dev: in fixed number x seconds

        // update cumulative market price feed
        int256 latestMarketPrice = marketPrice().toInt256();
        marketCumulativeAmount += latestMarketPrice * timeElapsed; // @dev: in fixed number x seconds

        uint256 timeElapsedSinceBeginningOfPeriod = block.timestamp - globalPosition.timeOfLastTwapUpdate;

        if (timeElapsedSinceBeginningOfPeriod >= twapFrequency) {
            /*
                TWAP = (priceCumulative1 - priceCumulative0) / timeElapsed
            */

            // calculate chainlink twap
            oracleTwap = (
                (oracleCumulativeAmount - oracleCumulativeAmountAtBeginningOfPeriod)
                    / timeElapsedSinceBeginningOfPeriod.toInt256()
            ).toInt128(); // @dev: in fixed number x seconds / seconds = fixed number

            // calculate market twap
            marketTwap = (
                (marketCumulativeAmount - marketCumulativeAmountAtBeginningOfPeriod)
                    / timeElapsedSinceBeginningOfPeriod.toInt256()
            ).toInt128(); // @dev: in fixed number x seconds / seconds = fixed number

            // reset cumulative amount and timestamp
            oracleCumulativeAmountAtBeginningOfPeriod = oracleCumulativeAmount;
            marketCumulativeAmountAtBeginningOfPeriod = marketCumulativeAmount;
            globalPosition.timeOfLastTwapUpdate = block.timestamp.toUint64();

            emit TwapUpdated(oracleTwap, marketTwap);
        }
    }

    /**
     *
     */
    /* Internal  (Misc)         */
    /**
     *
     */

    /// @notice Update Twap, Funding Rate and reset current block trade amount
    function _updateGlobalState() internal whenNotPaused {
        LibPerpetual.GlobalPosition storage globalP = globalPosition;
        uint256 currentTime = block.timestamp;
        uint256 timeOfLastTrade = uint256(globalP.timeOfLastTrade);

        // Don't update the state more than once per block
        if (currentTime > timeOfLastTrade) {
            _updateTwap();
            _updateFundingRate();
            _resetCurrentBlockTradeAmount();
        }
    }

    /// @notice Round the base position to zero and assign the difference ("dust") to the insurance
    /// @notice _roundDust is called because `getProposedAmount` cant accurately estimate the
    ///         the vBase amount to close a short position.
    /// @dev PnL of rounding base tokens is settled by calling `sellDust` in ClearingHouse.
    /// @param baseAmount The amount of base tokens which will be credited/debited to the insurance.
    function _roundDust(int256 baseAmount) internal {
        LibPerpetual.TraderPosition storage insurance = traderPosition[address(clearingHouse)];

        int256 newClearingHousePositionSize = insurance.positionSize + baseAmount;
        insurance.positionSize = newClearingHousePositionSize.toInt128();

        // settle funding payments into openNotional
        insurance.openNotional += settleTraderFunding(address(clearingHouse)).toInt128();

        emit DustGenerated(baseAmount);
    }

    /**
     *
     */
    /* Internal Viewer (Trading) */
    /**
     *
     */

    /// @notice true if trade amount lower than max trade amount per block, false otherwise
    function _checkBlockTradeAmount() internal view returns (bool) {
        return globalPosition.currentBlockTradeAmount < maxBlockTradeAmount;
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

            // fundingPayments = fundingRate * vBaseAmountToSettle
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

    function _getUnrealizedPnL(LibPerpetual.TraderPosition memory trader) internal view returns (int256) {
        int256 oraclePrice = indexPrice();
        int256 vQuoteVirtualProceeds = int256(trader.positionSize).wadMul(oraclePrice);

        // convert fees to 18 decimals precision
        // @dev: take upper bound (out_fee) on the trading fees
        uint256 feesInWad = market.out_fee() * 10 ** (18 - CURVE_TRADING_FEE_DECIMALS);
        int256 tradingFees = vQuoteVirtualProceeds.abs().wadMul(feesInWad.toInt256());

        // in the case of a LONG, trader.openNotional is negative but vQuoteVirtualProceeds is positive
        // in the case of a SHORT, trader.openNotional is positive while vQuoteVirtualProceeds is negative
        return int256(trader.openNotional) + vQuoteVirtualProceeds - tradingFees;
    }

    /**
     *
     */
    /* Internal Viewer (Liquidity) */
    /**
     *
     */
    function _getVirtualTokensEarnedAsCurveTradingFees(
        LibPerpetual.LiquidityProviderPosition storage lp,
        LibPerpetual.GlobalPosition storage globalP
    ) internal view returns (uint256 baseFeesEarned, uint256 quoteFeesEarned) {
        // LP position
        uint256 totalLiquidityProvided = getTotalLiquidityProvided();

        (uint256 quoteTokensExFees, uint256 quoteTokensInclFees) = _getVirtualTokensWithdrawnFromCurvePool(
            totalLiquidityProvided,
            lp.liquidityBalance,
            market.balances(VQUOTE_INDEX),
            lp.totalQuoteFeesGrowth,
            globalP.totalQuoteFeesGrowth
        );
        quoteFeesEarned = quoteTokensInclFees - quoteTokensExFees;

        (uint256 baseTokensExFees, uint256 baseTokensInclFees) = _getVirtualTokensWithdrawnFromCurvePool(
            totalLiquidityProvided,
            lp.liquidityBalance,
            market.balances(VBASE_INDEX),
            lp.totalBaseFeesGrowth,
            globalP.totalBaseFeesGrowth
        );
        baseFeesEarned = baseTokensInclFees - baseTokensExFees;
    }

    // calculate how many virtual tokens could be removed right now
    function _getVirtualTokensWithdrawnFromCurvePool(
        uint256 totalLiquidityProvided,
        uint256 lpTokensLiquidityProvider,
        uint256 curvePoolBalance,
        uint256 userVirtualTokenGrowthRate,
        uint256 globalVirtualTokenTotalGrowth
    ) internal pure returns (uint256 tokensExFees, uint256 tokensInclFees) {
        if (totalLiquidityProvided == 0) {
            return (0, 0);
        }

        // dev: use math equations from cryptoswap.remove_liquidity() here
        tokensInclFees = ((lpTokensLiquidityProvider - 1) * curvePoolBalance) / totalLiquidityProvided;

        // remove all fees earned in the pool
        tokensExFees = tokensInclFees.wadDiv(1e18 + globalVirtualTokenTotalGrowth - userVirtualTokenGrowthRate);
    }

    /// @notice Get the trading fees earned by the liquidity provider
    function _getLpTradingFees(
        LibPerpetual.LiquidityProviderPosition storage lp,
        LibPerpetual.GlobalPosition storage globalP
    ) internal view returns (uint256) {
        return uint256(lp.liquidityBalance).wadMul(globalP.totalTradingFeesGrowth - lp.totalTradingFeesGrowth);
    }

    /// @notice Get the (active) position of a liquidity provider after withdrawing liquidity
    function _getLpPositionAfterWithdrawal(
        LibPerpetual.LiquidityProviderPosition storage lp,
        LibPerpetual.GlobalPosition storage globalP
    ) internal view returns (LibPerpetual.TraderPosition memory) {
        // LP position
        uint256 totalLiquidityProvided = getTotalLiquidityProvided();

        (uint256 quoteTokensExFees,) = _getVirtualTokensWithdrawnFromCurvePool(
            totalLiquidityProvided,
            lp.liquidityBalance,
            market.balances(VQUOTE_INDEX),
            lp.totalQuoteFeesGrowth,
            globalP.totalQuoteFeesGrowth
        );

        (uint256 baseTokensExFees,) = _getVirtualTokensWithdrawnFromCurvePool(
            totalLiquidityProvided,
            lp.liquidityBalance,
            market.balances(VBASE_INDEX),
            lp.totalBaseFeesGrowth,
            globalP.totalBaseFeesGrowth
        );

        return LibPerpetual.TraderPosition({
            openNotional: (lp.openNotional + quoteTokensExFees.toInt256()).toInt128(),
            positionSize: (lp.positionSize + baseTokensExFees.toInt256()).toInt128(),
            cumFundingRate: 0
        });
    }

    function _isTraderPositionOpen(LibPerpetual.TraderPosition memory trader) internal pure returns (bool) {
        if (trader.openNotional != 0 || trader.positionSize != 0) {
            return true;
        }
        return false;
    }

    function _isLpPositionOpen(LibPerpetual.LiquidityProviderPosition storage lp) internal view returns (bool) {
        if (lp.liquidityBalance != 0) {
            return true;
        }
        return false;
    }

    function _getTraderDebt(LibPerpetual.TraderPosition storage trader) internal view returns (int256) {
        int256 quoteDebt = int256(trader.openNotional).min(0);
        int256 baseDebt = int256(trader.positionSize).wadMul(indexPrice()).min(0);

        return quoteDebt + baseDebt;
    }

    function _getLpDebt(LibPerpetual.LiquidityProviderPosition storage lp) internal view returns (int256) {
        int256 quoteDebt = int256(lp.openNotional).min(0);
        int256 baseDebt = int256(lp.positionSize).wadMul(indexPrice()).min(0);

        return quoteDebt + baseDebt;
    }
}
