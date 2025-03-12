// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library StableUtils {

    /// @dev copied from https://github.com/ThenafiBNB/THENA-Contracts/blob/f5bc742e1ff16c8be308a271a6a4a0e8f9e06453/contracts/Pair.sol#L467-L473
    function amount0(
        uint256 _amount1,
        uint256 _reserve0,
        uint256 _reserve1,
        uint256 _base0,
        uint256 _base1
    ) external pure returns (uint256 _amount0) {
        uint256 xy = _k(_reserve0, _reserve1, _base0, _base1);
        _reserve0 = (_reserve0 * 1e18) / _base0;
        _reserve1 = (_reserve1 * 1e18) / _base1;
        _amount1 = (_amount1 * 1e18) / _base1;
        _amount0 = _reserve0 - _y(_amount1 + _reserve1, xy, _reserve0);
        _amount0 = (_amount0 * _base0) / 1e18;
    }

    /// @dev copied from https://github.com/ThenafiBNB/THENA-Contracts/blob/f5bc742e1ff16c8be308a271a6a4a0e8f9e06453/contracts/Pair.sol#L467-L473
    function amount1(
        uint256 _amount0,
        uint256 _reserve0,
        uint256 _reserve1,
        uint256 _base0,
        uint256 _base1
    ) external pure returns (uint256 _amount1) {
        uint256 xy = _k(_reserve0, _reserve1, _base0, _base1);
        _reserve0 = (_reserve0 * 1e18) / _base0;
        _reserve1 = (_reserve1 * 1e18) / _base1;
        _amount0 = (_amount0 * 1e18) / _base0;
        _amount1 = _reserve1 - _y(_amount0 + _reserve0, xy, _reserve1);
        _amount1 = (_amount1 * _base1) / 1e18;
    }

    /// @dev copied from https://github.com/ThenafiBNB/THENA-Contracts/blob/f5bc742e1ff16c8be308a271a6a4a0e8f9e06453/contracts/Pair.sol#L482-L486
    function _k(uint256 x, uint256 y, uint256 base0, uint256 base1) private pure returns (uint256) {
        uint256 _x = x * 1e18 / base0;
        uint256 _y = y * 1e18 / base1;
        uint256 _a = (_x * _y) / 1e18;
        uint256 _b = ((_x * _x) / 1e18 + (_y * _y) / 1e18);

        return (_a * _b) / 1e18; // x3y+y3x >= k
    }

    /// @dev copied from https://github.com/ThenafiBNB/THENA-Contracts/blob/f5bc742e1ff16c8be308a271a6a4a0e8f9e06453/contracts/Pair.sol#L428-L428
    function _f(uint256 x0, uint256 y) private pure returns (uint256) {
        return x0*(y*y/1e18*y/1e18)/1e18+(x0*x0/1e18*x0/1e18)*y/1e18;
    }

    /// @dev copied from https://github.com/ThenafiBNB/THENA-Contracts/blob/f5bc742e1ff16c8be308a271a6a4a0e8f9e06453/contracts/Pair.sol#L432-L432
    function _d(uint256 x0, uint256 y) private pure returns (uint256) {
        return 3*x0*(y*y/1e18)/1e18+(x0*x0/1e18*x0/1e18);
    }

    /// @dev copied from https://github.com/ThenafiBNB/THENA-Contracts/blob/f5bc742e1ff16c8be308a271a6a4a0e8f9e06453/contracts/Pair.sol#L436-L456
    function _y(uint256 x0, uint256 xy, uint256 y)
        private
        pure
        returns (uint256)
    {
        for (uint i = 0; i < 255; i++) {
            uint y_prev = y;
            uint k = _f(x0, y);
            if (k < xy) {
                uint dy = (xy - k)*1e18/_d(x0, y);
                y = y + dy;
            } else {
                uint dy = (k - xy)*1e18/_d(x0, y);
                y = y - dy;
            }
            if (y > y_prev) {
                if (y - y_prev <= 1) {
                    return y;
                }
            } else {
                if (y_prev - y <= 1) {
                    return y;
                }
            }
        }
        return y;
    }

}