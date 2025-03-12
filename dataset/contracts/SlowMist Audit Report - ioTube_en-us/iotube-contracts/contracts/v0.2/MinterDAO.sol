// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "./EmergencyOperator.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract MinterDAO is OwnableUpgradeable, PausableUpgradeable {
    event NewLord(address indexed lord);
    event MinterAdded(address indexed minter, address indexed token);
    event MinterRemoved(address indexed minter, address indexed token);

    EmergencyOperator public emergencyOperator;
    address public lord;
    mapping(address => mapping(address => bool)) private minters;

    function initialize(address _lord, address _emergencyOperator) public initializer {
        __Ownable_init();
        __Pausable_init();
        lord = _lord;
        emergencyOperator = EmergencyOperator(_emergencyOperator);
        emit NewLord(_lord);
    }

    function addMinter(address _minter, address _token) external onlyOwner {
        require(_minter != address(0), "invalid minter address");
        require(_token != address(0), "invalid token address");
        require(!minters[_minter][_token], "already a minter");
        minters[_minter][_token] = true;
        emit MinterAdded(_minter, _token);
    }

    function removeMinter(address _minter, address _token) external onlyOwner {
        require(minters[_minter][_token], "not a minter");
        minters[_minter][_token] = false;
        emit MinterRemoved(_minter, _token);
    }

    function isMinter(address _account, address _token) external view whenNotPaused returns (bool) {
        return _account == lord || minters[_account][_token];
    }

    function pause() external {
        require(emergencyOperator.isEmergencyOperator(msg.sender), "no permission");
        _pause();
    }

    function unpause() external {
        require(emergencyOperator.isEmergencyOperator(msg.sender), "no permission");
        _unpause();
    }
}
