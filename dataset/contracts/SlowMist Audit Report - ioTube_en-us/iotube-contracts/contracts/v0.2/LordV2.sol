// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./OwnedUpgradeable.sol";

interface IERC20Mintable {
    function mint(address recipient, uint256 amount) external;
}

contract LordV2 is Initializable, OwnedUpgradeable {
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);

    mapping(address => bool) private operators;

    function initialize() public initializer {
        __Owned_init();
    }

    function addOperator(address _operator) public onlyOwner {
        require(!operators[_operator], "already an operator");
        operators[_operator] = true;
        emit OperatorAdded(_operator);
    }

    function removeOperator(address _operator) public onlyOwner {
        require(operators[_operator], "not an operator");
        operators[_operator] = false;
        emit OperatorRemoved(_operator);
    }

    function isOperator(address _operator) public view returns (bool) {
        return operators[_operator];
    }

    function mint(
        IERC20Mintable _token,
        address _recipient,
        uint256 _amount
    ) public {
        require(isOperator(msg.sender), "invalid operator");
        _token.mint(_recipient, _amount);
    }
}
