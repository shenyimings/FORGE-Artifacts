// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TickMath } from "./TickMath.sol";
import { GrowthX128, TickInfo } from "../types/common.sol";

library Tick {
    function tickSpacingToMaxLiquidityPerTick(int24 tickSpacing) internal pure returns (uint128) {
        unchecked {
            int24 minTick = (TickMath.MIN_TICK / tickSpacing) * tickSpacing;
            int24 maxTick = (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
            uint24 numTicks = uint24((maxTick - minTick) / tickSpacing) + 1;
            return type(uint128).max / numTicks;
        }
    }

    function getGrowthInside(
        mapping(int24 => TickInfo) storage self,
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent,
        GrowthX128 memory global
    )
        internal
        view
        returns (GrowthX128 memory inside)
    {
        unchecked {
            TickInfo storage lower = self[tickLower];
            TickInfo storage upper = self[tickUpper];

            GrowthX128 memory growthBelow;

            if (tickCurrent >= tickLower) {
                growthBelow.fee = lower.outside.fee;
                growthBelow.collateralIn = lower.outside.collateralIn;
                growthBelow.spearOut = lower.outside.spearOut;
                growthBelow.shieldOut = lower.outside.shieldOut;
            } else {
                growthBelow.fee = global.fee - lower.outside.fee;
                growthBelow.collateralIn = global.collateralIn - lower.outside.collateralIn;
                growthBelow.spearOut = global.spearOut - lower.outside.spearOut;
                growthBelow.shieldOut = global.shieldOut - lower.outside.shieldOut;
            }

            GrowthX128 memory growthAbove;

            if (tickCurrent < tickUpper) {
                growthAbove.fee = upper.outside.fee;
                growthAbove.collateralIn = upper.outside.collateralIn;
                growthAbove.spearOut = upper.outside.spearOut;
                growthAbove.shieldOut = upper.outside.shieldOut;
            } else {
                growthAbove.fee = global.fee - upper.outside.fee;
                growthAbove.collateralIn = global.collateralIn - upper.outside.collateralIn;
                growthAbove.spearOut = global.spearOut - upper.outside.spearOut;
                growthAbove.shieldOut = global.shieldOut - upper.outside.shieldOut;
            }
            inside.fee = global.fee - growthBelow.fee - growthAbove.fee;
            inside.collateralIn = global.collateralIn - growthBelow.collateralIn - growthAbove.collateralIn;
            inside.spearOut = global.spearOut - growthBelow.spearOut - growthAbove.spearOut;
            inside.shieldOut = global.shieldOut - growthBelow.shieldOut - growthAbove.shieldOut;
        }
    }

    function update(
        mapping(int24 => TickInfo) storage self,
        int24 tick,
        int24 tickCurrent,
        int128 liquidityDelta,
        GrowthX128 memory global,
        uint128 maxLiquidity,
        bool upper
    )
        internal
        returns (bool flipped)
    {
        TickInfo storage info = self[tick];

        uint128 liquidityGrossBefore = info.liquidityGross;
        uint128 liquidityGrossAfter =
            liquidityDelta < 0 ? liquidityGrossBefore - uint128(-liquidityDelta) : liquidityGrossBefore + uint128(liquidityDelta);

        require(liquidityGrossAfter <= maxLiquidity, "LO");

        flipped = (liquidityGrossAfter == 0) != (liquidityGrossBefore == 0);

        if (liquidityGrossBefore == 0) {
            if (tick <= tickCurrent) {
                info.outside.fee = global.fee;
                info.outside.collateralIn = global.collateralIn;
                info.outside.spearOut = global.spearOut;
                info.outside.shieldOut = global.shieldOut;
            }
            info.initialized = true;
        }

        info.liquidityGross = liquidityGrossAfter;
        info.liquidityNet = upper ? info.liquidityNet - liquidityDelta : info.liquidityNet + liquidityDelta;
    }

    function clear(mapping(int24 => TickInfo) storage self, int24 tick) internal {
        delete self[tick];
    }

    function cross(mapping(int24 => TickInfo) storage self, int24 tick, GrowthX128 memory global) internal returns (int128 liquidityNet) {
        unchecked {
            TickInfo storage info = self[tick];
            info.outside.fee = global.fee - info.outside.fee;
            info.outside.collateralIn = global.collateralIn - info.outside.collateralIn;
            info.outside.spearOut = global.spearOut - info.outside.spearOut;
            info.outside.shieldOut = global.shieldOut - info.outside.shieldOut;
            liquidityNet = info.liquidityNet;
        }
    }
}
