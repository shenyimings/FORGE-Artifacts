// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

interface IUniswapPairOracle {
    function update() external;

    function consult(address token, uint256 amountIn)
        external
        view
        returns (uint256 amountOut);

    function canUpdate() external view returns (bool);
}