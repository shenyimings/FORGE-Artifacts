// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.2;

contract CommonContext {
    // same unit in SafeDeicmalMath and SignedSafeDeicmalMath
    int internal constant _UNIT = int(10 ** 18);
    uint internal constant _UNSIGNED_UNIT = uint(10 ** 18);

    function _startOfDay(uint _t) internal pure returns (uint) {
        return (_t / 1 days) * 1 days;
    }

    function _startOfWeek(uint _t) internal pure returns (uint) {
        return (_t / 1 weeks) * 1 weeks;
    }
}
