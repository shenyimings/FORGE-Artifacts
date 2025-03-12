// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface ILiquidityGauge {
    function deposit(uint256) external;

    function balanceOf(address) external view returns (uint256);

    function withdraw(uint256) external;

    function minter() external view returns(address);

    function lp_token() external view returns(address);

    function crv_token() external view returns(address);
}
