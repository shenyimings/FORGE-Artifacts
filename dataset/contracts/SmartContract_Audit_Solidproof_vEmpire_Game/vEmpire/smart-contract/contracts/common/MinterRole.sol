pragma solidity =0.6.12;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Roles.sol";

contract MinterRole is Context, Ownable {
    using Roles for Roles.Role;

    event MinterAdded(address[] account);
    event MinterRemoved(address indexed account);

    Roles.Role private _minters;

    constructor () internal {
        address[] memory admins = new address[](1);
        admins[0] = _msgSender();
        _addMinter(admins);
    }

    modifier onlyMinter() {
        require(isMinter(_msgSender()), "MinterRole: caller does not have the Minter role");
        _;
    }

    function isMinter(address account) public view returns (bool) {
        return _minters.has(account);
    }

    function addMinter(address[] memory account) public onlyMinter {
        _addMinter(account);
    }
    
    function removeMinter(address account) public onlyOwner {
        _removeMinter(account);
    }

    function renounceMinter() public {
        _removeMinter(_msgSender());
    }

    function _addMinter(address[] memory account) internal {
        _minters.add(account);
        emit MinterAdded(account);
    }

    function _removeMinter(address account) internal {
        _minters.remove(account);
        emit MinterRemoved(account);
    }
}