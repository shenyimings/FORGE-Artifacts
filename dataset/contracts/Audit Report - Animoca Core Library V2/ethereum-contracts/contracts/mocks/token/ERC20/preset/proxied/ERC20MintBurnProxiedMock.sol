// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC20MintBurnProxied} from "./../../../../../token/ERC20/preset/proxied/ERC20MintBurnProxied.sol";

contract ERC20MintBurnProxiedMock is ERC20MintBurnProxied {
    constructor(IForwarderRegistry forwarderRegistry) ERC20MintBurnProxied(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
