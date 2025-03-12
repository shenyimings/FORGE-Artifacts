// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IAddressResolver.sol";

/**
@notice Obtain different contract addresses based on different bytes32(name)
 */
contract AddressResolver is Ownable, IAddressResolver {
    mapping(bytes32 => address) public override key2address;
    mapping(address => bytes32) public override address2key;

    function setAddress(bytes32 key, address addr) public override onlyOwner {
        key2address[key] = addr;
        address2key[addr] = key;
    }

    function setMultiAddress(bytes32[] memory keys, address[] memory addrs) public override onlyOwner {
        require(keys.length == addrs.length, "AddressResolver::setMultiAddress:parameter number not match");
        for (uint i=0; i < keys.length; i++) {
            key2address[keys[i]] = addrs[i];
            address2key[addrs[i]] = keys[i];
        }
    }

    function requireAndKey2Address(bytes32 name, string calldata reason) external view override returns(address) {
        address addr = key2address[name];
        require(addr != address(0), reason);
        return addr;
    }
}
