// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/**
 * @title Interface for Compound's CToken.
 */
interface ICToken {

    function mint(uint _amount) external returns (uint256);

    function redeem(uint256 _amount) external returns (uint256);

    function underlying() external view returns (address);

    function exchangeRateCurrent() external returns (uint256);

    function exchangeRateStored() external view returns (uint256);
}