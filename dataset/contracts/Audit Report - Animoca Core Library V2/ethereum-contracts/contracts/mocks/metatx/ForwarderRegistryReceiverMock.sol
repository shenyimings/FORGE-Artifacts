// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "../../metatx/interfaces/IForwarderRegistry.sol";
import {ForwarderRegistryContext} from "../../metatx/ForwarderRegistryContext.sol";

contract ForwarderRegistryReceiverMock is ForwarderRegistryContext {
    mapping(address => uint256) internal _d;

    constructor(IForwarderRegistry forwarderRegistry) ForwarderRegistryContext(forwarderRegistry) {}

    // test function without arguments, so that msg.data.length < 24
    function smallDataTest() external {
        address sender = _msgSender();
        _msgData();
        ++_d[sender];
    }

    function test(uint256 d) external {
        address sender = _msgSender();
        _msgData();
        _d[sender] = d;
    }

    function getData(address who) external view returns (uint256) {
        return _d[who];
    }
}
