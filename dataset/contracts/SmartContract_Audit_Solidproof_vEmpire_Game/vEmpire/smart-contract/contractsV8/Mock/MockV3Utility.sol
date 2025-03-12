// SPDX-License-Identifier: MIT
pragma solidity =0.8.9;

contract MockV3Utility {
    uint amount = 10 * 10**18;
    constructor() {
    }

    function getVEMPAmount(uint256 tokenID) public view returns (uint256) {
        return amount;
    }

    function setAmount(uint _amount) public {
        amount =  _amount;
    }
}
