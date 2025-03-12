// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IDCALimits {
    function minDepositAmount() external view returns (uint256);
}
