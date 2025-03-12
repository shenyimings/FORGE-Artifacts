// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LedgerV2 is Ownable {
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);

    mapping(address => bool) public operators;
    mapping(bytes32 => uint256) public records;

    function addOperator(address operator) public onlyOwner {
        require(!operators[operator], "already an operator");
        operators[operator] = true;
        emit OperatorAdded(operator);
    }

    function removeOperator(address operator) public onlyOwner {
        require(operators[operator], "not an operator");
        operators[operator] = false;
        emit OperatorRemoved(operator);
    }

    function record(bytes32 id) public {
        require(operators[msg.sender], "invalid operator");
        require(records[id] == 0, "duplicate record");
        records[id] = block.number;
    }

    function get(bytes32 id) public view returns (uint256) {
        return records[id];
    }
}
