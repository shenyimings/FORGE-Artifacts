// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Operator is Context, Ownable {

    mapping(address => bool) private _operator;

    event OperatorTransferred(
        address indexed previousOperator,
        address indexed newOperator
    );

    constructor() {
    _operator[_msgSender()] = true;
    }

    function operator() public view returns (bool) {
        return _operator[_msgSender()];
    }

    modifier onlyOperator() {
        require(
            _operator[_msgSender()] == true,
            "operator: caller is not the operator"
        );
        _;
    }

    function isOperator() public view returns (bool) {
        return _operator[_msgSender()];
    }

    function setOperator(address newOperator) public onlyOwner {
        _operator[newOperator] = true;
    }

    function removeOperator(address oldOperator) public onlyOwner {
        _operator[oldOperator] = false;
    }

}
