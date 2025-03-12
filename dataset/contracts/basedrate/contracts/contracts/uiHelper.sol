// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./aerodrome/interfaces/IPool.sol";
import "@uniswap/v2-core/contracts/interfaces/IERC20.sol";

contract UIHelper {
    struct LPData {
        address token0;
        address token1;
        string symbol0;
        string symbol1;
        uint8 decimals0;
        uint8 decimals1;
        uint256 reserve0;
        uint256 reserve1;
        bool stable;
        uint256 supply;
        uint256 token0InToken1Out;
        uint256 token1InToken0Out;
    }

    function getLPData(
        IPool pool
    ) external view returns (LPData memory lpData) {
        lpData = LPData({
            token0: pool.token0(),
            token1: pool.token1(),
            symbol0: IERC20(pool.token0()).symbol(),
            symbol1: IERC20(pool.token1()).symbol(),
            decimals0: IERC20(pool.token0()).decimals(),
            decimals1: IERC20(pool.token1()).decimals(),
            reserve0: pool.reserve0(),
            reserve1: pool.reserve1(),
            stable: pool.stable(),
            supply: IERC20(address(pool)).totalSupply(),
            token0InToken1Out: _getAmountOut(
                10 ** IERC20(pool.token0()).decimals(),
                pool.token0(),
                pool.reserve0(),
                pool.reserve1(),
                pool.token0(),
                10 ** IERC20(pool.token0()).decimals(),
                10 ** IERC20(pool.token1()).decimals(),
                pool.stable()
            ),
            token1InToken0Out: _getAmountOut(
                10 ** IERC20(pool.token1()).decimals(),
                pool.token1(),
                pool.reserve0(),
                pool.reserve1(),
                pool.token0(),
                10 ** IERC20(pool.token0()).decimals(),
                10 ** IERC20(pool.token1()).decimals(),
                pool.stable()
            )
        });
    }

    function _f(uint256 x0, uint256 y) internal pure returns (uint256) {
        uint256 _a = (x0 * y) / 1e18;
        uint256 _b = ((x0 * x0) / 1e18 + (y * y) / 1e18);
        return (_a * _b) / 1e18;
    }

    function _d(uint256 x0, uint256 y) internal pure returns (uint256) {
        return
            (3 * x0 * ((y * y) / 1e18)) /
            1e18 +
            ((((x0 * x0) / 1e18) * x0) / 1e18);
    }

    function _k(
        uint256 x,
        uint256 y,
        bool stable,
        uint256 decimals0,
        uint256 decimals1
    ) internal pure returns (uint256) {
        if (stable) {
            uint256 _x = (x * 1e18) / decimals0;
            uint256 _y = (y * 1e18) / decimals1;
            uint256 _a = (_x * _y) / 1e18;
            uint256 _b = ((_x * _x) / 1e18 + (_y * _y) / 1e18);
            return (_a * _b) / 1e18; // x3y+y3x >= k
        } else {
            return x * y; // xy >= k
        }
    }

    function _get_y(
        uint256 x0,
        uint256 xy,
        uint256 y,
        bool stable,
        uint256 decimals0,
        uint256 decimals1
    ) internal pure returns (uint256) {
        for (uint256 i = 0; i < 255; i++) {
            uint256 k = _f(x0, y);
            if (k < xy) {
                // there are two cases where dy == 0
                // case 1: The y is converged and we find the correct answer
                // case 2: _d(x0, y) is too large compare to (xy - k) and the rounding error
                //         screwed us.
                //         In this case, we need to increase y by 1
                uint256 dy = ((xy - k) * 1e18) / _d(x0, y);
                if (dy == 0) {
                    if (k == xy) {
                        // We found the correct answer. Return y
                        return y;
                    }
                    if (_k(x0, y + 1, stable, decimals0, decimals1) > xy) {
                        // If _k(x0, y + 1) > xy, then we are close to the correct answer.
                        // There's no closer answer than y + 1
                        return y + 1;
                    }
                    dy = 1;
                }
                y = y + dy;
            } else {
                uint256 dy = ((k - xy) * 1e18) / _d(x0, y);
                if (dy == 0) {
                    if (k == xy || _f(x0, y - 1) < xy) {
                        // Likewise, if k == xy, we found the correct answer.
                        // If _f(x0, y - 1) < xy, then we are close to the correct answer.
                        // There's no closer answer than "y"
                        // It's worth mentioning that we need to find y where f(x0, y) >= xy
                        // As a result, we can't return y - 1 even it's closer to the correct answer
                        return y;
                    }
                    dy = 1;
                }
                y = y - dy;
            }
        }
        revert("!y");
    }

    function _getAmountOut(
        uint256 amountIn,
        address tokenIn,
        uint256 _reserve0,
        uint256 _reserve1,
        address _token0,
        uint256 _decimals0,
        uint256 _decimals1,
        bool _stable
    ) internal pure returns (uint256) {
        if (_stable) {
            uint256 xy = _k(
                _reserve0,
                _reserve1,
                _stable,
                _decimals0,
                _decimals1
            );
            _reserve0 = (_reserve0 * 1e18) / _decimals0;
            _reserve1 = (_reserve1 * 1e18) / _decimals1;
            (uint256 reserveA, uint256 reserveB) = tokenIn == _token0
                ? (_reserve0, _reserve1)
                : (_reserve1, _reserve0);
            amountIn = tokenIn == _token0
                ? (amountIn * 1e18) / _decimals0
                : (amountIn * 1e18) / _decimals1;
            uint256 y = reserveB -
                _get_y(
                    amountIn + reserveA,
                    xy,
                    reserveB,
                    _stable,
                    _decimals0,
                    _decimals1
                );
            return (y * (tokenIn == _token0 ? _decimals1 : _decimals0)) / 1e18;
        } else {
            (uint256 reserveA, uint256 reserveB) = tokenIn == _token0
                ? (_reserve0, _reserve1)
                : (_reserve1, _reserve0);
            return (amountIn * reserveB) / (reserveA + amountIn);
        }
    }
}
