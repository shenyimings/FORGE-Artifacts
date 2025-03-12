// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface IFiatTokenProxy {
    function upgradeTo(address newImplementation) external;

    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;

    function implementation() external view returns (address);

    function changeAdmin(address newAdmin) external;

    function admin() external view returns (address);
}
