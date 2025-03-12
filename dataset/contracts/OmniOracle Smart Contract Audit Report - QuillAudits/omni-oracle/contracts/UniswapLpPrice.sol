// SPDX-License-Identifier: UNLICENCED
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";
import "./Math.sol";
import "./UniswapHelper.sol";
import "./IERC20Extended.sol";
import "./UniswapConfig.sol";

/** @title UniswapLpPrice
 * @notice Price provider for a Uniswap V2 pair token
 * It calculates the price using an external price source and uses a weighted geometric mean with the constant invariant K.
 */

abstract contract UniswapLpPrice {
    using SafeMath for uint256;

    /**
     * @dev Returns the pair's token price.
     *   It calculates the price using an external price source and uses a weighted geometric mean with the constant invariant K.
     * @param pairAddress Address of Uni V2 pair.
     * @param uniLpCalcParams UniLpCalcParams for pair.
     * @return int256 price
     */
    function getPairTokenPriceUsd(
        address pairAddress,
        UniswapConfig.UniLpCalcParams memory uniLpCalcParams
    ) public view returns (uint256) {
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        //Get token reserves in ethers
        (uint112 reserve_0, uint112 reserve_1, ) = pair.getReserves();
        address token_0 = pair.token0();
        address token_1 = pair.token1();

        uint256 usdTotal_0 = getUsdBalanceByToken(token_0, reserve_0);
        uint256 usdTotal_1 = getUsdBalanceByToken(token_1, reserve_1);

        //Calculate the weighted geometric mean
        return
            getWeightedGeometricMean(
                pair,
                usdTotal_0,
                usdTotal_1,
                uniLpCalcParams
            );
    }

    function getUsdBalanceByToken(address token, uint112 reserves)
        internal
        view
        returns (uint256)
    {
        uint256 tokenPrice = price(token);
        require(tokenPrice > 0, "UniswapLpPrice: no price found");

        // SafeMath will throw when decimals > 18
        uint256 missingDecimals = uint256(18).sub(IERC20(token).decimals());
        uint256 balance = uint256(reserves).mul(10**(missingDecimals));
        return Math.bmul(balance, tokenPrice);
    }

    function price(address token) public view virtual returns (uint256);

    /**
     * Calculates the price of the pair token using the formula of weighted geometric mean.
     * @param pair Uniswap V2 pair address.
     * @param usdTotal_0 Total usd for token 0.
     * @param usdTotal_1 Total usd for token 1.
     * @param uniLpCalcParams UniLpCalcParams for pair.
     */
    function getWeightedGeometricMean(
        IUniswapV2Pair pair,
        uint256 usdTotal_0,
        uint256 usdTotal_1,
        UniswapConfig.UniLpCalcParams memory uniLpCalcParams
    ) internal view returns (uint256) {
        uint256 square = Math.bsqrt(Math.bmul(usdTotal_0, usdTotal_1), true);
        return
            Math.bdiv(
                Math.bmul(Math.TWO_BONES, square),
                getTotalSupplyAtWithdrawal(pair, uniLpCalcParams)
            );
    }

    /**
     * Returns Uniswap V2 pair total supply at the time of withdrawal.
     */
    function getTotalSupplyAtWithdrawal(
        IUniswapV2Pair pair,
        UniswapConfig.UniLpCalcParams memory uniLpCalcParams
    ) private view returns (uint256 totalSupply) {
        totalSupply = pair.totalSupply();
        address feeTo = IUniswapV2Factory(IUniswapV2Pair(pair).factory())
            .feeTo();
        bool feeOn = feeTo != address(0);
        if (feeOn) {
            uint256 kLast = IUniswapV2Pair(pair).kLast();
            if (kLast != 0) {
                (uint112 reserve_0, uint112 reserve_1, ) = pair.getReserves();
                uint256 rootK = Math.bsqrt(
                    uint256(reserve_0).mul(reserve_1),
                    false
                );
                uint256 rootKLast = Math.bsqrt(kLast, false);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply
                        .mul(rootK.sub(rootKLast))
                        .mul(uniLpCalcParams.numFactor);
                    uint256 denominator = rootK
                        .mul(uniLpCalcParams.denoFactor)
                        .add(rootKLast.mul(uniLpCalcParams.numFactor));
                    uint256 liquidity = numerator / denominator;
                    totalSupply = totalSupply.add(liquidity);
                }
            }
        }
    }
}
