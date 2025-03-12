// SPDX-License-Identifier: MIT

/*------------------------------------------------------------------------------------------
████████████████████████████████████████████████████████████████████████████████████████████
█─▄─▄─█▄─▄▄▀█─▄▄─█▄─▄▄─█▄─▄█─▄▄▄─██▀▄─██▄─▄█████▄─▄▄─█▄─▄█▄─▀█▄─▄██▀▄─██▄─▀█▄─▄█─▄▄▄─█▄─▄▄─█
███─████─▄─▄█─██─██─▄▄▄██─██─███▀██─▀─███─██▀████─▄████─███─█▄▀─███─▀─███─█▄▀─██─███▀██─▄█▀█
▀▀▄▄▄▀▀▄▄▀▄▄▀▄▄▄▄▀▄▄▄▀▀▀▄▄▄▀▄▄▄▄▄▀▄▄▀▄▄▀▄▄▄▄▄▀▀▀▄▄▄▀▀▀▄▄▄▀▄▄▄▀▀▄▄▀▄▄▀▄▄▀▄▄▄▀▀▄▄▀▄▄▄▄▄▀▄▄▄▄▄▀
-------------------------------------------------------------------------------------------*/

pragma solidity >=0.6.12;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/** Operator Contract/Interface of Tropical Finance. **/

abstract contract Operable is Context, Ownable {
    mapping(address => bool) operators;    
    
    event OperatorUpdated(address indexed operator, bool indexed status);
    
    constructor() public {
        operators[msg.sender] = true;
    }

    /**
     * @dev Update the status of an operator
     */
    function updateOperator(address _operator, bool _status) public onlyOperator {
        operators[_operator] = _status;
        emit OperatorUpdated(_operator, _status);
    }

    modifier onlyOperator {
        require(operators[msg.sender] == true, "ERROR: Caller is not an operator");
        _;
    }
}