// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface IHarvestVaultProxy {
    function implementation() external view returns (address);

    function upgrade() external;
}
