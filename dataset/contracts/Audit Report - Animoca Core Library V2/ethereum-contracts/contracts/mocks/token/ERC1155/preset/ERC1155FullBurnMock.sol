// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {IOperatorFilterRegistry} from "./../../../../token/royalty/interfaces/IOperatorFilterRegistry.sol";
import {ITokenMetadataResolver} from "./../../../../token/metadata/interfaces/ITokenMetadataResolver.sol";
import {ERC1155FullBurn} from "./../../../../token/ERC1155/preset/ERC1155FullBurn.sol";

/// @title ERC1155FullBurnMock
contract ERC1155FullBurnMock is ERC1155FullBurn {
    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        ITokenMetadataResolver metadataResolver,
        IOperatorFilterRegistry filterRegistry,
        IForwarderRegistry forwarderRegistry
    ) ERC1155FullBurn(tokenName, tokenSymbol, metadataResolver, filterRegistry, forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
