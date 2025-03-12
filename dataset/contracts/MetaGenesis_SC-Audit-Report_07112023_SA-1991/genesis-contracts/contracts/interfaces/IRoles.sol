// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IRoles {
    function OWNER_ROLE() external view returns (bytes32);

    function MANAGER_ROLE() external view returns (bytes32);

    function VALIDATOR_ROLE() external view returns (bytes32);

    function hasRole(
        bytes32 role,
        address account
    ) external view returns (bool);
}
