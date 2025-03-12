// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ITokenMetadataResolver} from "./../../../metadata/interfaces/ITokenMetadataResolver.sol";
import {IOperatorFilterRegistry} from "./../../../royalty/interfaces/IOperatorFilterRegistry.sol";
import {ERC1155Storage} from "./../../libraries/ERC1155Storage.sol";
import {ERC2981Storage} from "./../../../royalty/libraries/ERC2981Storage.sol";
import {TokenMetadataStorage} from "./../../../metadata/libraries/TokenMetadataStorage.sol";
import {OperatorFiltererStorage} from "./../../../royalty/libraries/OperatorFiltererStorage.sol";
import {ContractOwnershipStorage} from "./../../../../access/libraries/ContractOwnershipStorage.sol";
import {ERC1155WithOperatorFiltererBase} from "./../../base/ERC1155WithOperatorFiltererBase.sol";
import {ERC1155MetadataBase} from "./../../base/ERC1155MetadataBase.sol";
import {ERC1155MintableBase} from "./../../base/ERC1155MintableBase.sol";
import {ERC1155DeliverableBase} from "./../../base/ERC1155DeliverableBase.sol";
import {ERC2981Base} from "./../../../royalty/base/ERC2981Base.sol";
import {OperatorFiltererBase} from "./../../../royalty/base/OperatorFiltererBase.sol";
import {ContractOwnershipBase} from "./../../../../access/base/ContractOwnershipBase.sol";
import {AccessControlBase} from "./../../../../access/base/AccessControlBase.sol";
import {TokenRecoveryBase} from "./../../../../security/base/TokenRecoveryBase.sol";
import {InterfaceDetection} from "./../../../../introspection/InterfaceDetection.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ForwarderRegistryContextBase} from "./../../../../metatx/base/ForwarderRegistryContextBase.sol";
import {ForwarderRegistryContext} from "./../../../../metatx/ForwarderRegistryContext.sol";

contract ERC1155FullProxied is
    ERC1155WithOperatorFiltererBase,
    ERC1155MetadataBase,
    ERC1155MintableBase,
    ERC1155DeliverableBase,
    ERC2981Base,
    OperatorFiltererBase,
    ContractOwnershipBase,
    AccessControlBase,
    TokenRecoveryBase,
    InterfaceDetection,
    ForwarderRegistryContext
{
    using TokenMetadataStorage for TokenMetadataStorage.Layout;
    using OperatorFiltererStorage for OperatorFiltererStorage.Layout;
    using ContractOwnershipStorage for ContractOwnershipStorage.Layout;

    constructor(IForwarderRegistry forwarderRegistry) ForwarderRegistryContext(forwarderRegistry) {}

    function init(
        string calldata tokenName,
        string calldata tokenSymbol,
        ITokenMetadataResolver metadataResolver,
        IOperatorFilterRegistry filterRegistry
    ) external {
        ContractOwnershipStorage.layout().proxyInit(_msgSender());
        ERC1155Storage.init();
        ERC1155Storage.initERC1155MetadataURI();
        ERC1155Storage.initERC1155Mintable();
        ERC1155Storage.initERC1155Deliverable();
        ERC2981Storage.init();
        TokenMetadataStorage.layout().proxyInit(tokenName, tokenSymbol, metadataResolver);
        OperatorFiltererStorage.layout().proxyInit(filterRegistry);
    }

    /// @inheritdoc ForwarderRegistryContextBase
    function _msgSender() internal view virtual override(Context, ForwarderRegistryContextBase) returns (address) {
        return ForwarderRegistryContextBase._msgSender();
    }

    /// @inheritdoc ForwarderRegistryContextBase
    function _msgData() internal view virtual override(Context, ForwarderRegistryContextBase) returns (bytes calldata) {
        return ForwarderRegistryContextBase._msgData();
    }
}
