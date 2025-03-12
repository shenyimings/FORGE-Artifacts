// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@overnight-contracts/connectors/contracts/stuff/AaveV3.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV3.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";

// Don't use
library AaveBorrowLibrary {

    function getAavePool(
        address aavePoolAddressesProvider,
        uint8 eModeCategoryId
    ) internal returns (address aavePool) {
        aavePool = IPoolAddressesProvider(aavePoolAddressesProvider).getPool();
        IPool(aavePool).setUserEMode(eModeCategoryId);
    }

    function getAavePool(
        address aavePoolAddressesProvider
    ) internal view returns (address aavePool) {
        aavePool = IPoolAddressesProvider(aavePoolAddressesProvider).getPool();
    }

    function getCollateralAndBorrowForSupplyAndBorrow(
        uint256 amount0,
        uint256 reserve0,
        uint256 reserve1,
        uint256 LT,
        uint256 HF,
        uint256 token0Denominator,
        uint256 token1Denominator,
        uint256 price0,
        uint256 price1
    ) internal pure returns (uint256 collateral0, uint256 borrow1) {
        uint256 reserve1InToken0 = convertTokenAmountToTokenAmount(reserve1, token1Denominator, token0Denominator, price1, price0);
        collateral0 = amount0 * HF / (HF + LT * reserve0 / reserve1InToken0);
        uint256 collateral1 = convertTokenAmountToTokenAmount(collateral0, token0Denominator, token1Denominator, price0, price1);
        borrow1 = collateral1 * LT / HF;
    }

    function getBorrowForWithdraw(
        uint256 collateral0,
        uint256 reserve0,
        uint256 reserve1,
        uint256 LT,
        uint256 HF,
        uint256 token0Denominator,
        uint256 token1Denominator,
        uint256 price0,
        uint256 price1
    ) internal pure returns (uint256 borrow1) {
        uint256 collateral1 = convertTokenAmountToTokenAmount(collateral0, token0Denominator, token1Denominator, price0, price1);
        //usdc to usdt
        uint256 reserve1InToken0 = convertTokenAmountToTokenAmount(reserve1, token1Denominator, token0Denominator, price1, price0);
        //usdt to usdc
        borrow1 = (collateral1 * LT * reserve1InToken0) / (HF * reserve1InToken0 + LT * reserve0);
    }

    // function getBorrowForWithdraw(
    //     uint256 collateral0,
    //     uint256 totalCollateralUsd,
    //     uint256 totalBorrowUsd,
    //     uint256 reserve0,
    //     uint256 reserve1,
    //     uint256 LT,
    //     uint256 HF,
    //     uint256 token0Denominator,
    //     uint256 token1Denominator,
    //     uint256 price0,
    //     uint256 price1
    // ) internal pure returns (uint256 borrow1) {
    //     uint256 totalBorrowUsd1 = convertUsdToTokenAmount(totalBorrowUsd, token1Denominator, price1);   //usd to usdt
    //     uint256 totalCollateralUsd1 = convertUsdToTokenAmount(totalCollateralUsd, token1Denominator, price1); //usd to usdt
    //     uint256 collateral1 = convertTokenAmountToTokenAmount(collateral0, token0Denominator, token1Denominator, price0, price1); //usdc to usdt
    //     uint256 reserve1InToken0 = convertTokenAmountToTokenAmount(reserve1, token1Denominator, token0Denominator, price1, price0); //usdt to usdc
    //     borrow1 = (totalBorrowUsd1 * HF + collateral1 * LT - totalCollateralUsd1 * LT) / (HF + LT * reserve0 / reserve1InToken0);
    // }

    // function getLpTokensForWithdraw(
    //     uint256 totalLpBalance,
    //     uint256 borrow1,
    //     uint256 reserve0,
    //     uint256 reserve1,
    //     uint256 token0Denominator,
    //     uint256 token1Denominator,
    //     uint256 price0,
    //     uint256 price1
    // ) internal pure returns (uint256 lpTokensToWithdraw) {
    //     uint256 borrow0 = convertTokenAmountToTokenAmount(borrow1, token1Denominator, token0Denominator, price1, price0);
    //     uint256 reserve1InToken0 = convertTokenAmountToTokenAmount(reserve1, token1Denominator, token0Denominator, price1, price0);
    //     lpTokensToWithdraw = totalLpBalance * (borrow0 + borrow1 * reserve0 / reserve1) / (reserve0 + reserve1InToken0);
    // }

    struct GetWithdrawAmountForBalanceParams {
        uint256 totalCollateralUsd;
        uint256 totalBorrowUsd;
        uint256 reserve0;
        uint256 reserve1;
        uint256 LT;
        uint256 HF;
        uint256 token0Denominator;
        uint256 token1Denominator;
        uint256 price0;
        uint256 price1;
    }

    function getWithdrawAmountForBalance(
        GetWithdrawAmountForBalanceParams memory params
    ) internal pure returns (uint256 withdrawAmount) {
        uint256 reserve1InUsd = convertTokenAmountToUsd(params.reserve1, params.token1Denominator, params.price1);
        uint256 reserve0InUsd = convertTokenAmountToUsd(params.reserve0, params.token0Denominator, params.price0);
        withdrawAmount = FullMath.mulDivRoundingUp(
            params.reserve0,
            params.totalCollateralUsd * params.LT - params.totalBorrowUsd * params.HF,
            reserve1InUsd * params.HF + reserve0InUsd * params.LT
        );
    }

    function getBorrowIfZeroAmountForBalance(
        GetWithdrawAmountForBalanceParams memory params
    ) internal pure returns (uint256 withdrawAmount) {
        withdrawAmount = (params.totalCollateralUsd * params.LT - params.totalBorrowUsd * params.HF) / (params.HF);
        withdrawAmount = convertUsdToTokenAmount(withdrawAmount, params.token1Denominator, params.price1);
    }

    struct GetLpTokensForBalanceParams {
        uint256 totalCollateralUsd;
        uint256 totalBorrowUsd;
        uint256 reserve0;
        uint256 reserve1;
        uint256 LT;
        uint256 HF;
        uint256 token0Denominator;
        uint256 token1Denominator;
        uint256 price0;
        uint256 price1;
        uint256 totalSuply;
    }

    function getLpTokensForBalance(
        GetLpTokensForBalanceParams memory params
    ) internal pure returns (uint256 lpTokens) {
        uint256 reserve1InUsd = convertTokenAmountToUsd(params.reserve1, params.token1Denominator, params.price1);
        uint256 reserve0InUsd = convertTokenAmountToUsd(params.reserve0, params.token0Denominator, params.price0);
        lpTokens = FullMath.mulDivRoundingUp(
            params.totalSuply,
            params.totalBorrowUsd * params.HF - params.totalCollateralUsd * params.LT,
            reserve1InUsd * params.HF + reserve0InUsd * params.LT
        );
    }

    function convertTokenAmountToTokenAmount(
        uint256 amount0,
        uint256 token0Denominator,
        uint256 token1Denominator,
        uint256 price0,
        uint256 price1
    ) internal pure returns (uint256 amount1) {
        amount1 = (amount0 * token1Denominator * price0) / (token0Denominator * price1);
    }

    function convertTokenAmountToUsd(
        uint256 amount,
        uint256 tokenDenominator,
        uint256 price
    ) internal pure returns (uint256 amountUsd) {
        amountUsd = amount * price / tokenDenominator;
    }

    function convertUsdToTokenAmount(
        uint256 amountUsd,
        uint256 tokenDenominator,
        uint256 price
    ) internal pure returns (uint256 amount) {
        amount = amountUsd * tokenDenominator / price;
    }

}
