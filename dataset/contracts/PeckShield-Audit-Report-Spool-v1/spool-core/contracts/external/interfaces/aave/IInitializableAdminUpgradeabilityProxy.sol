// SPDX-License-Identifier: agpl-3.0

pragma solidity 0.8.11;

interface IInitializableAdminUpgradeabilityProxy {
    function admin() external returns (address);

    function changeAdmin(address newAdmin) external;

    function implementation() external returns (address);

    function initialize(
        address _logic,
        address _admin,
        bytes memory _data
    ) external;

    function initialize(address _logic, bytes memory _data) external;

    function upgradeTo(address newImplementation) external;

    function upgradeToAndCall(address newImplementation, bytes memory data) external;
}
