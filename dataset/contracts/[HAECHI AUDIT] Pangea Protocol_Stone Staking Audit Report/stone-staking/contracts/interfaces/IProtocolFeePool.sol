// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0;

interface IProtocolFeePool {
    function collectProtocolFee() external returns (uint128, uint128);

    function getTokenProtocolFees() external view returns (uint128, uint128);
}
