// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC721FullMintOnceBurnProxied} from "./../../../../../token/ERC721/preset/proxied/ERC721FullMintOnceBurnProxied.sol";

contract ERC721FullMintOnceBurnProxiedMock is ERC721FullMintOnceBurnProxied {
    constructor(IForwarderRegistry forwarderRegistry) ERC721FullMintOnceBurnProxied(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
