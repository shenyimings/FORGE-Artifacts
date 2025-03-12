// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;


import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "./interfaces/IRoleAccess.sol";

contract RolesRegistry is IRoleAccess, AccessControlEnumerable {
    
    bytes32 private constant IDO_DEPLOYER_ROLE = keccak256("IDO_DEPLOYER_ROLE");
    bytes32 private constant IDO_CONFIGURATOR_ROLE = keccak256("IDO_CONFIGURATOR_ROLE");
    bytes32 private constant IDO_APPROVER_ROLE = keccak256("IDO_APPROVER_ROLE");
    
    constructor()  {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    //--------------------//
    // EXTERNAL FUNCTIONS //
    //--------------------//
    
    function setDeployer(address user, bool on) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Errors.NOT_ADMIN");
        _setRole(IDO_DEPLOYER_ROLE, user, on);
    }
    
    function setConfigurator(address user, bool on) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Errors.NOT_ADMIN");
        _setRole(IDO_CONFIGURATOR_ROLE, user, on);
    }
    
    function setApprover(address user, bool on) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Errors.NOT_ADMIN");
        _setRole(IDO_APPROVER_ROLE, user, on);
    }
    
    function setRole(string memory roleName, address user, bool on) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Errors.NOT_ADMIN");
         bytes32  role = keccak256(abi.encodePacked(roleName));
        _setRole(role, user, on);
    }
    
    
    //------------------------//
    // IMPLEMENTS IRoleAccess //
    //------------------------//
    
    function isAdmin(address user) view override external returns (bool) {
         return hasRole(DEFAULT_ADMIN_ROLE, user);
    }
    
    function isDeployer(address user) view override external returns (bool) {
        return hasRole(IDO_DEPLOYER_ROLE, user);
    }
    
    function isConfigurator(address user) view override external returns (bool) {
        return hasRole(IDO_CONFIGURATOR_ROLE, user);
    }
    
    function isApprover(address user) view override external returns (bool) {
        return hasRole(IDO_APPROVER_ROLE, user);
    }
    
    function isRole(string memory roleName, address user) view override external returns (bool) {
        return hasRole(keccak256(abi.encodePacked(roleName)), user);
    }

    //--------------------//
    // PRIVATE FUNCTIONS  //
    //--------------------//
    
    function _setRole(bytes32 role, address user, bool on) private {
        
        if (on != hasRole(role, user)) {
            if (on) {
                grantRole(role, user);
            } else {
                revokeRole(role, user);
            }
        }
    }
}