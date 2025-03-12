// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";


interface IZNSAccessController is IAccessControl {
    function setRoleAdmin(bytes32 role, bytes32 adminRole) external;

    function checkGovernor(address account) external view;

    function checkAdmin(address account) external view;

    function checkExecutor(address account) external view;

    function checkRegistrar(address account) external view;

    function isAdmin(address account) external view returns (bool);

    function isRegistrar(address account) external view returns (bool);

    function isGovernor(address account) external view returns (bool);

    function isExecutor(address account) external view returns (bool);
}
