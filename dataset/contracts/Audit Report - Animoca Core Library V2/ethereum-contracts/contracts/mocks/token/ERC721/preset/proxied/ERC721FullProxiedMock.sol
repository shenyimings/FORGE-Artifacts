// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC721FullProxied} from "./../../../../../token/ERC721/preset/proxied/ERC721FullProxied.sol";

contract ERC721FullProxiedMock is ERC721FullProxied {
    constructor(IForwarderRegistry forwarderRegistry) ERC721FullProxied(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
