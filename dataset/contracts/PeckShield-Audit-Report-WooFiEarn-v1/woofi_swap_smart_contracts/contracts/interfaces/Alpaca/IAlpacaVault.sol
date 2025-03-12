// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IAlpacaVault {
    function balanceOf(address account) external view returns (uint256);

    function totalToken() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function deposit(uint256 amountToken) external payable;

    function withdraw(uint256 share) external;
}
