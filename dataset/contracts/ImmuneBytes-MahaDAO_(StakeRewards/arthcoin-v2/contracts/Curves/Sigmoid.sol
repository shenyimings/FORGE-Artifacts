// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Math} from '../utils/math/Math.sol';
import {SafeMath} from '../utils/math/SafeMath.sol';

import {Curve} from './Curve.sol';

contract Sigmoid is Curve {
    using SafeMath for uint256;

    uint256[26] private slots; // Note: 26 slots including slot 0

    /**
     * Constructor.
     */

    constructor(
        uint256 _minX,
        uint256 _maxX,
        uint256 _minY,
        uint256 _maxY
    ) {
        minX = _minX;
        maxX = _maxX;
        minY = _minY;
        maxY = _maxY;

        slots[0] = 5e17; // 0.5
        slots[1] = 45e16; // 0.450
        slots[2] = 40e16; // 0.401
        slots[3] = 354e15; // 0.354
        slots[4] = 31e16; // 0.310
        slots[5] = 2689e14; // 0.2689
        slots[6] = 2314e14; // 0.2314
        slots[7] = 197e15; // 0.197
        slots[8] = 167e15; // 0.167
        slots[9] = 141e15; // 0.141
        slots[10] = 1192e14; // 0.1192
        slots[11] = 997e14; // 0.0997
        slots[12] = 831e14; // 0.0831
        slots[13] = 691e14; // 0.0691
        slots[14] = 573e14; // 0.0573
        slots[15] = 474e14; // 0.047
        slots[16] = 391e14; // 0.0391
        slots[17] = 322e14; // 0.0322
        slots[18] = 265e14; // 0.0265
        slots[19] = 218e14; // 0.0218
        slots[20] = 179e14; // 0.0179
        slots[21] = 147e14; // 0.0147
        slots[22] = 121e14; // 0.0121
        slots[23] = 995e13; // 0.00995
        slots[24] = 816e13; // 0.00816
        slots[25] = 669e13; // 0.00669
    }

    /**
     * Public.
     */

    function setMinX(uint256 x) public override onlyOwner {
        super.setMinX(x);
    }

    function setMaxX(uint256 x) public override onlyOwner {
        super.setMaxX(x);
    }

    function setMinY(uint256 y) public override onlyOwner {
        super.setMinY(y);
    }

    function setFixedY(uint256 y) public override onlyOwner {
        super.setFixedY(y);
    }

    function setMaxY(uint256 y) public override onlyOwner {
        super.setMaxY(y);
    }

    function getY(uint256 x) public view override returns (uint256) {
        if (x <= minX) return 0; // return maxY;

        // Fail safe to return after maxX.
        if (x >= maxX) return maxY;

        uint256 slotWidth = maxX.sub(minX).div(slots.length);
        uint256 xa = x.sub(minX).div(slotWidth);
        uint256 xb = Math.min(xa.add(1), slots.length.sub(1));

        uint256 slope = slots[xa].sub(slots[xb]).mul(1e18).div(slotWidth);
        uint256 wy = slots[xa].add(slope.mul(slotWidth.mul(xa)).div(1e18));

        uint256 percentage = 0;
        if (wy > slope.mul(x).div(1e18)) {
            percentage = wy.sub(slope.mul(x).div(1e18));
        } else {
            percentage = slope.mul(x).div(1e18).sub(wy);
        }

        return minY.add(maxY.sub(minY).mul(percentage).div(1e18));
    }
}
