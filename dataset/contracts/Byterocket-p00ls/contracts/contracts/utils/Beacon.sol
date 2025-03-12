// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/// @custom:security-contact security@p00ls.com
contract Beacon is IBeacon, Ownable {
    address private _implementation;

    event Upgraded(address indexed implementation);

    function implementation()
        public
        view
        override
        returns (address)
    {
        return _implementation;
    }

    function upgradeTo(address newImplementation)
        public
        onlyOwner
    {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    function _setImplementation(address newImplementation)
        private
    {
        require(Address.isContract(newImplementation), "UpgradeableBeacon: implementation is not a contract");
        _implementation = newImplementation;
    }
}