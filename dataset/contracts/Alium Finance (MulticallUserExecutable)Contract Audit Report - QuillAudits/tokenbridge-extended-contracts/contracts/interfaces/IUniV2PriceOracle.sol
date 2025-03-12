/// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// @title IUniV2PriceOracle - Uniswap V2 price oracle interface
interface IUniV2PriceOracle {
    function update() external;

    function PERIOD() external view returns (uint256);

    function blockTimestampLast() external view returns (uint32);

    function pair() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function consult(address token, uint256 amountIn)
        external
        view
        returns (uint256 amountOut);
}
