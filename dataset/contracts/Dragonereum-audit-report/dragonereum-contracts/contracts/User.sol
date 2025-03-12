pragma solidity 0.4.25;

import "./Common/Name.sol";
import "./Common/Upgradable.sol";


contract User is Upgradable, Name {
    mapping (bytes32 => bool) public existingNames;
    mapping (address => bytes32) public names;

    function getName(address _user) external view returns (bytes32) {
        return names[_user];
    }

    function setName(
        address _user,
        string _name
    ) external onlyController returns (bytes32) {
        (
            bytes32 _initial, // initial name that converted to bytes32
            bytes32 _lowercase // name to lowercase
        ) = _convertName(_name);
        require(!existingNames[_lowercase], "this username already exists");
        require(names[_user] == 0x0, "username is already set");
        names[_user] = _initial;
        existingNames[_lowercase] = true;

        return _initial;
    }
}
