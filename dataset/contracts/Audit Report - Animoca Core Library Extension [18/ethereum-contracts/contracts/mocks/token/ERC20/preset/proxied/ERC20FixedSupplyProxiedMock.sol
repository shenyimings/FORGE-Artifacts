// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC20FixedSupplyProxied} from "./../../../../../token/ERC20/preset/proxied/ERC20FixedSupplyProxied.sol";

contract ERC20FixedSupplyProxiedMock is ERC20FixedSupplyProxied {
    constructor(IForwarderRegistry forwarderRegistry) ERC20FixedSupplyProxied(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
