// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.4;

contract Test_FlashStrategyAAVEv2 {
    mapping(address => uint256) amounts;

    function setTotalFTokenBurned(address _address, uint256 _amount) public returns (uint256) {
        // This is a stub method for testing purposes

        amounts[_address] = _amount;

        return _amount;
    }

    function getTotalFTokenBurned(address _address) public view returns (uint256) {
        // This is a stub method for testing purposes
        return amounts[_address];
    }
}
