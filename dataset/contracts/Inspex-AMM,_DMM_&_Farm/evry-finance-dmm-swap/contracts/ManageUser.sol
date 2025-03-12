// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;

interface IManageAddress {
    function getRole(address user) external view returns (bytes32);
}

contract ManageUser {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SUPER_ADMIN_ROLE = keccak256("SUPER_ADMIN_ROLE");
    bytes32 public constant NORMAL = keccak256("NORMAL");
    IManageAddress public manage;

    constructor(address manageAddress) public {
        manage = IManageAddress(manageAddress);
    }

    function getRoleUser(address user) public view returns (bytes32) {
        return manage.getRole(user);
    }

    modifier _superAdmin() {
        require(getRoleUser(msg.sender) == SUPER_ADMIN_ROLE, "NO PERMISSION");
        _;
    }

    modifier _admin() {
        require(
            getRoleUser(msg.sender) == ADMIN_ROLE || getRoleUser(msg.sender) == SUPER_ADMIN_ROLE,
            "NO PERMISSION"
        );
        _;
    }
}
