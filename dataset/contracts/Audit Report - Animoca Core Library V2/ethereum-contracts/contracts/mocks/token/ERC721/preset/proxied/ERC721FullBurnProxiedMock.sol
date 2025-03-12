// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC721FullBurnProxied} from "./../../../../../token/ERC721/preset/proxied/ERC721FullBurnProxied.sol";

contract ERC721FullBurnProxiedMock is ERC721FullBurnProxied {
    constructor(IForwarderRegistry forwarderRegistry) ERC721FullBurnProxied(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
