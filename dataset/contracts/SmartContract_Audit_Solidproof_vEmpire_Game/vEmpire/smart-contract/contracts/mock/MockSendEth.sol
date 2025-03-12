//SPDX-License-Identifier: Unlicensed

pragma solidity =0.6.12;

contract MockSendEth {

    constructor() public { 
    }

    function sendETH(address payable _user) public payable {
        _user.transfer(msg.value);
    }
}