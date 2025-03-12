// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import "./interfaces/IAdminProjectRouter.sol";

abstract contract Authorization {
    IAdminProjectRouter public adminRouter;
    string public constant PROJECT = "yuemmai";

    modifier onlySuperAdmin() {
        require(
            adminRouter.isSuperAdmin(msg.sender, PROJECT),
            "Restricted only super admin"
        );
        _;
    }

    modifier onlyAdmin() {
        require(
            adminRouter.isAdmin(msg.sender, PROJECT),
            "Restricted only admin"
        );
        _;
    }

    modifier onlySuperAdminOrAdmin() {
        require(
            adminRouter.isSuperAdmin(msg.sender, PROJECT) ||
                adminRouter.isAdmin(msg.sender, PROJECT),
            "Restricted only super admin or admin"
        );
        _;
    }

    constructor(address adminRouter_) {
        adminRouter = IAdminProjectRouter(adminRouter_);
    }

    function setAdmin(address _adminRouter) external onlySuperAdmin {
        adminRouter = IAdminProjectRouter(_adminRouter);
    }
}
