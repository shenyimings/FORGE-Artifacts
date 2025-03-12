// SPDX-License-Identifier: MIT

pragma solidity 0.6;
pragma experimental ABIEncoderV2;

interface ILendingPlatformBSC {
    function redeemAll(address platform, address token) external;

    function getLiquidity(address platform, address token) external returns (uint256);
}
