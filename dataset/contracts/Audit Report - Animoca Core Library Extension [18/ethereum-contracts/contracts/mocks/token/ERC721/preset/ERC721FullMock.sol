// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {IOperatorFilterRegistry} from "./../../../../token/royalty/interfaces/IOperatorFilterRegistry.sol";
import {ITokenMetadataResolver} from "./../../../../token/metadata/interfaces/ITokenMetadataResolver.sol";
import {ERC721Full} from "./../../../../token/ERC721/preset/ERC721Full.sol";

/// @title ERC721FullMock
contract ERC721FullMock is ERC721Full {
    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        ITokenMetadataResolver metadataResolver,
        IOperatorFilterRegistry filterRegistry,
        IForwarderRegistry forwarderRegistry
    ) ERC721Full(tokenName, tokenSymbol, metadataResolver, filterRegistry, forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
