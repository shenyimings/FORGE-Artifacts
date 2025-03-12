// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../libraries/FixedPoint.sol";

contract FixedPointMock {
    using FixedPoint for uint256;

    function add(uint256 a, uint256 b) external pure returns (uint256) {
        return a.add(b);
    }

    function sub(uint256 a, uint256 b) external pure returns (uint256) {
        return a.sub(b);
    }

    function mulDown(uint256 a, uint256 b) external pure returns (uint256) {
        return a.mulDown(b);
    }

    function mulUp(uint256 a, uint256 b) external pure returns (uint256) {
        return a.mulUp(b);
    }

    function divDown(uint256 a, uint256 b) external pure returns (uint256) {
        return a.divDown(b);
    }

    function divUp(uint256 a, uint256 b) external pure returns (uint256) {
        return a.divUp(b);
    }

    function powDown(uint256 x, uint256 y) external pure returns (uint256) {
        return x.powDown(y);
    }

    function powUp(uint256 x, uint256 y) external pure returns (uint256) {
        return x.powUp(y);
    }

    function complement(uint256 x) external pure returns (uint256) {
        return x.complement();
    }
}
