// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1.0;

import "@openzeppelin/contracts/proxy/Proxy.sol";


contract SimpleProxy is Proxy {

    bytes32 private constant _SLOT_ = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    struct ProxyStorage {
        address implementation;
        address upgrader;
    }

    constructor(address implementation_, address _upgrader, bytes memory data) {
        _getProxyStorage().upgrader = msg.sender;
        upgradeToAndCall(implementation_, data);
        appointNewUpgrader(_upgrader);
    }

    function _implementation() internal view override returns(address) {
        return _getProxyStorage().implementation;
    }

    function _getProxyStorage() internal pure returns(ProxyStorage storage s) {
        bytes32 _slot = _SLOT_;
        assembly {
            s.slot := _slot
        }
    }

    function upgradeToAndCall(address newImplementation, bytes memory data) public {
        ProxyStorage storage s = _getProxyStorage();

        require(msg.sender == s.upgrader, "not the upgrader");
        require(newImplementation != s.implementation, "is already the implementation");
        require(_isContract(newImplementation), "not a contract");

        s.implementation = newImplementation;
        if(data.length != 0) {
            (bool success, ) = newImplementation.delegatecall(data);
            require(success, "low level call failed");
        }
    }

    function appointNewUpgrader(address newUpgrader) public {
        ProxyStorage storage s = _getProxyStorage();

        require(msg.sender == s.upgrader, "msg.sender == upgrader");
        s.upgrader = newUpgrader;
    }

    function _isContract(address newImplementation) internal view returns(bool) {
        uint256 size;
        assembly {
            size := extcodesize(newImplementation)
        }
        return size > 0;
    }
}