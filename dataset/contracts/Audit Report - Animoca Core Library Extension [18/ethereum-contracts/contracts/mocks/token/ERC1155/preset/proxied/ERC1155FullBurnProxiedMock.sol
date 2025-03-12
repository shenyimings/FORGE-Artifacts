// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC1155FullBurnProxied} from "./../../../../../token/ERC1155/preset/proxied/ERC1155FullBurnProxied.sol";

contract ERC1155FullBurnProxiedMock is ERC1155FullBurnProxied {
    constructor(IForwarderRegistry forwarderRegistry) ERC1155FullBurnProxied(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
