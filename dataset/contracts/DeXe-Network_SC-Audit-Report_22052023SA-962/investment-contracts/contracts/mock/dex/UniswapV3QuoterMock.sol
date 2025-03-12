// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract UniswapV3QuoterMock {
    struct PoolInfo {
        uint256 reserve0;
        uint256 reserve1;
    }

    struct QuoteExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    struct QuoteExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 amount;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    mapping(address => mapping(address => mapping(uint24 => PoolInfo))) internal _poolInfos;

    function setPoolInfo(
        address token0,
        address token1,
        uint24 fee,
        PoolInfo calldata poolInfo
    ) external {
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
        _poolInfos[token0][token1][fee] = poolInfo;
    }

    function quoteExactInputSingle(
        QuoteExactInputSingleParams memory params
    )
        external
        returns (
            uint256 amountOut,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256 gasEstimate
        )
    {
        if (params.amountIn == 0) {
            return (0, 0, 0, 0);
        }

        (uint256 reserveIn, uint256 reserveOut) = _getReserves(
            params.tokenIn,
            params.tokenOut,
            params.fee
        );

        if (reserveIn == 0) {
            revert();
        }

        amountOut = (params.amountIn * reserveOut) / reserveIn;

        if (amountOut > reserveOut) {
            amountOut = reserveOut;
        }
    }

    function quoteExactOutputSingle(
        QuoteExactOutputSingleParams memory params
    )
        external
        returns (
            uint256 amountIn,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256 gasEstimate
        )
    {
        if (params.amount == 0) {
            return (0, 0, 0, 0);
        }

        (uint256 reserveIn, uint256 reserveOut) = _getReserves(
            params.tokenIn,
            params.tokenOut,
            params.fee
        );

        if (reserveOut == 0 || params.amount > reserveOut) {
            revert();
        }

        amountIn = (params.amount * reserveIn) / reserveOut;
    }

    function _getReserves(
        address tokenIn,
        address tokenOut,
        uint24 fee
    ) internal view returns (uint256 reserveIn, uint256 reserveOut) {
        bool zeroToOne = tokenIn < tokenOut;

        PoolInfo storage poolInfo = zeroToOne
            ? _poolInfos[tokenIn][tokenOut][fee]
            : _poolInfos[tokenOut][tokenIn][fee];

        (reserveIn, reserveOut) = zeroToOne
            ? (poolInfo.reserve0, poolInfo.reserve1)
            : (poolInfo.reserve1, poolInfo.reserve0);
    }
}
