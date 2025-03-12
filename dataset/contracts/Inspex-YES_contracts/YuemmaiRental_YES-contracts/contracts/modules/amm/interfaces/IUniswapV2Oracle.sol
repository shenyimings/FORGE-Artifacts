//SPDX-License-Identifier: MIT
pragma solidity >= 0.5.0;

interface IUniswapV2Oracle {

    struct Observation {
        uint timestamp;
        uint price0Cumulative;
        uint price1Cumulative;
    }

    function factory() external view returns (address);
    function windowSize() external view returns (uint);
    function granularity() external view returns (uint8);
    function periodSize() external view returns (uint);
    function pairObservations(address addr, uint index) external view returns (Observation calldata);
    function observationIndexOf(uint timestamp) external view returns (uint8);
    function consult(address tokenIn, uint amountIn, address tokenOut) external view returns (uint);

    function update(address tokenA, address tokenB) external;
}