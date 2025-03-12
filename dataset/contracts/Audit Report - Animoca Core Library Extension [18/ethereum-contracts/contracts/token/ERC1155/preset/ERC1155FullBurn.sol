// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../../metatx/interfaces/IForwarderRegistry.sol";
import {ITokenMetadataResolver} from "./../../metadata/interfaces/ITokenMetadataResolver.sol";
import {IOperatorFilterRegistry} from "./../../royalty/interfaces/IOperatorFilterRegistry.sol";
import {ERC1155WithOperatorFilterer} from "./../ERC1155WithOperatorFilterer.sol";
import {ERC1155Metadata} from "./../ERC1155Metadata.sol";
import {ERC1155Mintable} from "./../ERC1155Mintable.sol";
import {ERC1155Deliverable} from "./../ERC1155Deliverable.sol";
import {ERC1155Burnable} from "./../ERC1155Burnable.sol";
import {ERC2981} from "./../../royalty/ERC2981.sol";
import {ContractOwnership} from "./../../../access/ContractOwnership.sol";
import {TokenRecovery} from "./../../../security/TokenRecovery.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ForwarderRegistryContextBase} from "./../../../metatx/base/ForwarderRegistryContextBase.sol";
import {ForwarderRegistryContext} from "./../../../metatx/ForwarderRegistryContext.sol";

contract ERC1155FullBurn is
    ERC1155WithOperatorFilterer,
    ERC1155Metadata,
    ERC1155Mintable,
    ERC1155Deliverable,
    ERC1155Burnable,
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
        ERC1155Metadata(tokenName, tokenSymbol, metadataResolver)
        ERC1155WithOperatorFilterer(filterRegistry)
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
