// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ParamBook is Ownable {
    mapping(bytes32 => uint256) public params;
    mapping(bytes32 => mapping(bytes32 => uint256)) public params2;

    function setParams(bytes32 name, uint256 value) public onlyOwner {
        params[name] = value;
    }

    function setMultiParams(bytes32[] memory names, uint[] memory values) public onlyOwner {
        require(names.length == values.length, "ParamBook::setMultiParams:param length not match");
        for (uint i=0; i < names.length; i++ ) {
            params[names[i]] = values[i];
        }
    }

    function setParams2(
        bytes32 name1,
        bytes32 name2,
        uint256 value
    ) public onlyOwner {
        params2[name1][name2] = value;
    }

    function setMultiParams2(bytes32[] memory names1, bytes32[] memory names2, uint[] memory values) public onlyOwner {
        require(names1.length == names2.length, "ParamBook::setMultiParams2:param length not match");
        require(names1.length == values.length, "ParamBook::setMultiParams2:param length not match");
        for(uint i=0; i < names1.length; i++) {
            params2[names1[i]][names2[i]] = values[i];
        }
    }
}
