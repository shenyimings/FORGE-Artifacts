// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {IOperatorFilterRegistry} from "./../../../../token/royalty/interfaces/IOperatorFilterRegistry.sol";
import {ITokenMetadataResolver} from "./../../../../token/metadata/interfaces/ITokenMetadataResolver.sol";
import {ERC721FullMintOnceBurn} from "./../../../../token/ERC721/preset/ERC721FullMintOnceBurn.sol";

/// @title ERC721FullBurnMock
contract ERC721FullMintOnceBurnMock is ERC721FullMintOnceBurn {
    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        ITokenMetadataResolver metadataResolver,
        IOperatorFilterRegistry filterRegistry,
        IForwarderRegistry forwarderRegistry
    ) ERC721FullMintOnceBurn(tokenName, tokenSymbol, metadataResolver, filterRegistry, forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
