pragma solidity 0.6.12;

import "./OwnerRole.sol";

contract MinterRole is OwnerRole {

    event MinterAdded(address indexed addedMinter, address indexed addedBy);
    event MinterRemoved(address indexed removedMinter, address indexed removedBy);

    Roles.Role private _minters;

    modifier onlyMinter() {
        require(isMinter(msg.sender), "MinterRole: caller does not have the Minter role");
        _;
    }

    function isMinter(address account) public view returns (bool) {
        return _minters.has(account);
    }

    function _addMinter(address account) internal {
        _minters.add(account);
        emit MinterAdded(account, msg.sender);
    }

    function _removeMinter(address account) internal {
        _minters.remove(account);
        emit MinterRemoved(account, msg.sender);
    }

    function addMinter(address account) public onlyOwner {
        _addMinter(account);
    }

    function removeMinter(address account) public onlyOwner {
        _removeMinter(account);
    }

}