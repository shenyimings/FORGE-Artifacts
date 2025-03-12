// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IWhitelistController {
    struct RoleInfo {
        bool jGLP_BYPASS_CAP;
        bool jUSDC_BYPASS_TIME;
        uint256 jGLP_RETENTION;
        uint256 jUSDC_RETENTION;
    }

    function isInternalContract(address _account) external view returns (bool);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getUserRole(address _user) external view returns (bytes32);
    function getRoleInfo(bytes32 _role) external view returns (IWhitelistController.RoleInfo memory);
    function getDefaultRole() external view returns (IWhitelistController.RoleInfo memory);
    function isWhitelistedContract(address _account) external view returns (bool);
    function addToInternalContract(address _account) external;
    function addToWhitelistContracts(address _account) external;
    function removeFromInternalContract(address _account) external;
    function removeFromWhitelistContract(address _account) external;
    function bulkAddToWhitelistContracts(address[] calldata _accounts) external;
    function bulkRemoveFromWhitelistContract(address[] calldata _accounts) external;
}
