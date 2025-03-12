/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity >=0.8.0 <0.9.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IDODOMine {

    function balanceOf(address user) external view returns (uint256);

    function deposit(uint256 _amount) external;

    function withdraw(uint256 _amount) external;

    function claimAllRewards() external;

}

interface IDODOProxy {
    function dodoSwapV1(
        address fromToken,
        address toToken,
        uint256 fromTokenAmount,
        uint256 minReturnAmount,
        address[] memory dodoPairs,
        uint256 directions,
        bool,
        uint256 deadLine
    ) external payable returns (uint256 returnAmount);

    function dodoSwapV2TokenToToken(
        address fromToken,
        address toToken,
        uint256 fromTokenAmount,
        uint256 minReturnAmount,
        address[] memory dodoPairs,
        uint256 directions,
        bool isIncentive,
        uint256 deadLine
    ) external returns (uint256 returnAmount);
}

interface IDODOV1 {
    function init(
        address owner,
        address supervisor,
        address maintainer,
        address baseToken,
        address quoteToken,
        address oracle,
        uint256 lpFeeRate,
        uint256 mtFeeRate,
        uint256 k,
        uint256 gasPriceLimit
    ) external;

    function transferOwnership(address newOwner) external;

    function claimOwnership() external;

    function sellBaseToken(
        uint256 amount,
        uint256 minReceiveQuote,
        bytes calldata data
    ) external returns (uint256);

    function buyBaseToken(
        uint256 amount,
        uint256 maxPayQuote,
        bytes calldata data
    ) external returns (uint256);

    function querySellBaseToken(uint256 amount) external view returns (uint256 receiveQuote);

    function queryBuyBaseToken(uint256 amount) external view returns (uint256 payQuote);

    function getExpectedTarget() external view returns (uint256 baseTarget, uint256 quoteTarget);

    function depositBaseTo(address to, uint256 amount) external returns (uint256);

    function withdrawBase(uint256 amount) external returns (uint256);

    function withdrawAllBase() external returns (uint256);

    function depositQuoteTo(address to, uint256 amount) external returns (uint256);

    function withdrawQuote(uint256 amount) external returns (uint256);

    function withdrawAllQuote() external returns (uint256);

    function _BASE_CAPITAL_TOKEN_() external view returns (address);

    function _QUOTE_CAPITAL_TOKEN_() external view returns (address);

    function _BASE_TOKEN_() external returns (address);

    function _QUOTE_TOKEN_() external returns (address);

    function _K_() external view returns (uint256);

    function _R_STATUS_() external view returns (RStatus);

    function _TARGET_BASE_TOKEN_AMOUNT_() external view returns (uint256);

    function _TARGET_QUOTE_TOKEN_AMOUNT_() external view returns (uint256);

    function _BASE_BALANCE_() external view returns (uint256);

    function _QUOTE_BALANCE_() external view returns (uint256);

    function getOraclePrice() external view returns (uint256);

    function getWithdrawBasePenalty(uint256 amountLp) external view returns (uint256);

    enum RStatus {ONE, ABOVE_ONE, BELOW_ONE}

}

interface IDODOV1Helper {
    function querySellQuoteToken(
        address dodoV1Pool,
        uint256 quoteAmount
    ) external view returns (uint256 receivedBaseAmount);

    function querySellBaseToken(
        address dodoV1Pool,
        uint256 baseAmount
    ) external view returns (uint256 receivedQuoteAmount);
}

interface IDODOV2 {
    function querySellBase(
        address trader,
        uint256 payBaseAmount
    ) external view returns (uint256 receiveQuoteAmount, uint256 mtFee);

    function querySellQuote(
        address trader,
        uint256 payQuoteAmount
    ) external view returns (uint256 receiveBaseAmount, uint256 mtFee);
}


import "@overnight-contracts/common/contracts/libraries/SafeMath.sol";
import "@overnight-contracts/common/contracts/libraries/DecimalMath.sol";


library StrategyDodoLibrary {
    using SafeMath for uint256;


    struct Context {
        IDODOV1 dodo;
        uint256 amountOut;
        uint256 fairAmount;
        uint256 targetBase;
        uint256 dd;
        uint256 a;
        uint256 b;
        uint256 c;
        uint256 d;
        uint256 e;
        uint256 g;
        uint256 h;
        uint256 i;
    }

    function _getAmountIn(uint256 amountOut, IDODOV1 dodo) internal view returns (uint256) {
        if (dodo._R_STATUS_() != IDODOV1.RStatus.ABOVE_ONE) {
            return amountOut;
        }

        Context memory ctx;
        ctx.dodo = dodo;
        ctx.amountOut = amountOut;

        ctx.fairAmount = _fairAmount(ctx);
        ctx.targetBase = _solveQuadraticFunctionForTargetCeil(ctx);

        ctx.dd = getDD(ctx);
        ctx.a = getA(ctx);
        ctx.b = getB(ctx);
        ctx.c = getC(ctx);
        ctx.d = getD(ctx);
        ctx.e = getE(ctx);
        ctx.g = getG(ctx);
        ctx.h = getH(ctx);
        ctx.i = getI(ctx);

        uint256 underSqrt = ctx.a.add(ctx.c).add(ctx.d).add(ctx.e).sub(ctx.b);
        uint256 sqrt = underSqrt.sqrt();
        uint256 t1 = ctx.g.add(sqrt);
        uint256 t2 = t1.mul(1e18).div(ctx.i);
        uint256 res = ctx.h.sub(t2);

        return res;
    }


    function _fairAmount(Context memory ctx) internal view returns (uint256){
        uint256 spareQuote = ctx.dodo._QUOTE_BALANCE_().sub(ctx.dodo._TARGET_QUOTE_TOKEN_AMOUNT_());
        uint256 price = ctx.dodo.getOraclePrice();
        uint256 fairAmount = DecimalMath.divFloor(spareQuote, price);
        return fairAmount;
    }

    function getDD(Context memory ctx) internal view returns (uint256){
        return ctx.dodo._BASE_BALANCE_().mul(2).sub(ctx.amountOut);
    }

    function getA(Context memory ctx) internal view returns (uint256){
        return ctx.fairAmount.mul(ctx.fairAmount).add(ctx.targetBase.mul(ctx.targetBase));
    }

    function getB(Context memory ctx) internal view returns (uint256){

        uint256 t1 = ctx.fairAmount.mul(ctx.dodo._K_()).mul(2).div(1e18);
        uint256 t2 = ctx.dd.add(ctx.fairAmount).add(t1);
        uint256 t3 = t2.mul(ctx.targetBase).mul(2);

        return t3;
    }

    function getC(Context memory ctx) internal view returns (uint256){
        return ctx.dd.mul(ctx.fairAmount).mul(2);
    }

    function getD(Context memory ctx) internal view returns (uint256){
        return ctx.c.mul(ctx.dodo._K_()).mul(2).div(1e18);
    }

    function getE(Context memory ctx) internal view returns (uint256){
        return ctx.dd.mul(ctx.dd);
    }

    function getG(Context memory ctx) internal view returns (uint256){
        return ctx.targetBase.add(ctx.fairAmount).sub(ctx.dd);
    }

    function getH(Context memory ctx) internal view returns (uint256){
        return ctx.targetBase.add(ctx.dodo._BASE_BALANCE_()).sub(ctx.dd);
    }

    function getI(Context memory ctx) internal view returns (uint256){
        return ctx.dodo._K_().mul(2).add(uint256(2).mul(1e18));
    }


    function _solveQuadraticFunctionForTargetCeil(
        Context memory ctx
    ) internal view returns (uint256) {
        uint256 V1 = ctx.dodo._BASE_BALANCE_();
        uint256 k = ctx.dodo._K_();

        // V0 = V1+V1*(sqrt-1)/2k
        uint256 sqrt = DecimalMath.divCeil(DecimalMath.mulCeil(k, ctx.fairAmount).mul(4), V1);
        sqrt = sqrt.add(DecimalMath.ONE).mul(DecimalMath.ONE).sqrt();
        uint256 premium = DecimalMath.divCeil(sqrt.sub(DecimalMath.ONE), k.mul(2));
        // V0 is greater than or equal to V1 according to the solution
        return DecimalMath.mul(V1, DecimalMath.ONE.add(premium));
    }
}


abstract contract DodoExchange {

    IDODOV1Helper private dodoV1Helper;
    IDODOProxy private dodoProxy;
    address private dodoApprove;

    function _setDodoParams(
        address _dodoV1Helper,
        address _dodoProxy,
        address _dodoApprove
    ) internal {
        dodoV1Helper = IDODOV1Helper(_dodoV1Helper);
        dodoProxy = IDODOProxy(_dodoProxy);
        dodoApprove = _dodoApprove;
    }

    /*
        The code example assumes user wanting to use the specify DODOV1 pool for swapping

        Note: Differentiate sellBaseToken or sellQuoteToken. If sellBaseToken represents 0, sellQuoteToken represents 1.
        At the same time, dodoSwapV1 supports multi-hop linear routing, so here we use 0,1
        combination to represent the multi-hop directions to save gas consumption
        For example:
            A - B - C (A - B sellBase and  B - C sellQuote)  Binary: 10, Decimal 2 (directions = 2)
            D - E - F (D - E sellQuote and E - F sellBase) Binary: 01, Decimal 1 (directions = 1)
    */
    function _useDodoSwapV1(
        address dodoV1Pool,
        address fromToken,
        address toToken,
        uint256 fromTokenAmount,
        uint256 slippage,
        uint256 directions
    ) internal returns (uint256) {

        uint256 minReturnAmount;
        if (directions == 0) {
            uint256 receivedQuoteAmount = dodoV1Helper.querySellBaseToken(dodoV1Pool, fromTokenAmount);
            minReturnAmount = receivedQuoteAmount * (100 - slippage) / 100;
        } else {
            uint256 receivedBaseAmount = dodoV1Helper.querySellQuoteToken(dodoV1Pool, fromTokenAmount);
            minReturnAmount = receivedBaseAmount * (100 - slippage) / 100;
        }
        if (minReturnAmount == 0) {
            return 0;
        }

        address[] memory dodoPairs = new address[](1); //one-hop
        dodoPairs[0] = dodoV1Pool;

        IERC20(fromToken).approve(dodoApprove, fromTokenAmount);

        return dodoProxy.dodoSwapV1(
            fromToken,
            toToken,
            fromTokenAmount,
            minReturnAmount,
            dodoPairs,
            directions,
            false,
            block.timestamp + 600
        );
    }

    /*
        The code example assumes user wanting to use the specify DODOV2 pool for swapping

        Note: Differentiate sellBaseToken or sellQuoteToken. If sellBaseToken represents 0, sellQuoteToken represents 1.
        At the same time, dodoSwapV1 supports multi-hop linear routing, so here we use 0,1
        combination to represent the multi-hop directions to save gas consumption
        For example:
            A - B - C (A - B sellBase and  B - C sellQuote)  Binary: 10, Decimal 2 (directions = 2)
            D - E - F (D - E sellQuote and E - F sellBase) Binary: 01, Decimal 1 (directions = 1)
    */
    function _useDodoSwapV2(
        address dodoV2Pool,
        address fromToken,
        address toToken,
        uint256 fromTokenAmount,
        uint256 slippage,
        uint256 directions
    ) internal returns (uint256) {

        uint256 minReturnAmount;
        if (directions == 0) {
            (uint256 receiveQuoteAmount,) = IDODOV2(dodoV2Pool).querySellBase(address(this), fromTokenAmount);
            minReturnAmount = receiveQuoteAmount * (100 - slippage) / 100;
        } else {
            (uint256 receiveBaseAmount,) = IDODOV2(dodoV2Pool).querySellQuote(address(this), fromTokenAmount);
            minReturnAmount = receiveBaseAmount * (100 - slippage) / 100;
        }
        if (minReturnAmount == 0) {
            return 0;
        }

        address[] memory dodoPairs = new address[](1); //one-hop
        dodoPairs[0] = dodoV2Pool;

        IERC20(fromToken).approve(dodoApprove, fromTokenAmount);

        return dodoProxy.dodoSwapV2TokenToToken(
            fromToken,
            toToken,
            fromTokenAmount,
            minReturnAmount,
            dodoPairs,
            directions,
            false,
            block.timestamp + 600
        );
    }

}
