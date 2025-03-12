// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/**
 * @dev Interface for VToken
 */
interface IVToken {

    function mint(uint mintAmount) external returns (uint256);

    function redeem(uint redeemTokens) external returns (uint256);

    function redeemUnderlying(uint redeemAmount) external returns (uint256);
}