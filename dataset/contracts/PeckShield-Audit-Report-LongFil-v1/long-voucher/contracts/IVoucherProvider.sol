// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IVoucherProvider {
    function isRedeemable(uint256 voucherId) external view returns (bool);

    function getRedeemableAmount(uint256 voucherId) external view returns (uint256);
}
