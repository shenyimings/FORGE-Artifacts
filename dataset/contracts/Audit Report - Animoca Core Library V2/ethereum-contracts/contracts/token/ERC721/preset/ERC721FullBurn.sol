// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../metatx/interfaces/IForwarderRegistry.sol";
import {ITokenMetadataResolver} from "./../../metadata/interfaces/ITokenMetadataResolver.sol";
import {IOperatorFilterRegistry} from "./../../royalty/interfaces/IOperatorFilterRegistry.sol";
import {ERC721WithOperatorFilterer} from "./../ERC721WithOperatorFilterer.sol";
import {ERC721BatchTransferWithOperatorFilterer} from "./../ERC721BatchTransferWithOperatorFilterer.sol";
import {ERC721Metadata} from "./../ERC721Metadata.sol";
import {ERC721Mintable} from "./../ERC721Mintable.sol";
import {ERC721Deliverable} from "./../ERC721Deliverable.sol";
import {ERC721Burnable} from "./../ERC721Burnable.sol";
import {ERC2981} from "./../../royalty/ERC2981.sol";
import {ContractOwnership} from "./../../../access/ContractOwnership.sol";
import {TokenRecovery} from "./../../../security/TokenRecovery.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ForwarderRegistryContextBase} from "./../../../metatx/base/ForwarderRegistryContextBase.sol";
import {ForwarderRegistryContext} from "./../../../metatx/ForwarderRegistryContext.sol";

contract ERC721FullBurn is
    ERC721WithOperatorFilterer,
    ERC721BatchTransferWithOperatorFilterer,
    ERC721Metadata,
    ERC721Mintable,
    ERC721Deliverable,
    ERC721Burnable,
    ERC2981,
    TokenRecovery,
    ForwarderRegistryContext
{
    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        ITokenMetadataResolver metadataResolver,
        IOperatorFilterRegistry filterRegistry,
        IForwarderRegistry forwarderRegistry
    )
        ContractOwnership(msg.sender)
        ERC721Metadata(tokenName, tokenSymbol, metadataResolver)
        ERC721WithOperatorFilterer(filterRegistry)
        ForwarderRegistryContext(forwarderRegistry)
    {}

    /// @inheritdoc ForwarderRegistryContextBase
    function _msgSender() internal view virtual override(Context, ForwarderRegistryContextBase) returns (address) {
        return ForwarderRegistryContextBase._msgSender();
    }

    /// @inheritdoc ForwarderRegistryContextBase
    function _msgData() internal view virtual override(Context, ForwarderRegistryContextBase) returns (bytes calldata) {
        return ForwarderRegistryContextBase._msgData();
    }
}
