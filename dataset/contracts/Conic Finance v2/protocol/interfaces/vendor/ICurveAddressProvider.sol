// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface ICurveAddressProvider {
    function get_registry() external view returns (address);
}
