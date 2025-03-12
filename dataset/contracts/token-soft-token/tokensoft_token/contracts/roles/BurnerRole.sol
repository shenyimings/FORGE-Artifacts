pragma solidity 0.6.12;

import "./OwnerRole.sol";

contract BurnerRole is OwnerRole {

    event BurnerAdded(address indexed addedBurner, address indexed addedBy);
    event BurnerRemoved(address indexed removedBurner, address indexed removedBy);

    Roles.Role private _burners;

    modifier onlyBurner() {
        require(isBurner(msg.sender), "BurnerRole: caller does not have the Burner role");
        _;
    }

    function isBurner(address account) public view returns (bool) {
        return _burners.has(account);
    }

    function _addBurner(address account) internal {
        _burners.add(account);
        emit BurnerAdded(account, msg.sender);
    }

    function _removeBurner(address account) internal {
        _burners.remove(account);
        emit BurnerRemoved(account, msg.sender);
    }

    function addBurner(address account) public onlyOwner {
        _addBurner(account);
    }

    function removeBurner(address account) public onlyOwner {
        _removeBurner(account);
    }

}