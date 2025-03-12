// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC1155FullProxied} from "./../../../../../token/ERC1155/preset/proxied/ERC1155FullProxied.sol";

contract ERC1155FullProxiedMock is ERC1155FullProxied {
    constructor(IForwarderRegistry forwarderRegistry) ERC1155FullProxied(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
