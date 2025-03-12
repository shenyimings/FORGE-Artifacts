// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { SafeCast } from "@oz/utils/math/SafeCast.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { FixedPoint128 } from "@uniswap/v3-core/contracts/libraries/FixedPoint128.sol";
import { PositionInfo, GrowthX128, Owed } from "../types/common.sol";

library Position {
    using SafeCast for uint256;

    function get(
        mapping(bytes32 => PositionInfo) storage self,
        address owner,
        int24 tickLower,
        int24 tickUpper
    )
        internal
        view
        returns (PositionInfo storage position)
    {
        position = self[keccak256(abi.encodePacked(owner, tickLower, tickUpper))];
    }

    function update(PositionInfo storage self, int128 liquidityDelta, GrowthX128 memory insideLast) internal {
        PositionInfo memory _self = self;

        uint128 liquidityNext;
        if (liquidityDelta == 0) {
            require(_self.liquidity > 0, "disallow pokes for 0 liquidity"); // disallow
                // pokes for 0 liquidity Positions
            liquidityNext = _self.liquidity;
        } else {
            liquidityNext = liquidityDelta < 0 ? _self.liquidity - uint128(-liquidityDelta) : _self.liquidity + uint128(liquidityDelta);
        }
        Owed memory tempOwed;
        unchecked {
            tempOwed.fee =
                _self.liquidity == 0 ? 0 : FullMath.mulDiv(insideLast.fee - _self.insideLast.fee, _self.liquidity, FixedPoint128.Q128).toUint128();
            tempOwed.collateralIn = _self.liquidity == 0
                ? 0
                : FullMath.mulDiv(insideLast.collateralIn - _self.insideLast.collateralIn, _self.liquidity, FixedPoint128.Q128).toUint128();
            tempOwed.spearOut = _self.liquidity == 0
                ? 0
                : FullMath.mulDiv(insideLast.spearOut - _self.insideLast.spearOut, _self.liquidity, FixedPoint128.Q128).toUint128();

            tempOwed.shieldOut = _self.liquidity == 0
                ? 0
                : FullMath.mulDiv(insideLast.shieldOut - _self.insideLast.shieldOut, _self.liquidity, FixedPoint128.Q128).toUint128();

            // update the Position
            if (liquidityDelta != 0) {
                self.liquidity = liquidityNext;
            }

            self.insideLast = insideLast;

            if (tempOwed.fee > 0) {
                self.owed.fee += tempOwed.fee;
            }

            if (tempOwed.collateralIn > 0) {
                self.owed.collateralIn += tempOwed.collateralIn;
            }

            if (tempOwed.spearOut > 0) {
                self.owed.spearOut += tempOwed.spearOut;
            }

            if (tempOwed.shieldOut > 0) {
                self.owed.shieldOut += tempOwed.shieldOut;
            }
        }
    }
}
