// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <1.0.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract OperatorAccess is Ownable {
    mapping(address => bool) public operators;

    event SetOperator(address account, bool status);

    function setOperator(address _account, bool _status) external onlyOwner {
        operators[_account] = _status;
        emit SetOperator(_account, _status);
    }

    modifier onlyOperator() {
        require(operators[msg.sender], "only operator");
        _;
    }
}
