// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../interfaces/vendor/ICurvePoolV2.sol";
import "../interfaces/vendor/ICurvePoolV1.sol";
import "./ScaledMath.sol";

library CurvePoolUtils {
    using ScaledMath for uint256;

    /// @dev by default, allow for 10 bps deviation regardless of pool fees
    uint256 internal constant _DEFAULT_IMBALANCE_BUFFER = 30e14;

    /// @dev Curve scales the `fee` by 1e10
    uint8 internal constant _CURVE_POOL_FEE_DECIMALS = 10;

    /// @dev allow imbalance to be buffer + 3x the fee, e.g. if fee is 3.6 bps and buffer is 30 bps, allow 40.8 bps
    uint256 internal constant _FEE_IMBALANCE_MULTIPLIER = 3;

    enum AssetType {
        USD,
        ETH,
        BTC,
        OTHER,
        CRYPTO
    }

    struct PoolMeta {
        address pool;
        uint256 numberOfCoins;
        AssetType assetType;
        uint256[] decimals;
        uint256[] prices;
        uint256[] imbalanceBuffers;
    }

    function ensurePoolBalanced(PoolMeta memory poolMeta) internal view {
        uint256 fromDecimals = poolMeta.decimals[0];
        uint256 fromBalance = 10 ** fromDecimals;
        uint256 fromPrice = poolMeta.prices[0];

        uint256 poolFee = ICurvePoolV1(poolMeta.pool).fee().convertScale(
            _CURVE_POOL_FEE_DECIMALS,
            18
        );
        for (uint256 i = 1; i < poolMeta.numberOfCoins; i++) {
            uint256 toDecimals = poolMeta.decimals[i];
            uint256 toPrice = poolMeta.prices[i];
            uint256 toExpectedUnscaled = (fromBalance * fromPrice) / toPrice;
            uint256 toExpected = toExpectedUnscaled.convertScale(
                uint8(fromDecimals),
                uint8(toDecimals)
            );

            uint256 toActual;

            if (poolMeta.assetType == AssetType.CRYPTO) {
                // Handling crypto pools
                toActual = ICurvePoolV2(poolMeta.pool).get_dy(0, i, fromBalance);
            } else {
                // Handling other pools
                toActual = ICurvePoolV1(poolMeta.pool).get_dy(0, int128(uint128(i)), fromBalance);
            }

            require(
                _isWithinThreshold(toExpected, toActual, poolFee, poolMeta.imbalanceBuffers[i]),
                "pool is not balanced"
            );
        }
    }

    function _isWithinThreshold(
        uint256 a,
        uint256 b,
        uint256 poolFee,
        uint256 imbalanceBuffer
    ) internal pure returns (bool) {
        if (imbalanceBuffer == 0) imbalanceBuffer = _DEFAULT_IMBALANCE_BUFFER;
        uint256 imbalanceTreshold = imbalanceBuffer + poolFee * _FEE_IMBALANCE_MULTIPLIER;
        if (a > b) return (a - b).divDown(a) <= imbalanceTreshold;
        return (b - a).divDown(b) <= imbalanceTreshold;
    }
}
