// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../interfaces/vendor/ICurvePoolV1.sol";
import "../interfaces/vendor/ICurveLpTokenV3.sol";

import "./ScaledMath.sol";
import "./SquareRoot.sol";

library CurveLPTokenPricing {
    using SafeCast for int256;
    using ScaledMath for uint256;
    using ScaledMath for int256;
    using SquareRoot for uint256;

    uint256 internal constant THRESHOLD_LOW_PREC = 10 ** 3;
    uint256 internal constant A_PREC = 100;

    function calcA(uint256 D, uint256 A, uint8 n) internal pure returns (int256) {
        return int256((D * A_PREC) / (A * n)) - int256(D);
    }

    function calcB(uint256 D, uint256 A, uint8 n) internal pure returns (uint256) {
        return (D.intPow(n + 1) * A_PREC) / (A * n ** (2 * n - 1));
    }

    function calcR(uint256 x, uint256 b, int256 a) internal pure returns (uint256) {
        x = x.downscale(18, 6);
        b = b.downscale(18, 6);
        a = a.downscale(18, 6);
        int256 aPlusX = a + int256(x);
        uint256 aPlusXSq = uint256(aPlusX.mulDown(aPlusX, 6));
        uint256 rest = (4 * b + x.mulDown(aPlusXSq, 6));
        uint256 r = _sqrtLowPrec(x).mulDown(_sqrtLowPrec(rest), 6);
        return r.upscale(6, 18);
    }

    function computeDfSForXAndS(
        uint256 D,
        uint256 A,
        uint256 x,
        uint256 s,
        uint8 n
    ) internal pure returns (int256) {
        int256 a = calcA(D, A, n);
        uint256 b = calcB(D, A, n);
        uint256 r = calcR(x, b, a);

        int256 ix = int256(x);

        int256 numLeft = -2 * int256(b);
        int256 numRight = ix.mulDown(int256(a).mulDown(ix) + ix.mulDown(ix) - int256(r));
        int256 result = numLeft + numRight;

        result /= 2;
        result = result.downscale(18, 6);
        result = result.divDown(ix.downscale(18, 6), 6);
        result = result.divDown(int256(r).downscale(18, 6), 6);
        result = result.upscale(6, 18);

        return -int256(s) - result;
    }

    function computeDDfForX(
        uint256 D,
        uint256 A,
        uint256 x,
        uint8 n
    ) internal pure returns (int256) {
        int256 a = calcA(D, A, n);
        uint256 b = calcB(D, A, n);

        uint256 b6Dec = b.downscale(18, 6);
        uint256 x6Dec = x.downscale(18, 6);
        int256 a6Dec = a.downscale(18, 6);

        int256 aPlusX6Dec = a6Dec + int256(x6Dec);

        uint256 base = 4 * b6Dec + x6Dec.mulDown(uint256(aPlusX6Dec.mulDown(aPlusX6Dec, 6)), 6);

        uint256 t1 = 6 * b6Dec;
        t1 = t1.divDown(x6Dec, 6);
        t1 = t1.divDown(x6Dec, 6);
        t1 = t1.mulDown(b6Dec, 6);
        t1 = t1.divDown(base, 6);
        t1 = t1.upscale(6, 18);

        int256 t2 = 2 * int256(b);
        t2 = t2.divDown(int256(x));
        t2 = t2.mulDown(a);
        t2 = t2.divDown(int256(base.upscale(6, 18)));
        t2 = t2.mulDown(a);

        int256 t3 = 6 * int256(b6Dec);
        t3 = t3.divDown(int256(base), 6);
        t3 = t3.upscale(6, 18);
        t3 = t3.mulDown(a);

        uint256 t4 = 6 * b6Dec;
        t4 = t4.divDown(base, 6);
        t4 = t4.upscale(6, 18);
        t4 = t4.mulDown(x);

        int256 numerator = int256(t1) + t2 + t3 + int256(t4);
        uint256 denominator = uint256(_sqrtLowPrec(x6Dec).mulDown(_sqrtLowPrec(base), 6));
        denominator = denominator.upscale(6, 18);

        return -numerator.divDown(int256(denominator));
    }

    function nextIter(
        uint256 D,
        uint256 A,
        uint256 x,
        uint256 s,
        uint8 n
    ) internal pure returns (uint256) {
        int256 numerator = computeDfSForXAndS(D, A, x, s, n);
        int256 denominator = computeDDfForX(D, A, x, n);
        int256 adjust = numerator.divDown(denominator);

        if (adjust < 0) {
            return x + uint256(-adjust);
        }

        uint256 uAdjust = uint256(adjust);

        if (uAdjust >= x) {
            uAdjust = x / 2;
        }

        return x - uAdjust;
    }

    function calcYFromD(uint256 D, uint256 A, uint256 price) internal pure returns (uint256) {
        uint256 xCur = D;
        uint256 xPrev = 0;
        for (uint256 i = 0; i < 255; i++) {
            xCur = nextIter(D, A, xCur, price, 2);
            if (xCur.absSub(xPrev) <= 10 ** 16) {
                break;
            }
            xPrev = xCur;
        }
        return xCur - 5 * 10 ** 17;
    }

    /// @notice this computes `calcYFromXCrv` for a pool with 2 tokens
    function calcYFromXCrv(uint256 x, uint256 A, uint256 D) internal pure returns (uint256) {
        return calcYFromXCrv(x, A, D, 2);
    }

    function calcYFromXCrv(
        uint256 x,
        uint256 A,
        uint256 D,
        uint8 n
    ) internal pure returns (uint256) {
        uint256 Ann = A * n;
        uint256 c = D * A_PREC;
        c = c.mulDown(D).divDown(x * n);
        c = c.mulDown(D) / (Ann * n);
        uint256 b = x + (D * A_PREC) / Ann;
        uint256 y = D;
        uint256 yPrev = 0;
        for (uint256 i = 0; i < 255; i++) {
            yPrev = y;
            y = (y.mulDown(y) + c).divDown(2 * y + b - D);
            if (y.absSub(yPrev) < ScaledMath.ONE) {
                return y;
            }
        }
        return y;
    }

    function getV1LpTokenPrice(
        ICurvePoolV1 pool,
        uint256 priceA,
        uint256 priceB
    ) internal view returns (uint256) {
        uint256 totalSupply = ICurveLpTokenV3(pool.lp_token()).totalSupply();
        uint256 D = pool.get_virtual_price().mulDown(totalSupply);
        uint256 A_precise = pool.A_precise();
        uint256 amountAssetA = calcYFromD(D, A_precise, priceA);
        uint256 amountAssetB = calcYFromXCrv(amountAssetA, A_precise, D);
        uint256 tokenPrice = (amountAssetA * priceA + amountAssetB * priceB) / totalSupply;
        return tokenPrice;
    }

    function _sqrtLowPrec(uint256 x) internal pure returns (uint256) {
        return x.sqrt(THRESHOLD_LOW_PREC, SquareRoot.Precision.Low);
    }
}
