// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { SafeCast } from "@oz/utils/math/SafeCast.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { UnsafeMath } from "@uniswap/v3-core/contracts/libraries/UnsafeMath.sol";
import { FixedPoint96 } from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";

library DiverSqrtPriceMath {
    using SafeCast for uint256;
    using SafeCast for int128;

    /**
     * todo formula
     * amount = liquidity * (sqrtRatioBX96 - sqrtRatioAX96) * (1 + 1 /
     * (sqrtRatioAX96 * sqrtRatioBX96));
     *
     */
    function getSTokenDelta(uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, uint128 liquidity, bool roundUp) internal pure returns (uint256 amount) {
        if (sqrtRatioAX96 > sqrtRatioBX96) {
            (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        }
        if (roundUp) {
            uint256 l = uint256(liquidity) << FixedPoint96.RESOLUTION;
            uint256 l1 = FullMath.mulDivRoundingUp(l, sqrtRatioBX96 - sqrtRatioAX96, FixedPoint96.Q96);
            uint256 l2 = FullMath.mulDivRoundingUp(sqrtRatioAX96, sqrtRatioBX96, FixedPoint96.Q96) + FixedPoint96.Q96;
            uint256 l3 = FullMath.mulDivRoundingUp(l1, l2, sqrtRatioBX96);
            amount = UnsafeMath.divRoundingUp(l3, sqrtRatioAX96);
        } else {
            uint256 l = uint256(liquidity) << FixedPoint96.RESOLUTION;
            uint256 l1 = FullMath.mulDiv(l, sqrtRatioBX96 - sqrtRatioAX96, FixedPoint96.Q96);
            uint256 l2 = FullMath.mulDiv(sqrtRatioAX96, sqrtRatioBX96, FixedPoint96.Q96) + FixedPoint96.Q96;
            uint256 l3 = FullMath.mulDiv(l1, l2, sqrtRatioBX96);
            amount = l3 / sqrtRatioAX96;
        }
    }

    function getSTokenDelta(uint160 sqrtPriceAX96, uint160 sqrtPriceBX96, int128 liquidity) internal pure returns (int256 amount) {
        if (sqrtPriceAX96 > sqrtPriceBX96) {
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
        }
        if (liquidity < 0) {
            amount = -getSTokenDelta(sqrtPriceAX96, sqrtPriceBX96, uint128(-liquidity), false).toInt256();
        } else {
            amount = getSTokenDelta(sqrtPriceAX96, sqrtPriceBX96, uint128(liquidity), true).toInt256();
        }
    }
}
