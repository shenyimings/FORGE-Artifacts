// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Listing is Ownable {
    mapping(address => bool) public blacklistedMap;

    event Blacklisted(address indexed account, bool isBlacklisted);

     modifier checkBlacklist(address account,address recipient) {
        if (blacklisted(account)) revert("Crowdsale: BLACKLISTED");
        if (blacklisted(recipient)) revert("Crowdsale: BLACKLISTED");
        _;
    }

    function blacklisted(address _address) public view returns (bool) {
        return blacklistedMap[_address];
    }

    function addBlacklist(address _address) public onlyOwner {
        require(blacklistedMap[_address] != true);
        blacklistedMap[_address] = true;
        emit Blacklisted(_address, true);
    }

    function removeBlacklist(address _address) public onlyOwner {
        require(blacklistedMap[_address] != false);
        blacklistedMap[_address] = false;
        emit Blacklisted(_address, false);
    }
}
