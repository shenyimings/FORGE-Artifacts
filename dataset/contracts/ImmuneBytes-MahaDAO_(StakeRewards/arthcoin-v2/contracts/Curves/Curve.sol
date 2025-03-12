// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ICurve} from './ICurve.sol';
import {Ownable} from '../access/Ownable.sol';

abstract contract Curve is ICurve, Ownable {
    /**
     * Events.
     */

    event MinXChanged(uint256 old, uint256 latest);

    event MaxXChanged(uint256 old, uint256 latest);

    event MinYChanged(uint256 old, uint256 latest);

    event MaxYChanged(uint256 old, uint256 latest);

    event FixedYChanged(uint256 old, uint256 latest);

    /**
     * State variables.
     */

    uint256 public override minX;
    uint256 public override maxX;
    uint256 public override minY;
    uint256 public override maxY;
    uint256 public override fixedY; // Fixed Y(Price in some graphs) in case needed.

    /**
     * Public.
     */

    function setMinX(uint256 x) public virtual onlyOwner {
        uint256 oldMinX = minX;
        minX = x;
        emit MinXChanged(oldMinX, minX);
    }

    function setMaxX(uint256 x) public virtual onlyOwner {
        uint256 oldMaxX = maxX;
        maxX = x;
        emit MaxXChanged(oldMaxX, maxX);
    }

    function setFixedY(uint256 y) public virtual onlyOwner {
        uint256 old = fixedY;
        fixedY = y;
        emit FixedYChanged(old, fixedY);
    }

    function setMinY(uint256 y) public virtual onlyOwner {
        uint256 oldMinY = minY;
        minY = y;
        emit MinYChanged(oldMinY, minY);
    }

    function setMaxY(uint256 y) public virtual onlyOwner {
        uint256 oldMaxY = maxY;
        maxY = y;
        emit MaxYChanged(oldMaxY, maxY);
    }

    function getY(uint256 x) external view virtual override returns (uint256);
}
