// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "./OwnedUpgradeable.sol";

contract EmergencyOperator is OwnedUpgradeable {
    mapping(address => bool) private operators;

    event EmergencyOperatorAdded(address indexed operator);
    event EmergencyOperatorRemoved(address indexed operator);

    function initialize() public initializer {
        __Owned_init();
    }

    modifier onlyEmergencyOperator() {
        require(isEmergencyOperator(msg.sender), "caller is not emergency operator");
        _;
    }

    function addEmergencyOperator(address _newOperator) external onlyOwner {
        require(!operators[_newOperator], "already an operator");
        operators[_newOperator] = true;
        emit EmergencyOperatorAdded(_newOperator);
    }

    function removeEmergencyOperator(address _newOperator) external onlyOwner {
        require(operators[_newOperator], "not an operator");
        operators[_newOperator] = false;
        emit EmergencyOperatorRemoved(_newOperator);
    }

    function isEmergencyOperator(address _operator) public view returns (bool) {
        return operators[_operator];
    }
}
