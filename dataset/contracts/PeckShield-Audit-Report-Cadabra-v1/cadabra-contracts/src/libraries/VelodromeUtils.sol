// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

import "../interfaces/velodrome/IPool.sol";
import "./StableUtils.sol";

library VelodromeUtils {

    error UnsupportedToken(address token);

    function amountOut(address _pool, address _tokenIn, uint256 _amountIn)
        public
        view
        returns (uint256 _amountOut)
    {
        (address token0, address token1) = IPool(_pool).tokens();
        uint8 decimals0 = IERC20Metadata(token0).decimals();
        uint8 decimals1 = IERC20Metadata(token1).decimals();

        (uint256 reserve0, uint256 reserve1) = reserves(_pool);

        bool stable = IPool(_pool).stable();

        if (_tokenIn == token0) {
            if (stable) {
                return StableUtils.amount1(_amountIn, reserve0, reserve1, 10**decimals0, 10**decimals1);
            } else {
                return (_amountIn * reserve1) / (reserve0 + _amountIn);
            }
        } else if (_tokenIn == token1) {
            if (stable) {
                return StableUtils.amount0(_amountIn, reserve0, reserve1, 10**decimals0, 10**decimals1);
            } else {
                return (_amountIn * reserve0) / (reserve1 + _amountIn);
            }
        } else {
            revert UnsupportedToken({ token: _tokenIn });
        }
    }

    function amount1(uint256 _amount0, uint256 _base0, uint256 _base1, uint256 _reserve0, uint256 _reserve1, bool _stable)
        public
        view
        returns (uint256 _amount1)
    {
        if (_stable) {
            return StableUtils.amount1(_amount0, _reserve0, _reserve1, _base0, _base1);
        } else {
            return (_amount0 * _reserve1) / (_reserve0 + _amount0);
        }
    }

    function amount0(uint256 _amount1, uint256 _base0, uint256 _base1, uint256 _reserve0, uint256 _reserve1, bool _stable)
        public
        view
        returns (uint256 _amount0)
    {
        if (_stable) {
            return StableUtils.amount0(_amount1, _reserve0, _reserve1, _base0, _base1);
        } else {
            return (_amount1 * _reserve0) / (_reserve1 + _amount1);
        }
    }

    /// @dev copied from https://github.com/ThenafiBNB/THENA-Contracts/blob/f5bc742e1ff16c8be308a271a6a4a0e8f9e06453/contracts/Pair.sol#L283-L291
    function reserves(address _pool) public view returns (uint256 _reserve0, uint256 _reserve1) {
        IPool pool = IPool(_pool);
        IPool.Observation memory _observation = pool.lastObservation();
        (uint256 reserve0Cumulative, uint256 reserve1Cumulative,) = pool.currentCumulativePrices();
        if (block.timestamp == _observation.timestamp) {
            _observation = pool.observations(pool.observationLength() - 2);
        }

        uint256 timeElapsed = block.timestamp - _observation.timestamp;
        _reserve0 = (reserve0Cumulative - _observation.reserve0Cumulative) / timeElapsed;
        _reserve1 = (reserve1Cumulative - _observation.reserve1Cumulative) / timeElapsed;
    }

}