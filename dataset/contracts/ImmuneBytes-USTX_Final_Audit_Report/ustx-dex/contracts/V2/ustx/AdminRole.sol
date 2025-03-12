// AdminRole.sol
// Based on OpenZeppelin contracts v2.5.1
// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import "./Context.sol";
import "./Roles.sol";

contract AdminRole is Context {
    using Roles for Roles.Role;

    event AdminAdded(address indexed account);
    event AdminRemoved(address indexed account);

    Roles.Role private _administrators;
    uint256 private _numAdmins;
    uint256 private _minAdmins;

    constructor (uint256 minAdmins) internal {
        _numAdmins=0;
        _addAdmin(_msgSender());
        _minAdmins = minAdmins;
    }

    modifier onlyAdmin() {
        require(isAdmin(_msgSender()), "AdminRole: caller does not have the Admin role");
        _;
    }

    function isAdmin(address account) public view returns (bool) {
        return _administrators.has(account);
    }

    function addAdmin(address account) public onlyAdmin {
        _addAdmin(account);
    }

//    function removeAdmin(address account) public onlyAdmin {
//        require(_numAdmins>_minAdmins, "There must always be a minimum number of admins in charge");
//        _removeAdmin(account);
//    }

    function renounceAdmin() public {
        require(_numAdmins>_minAdmins, "There must always be a minimum number of admins in charge");
        _removeAdmin(_msgSender());
    }

    function _addAdmin(address account) internal {
        _administrators.add(account);
        _numAdmins++;
        emit AdminAdded(account);
    }

    function _removeAdmin(address account) internal {
        _administrators.remove(account);
        _numAdmins--;
        emit AdminRemoved(account);
    }
}
