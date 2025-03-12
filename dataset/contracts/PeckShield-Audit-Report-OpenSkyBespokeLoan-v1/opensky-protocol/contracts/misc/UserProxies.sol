// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import './UserProxy.sol';

contract UserProxies {
    mapping(address => UserProxy) public userProxies;

    function _getUserProxy(address user) internal returns (address) {
        UserProxy userProxy = userProxies[user];
        if (address(userProxy) == address(0)) {
            userProxy = new UserProxy();
            userProxies[user] = userProxy;
        }
        return address(userProxy);
    }

    function _callUserProxy(
        address user,
        address target,
        bytes memory data
    ) internal {
        require(address(userProxies[msg.sender]) != address(0), "HAS_NO_PROXY");
        userProxies[user].execute(target, data, 0);
    }
}