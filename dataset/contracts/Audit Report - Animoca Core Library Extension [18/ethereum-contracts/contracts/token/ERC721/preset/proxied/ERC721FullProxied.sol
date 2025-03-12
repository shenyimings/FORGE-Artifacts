// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ITokenMetadataResolver} from "./../../../metadata/interfaces/ITokenMetadataResolver.sol";
import {IOperatorFilterRegistry} from "./../../../royalty/interfaces/IOperatorFilterRegistry.sol";
import {ERC721Storage} from "./../../libraries/ERC721Storage.sol";
import {ERC2981Storage} from "./../../../royalty/libraries/ERC2981Storage.sol";
import {TokenMetadataStorage} from "./../../../metadata/libraries/TokenMetadataStorage.sol";
import {OperatorFiltererStorage} from "./../../../royalty/libraries/OperatorFiltererStorage.sol";
import {ContractOwnershipStorage} from "./../../../../access/libraries/ContractOwnershipStorage.sol";
import {ERC721WithOperatorFiltererBase} from "./../../base/ERC721WithOperatorFiltererBase.sol";
import {ERC721BatchTransferWithOperatorFiltererBase} from "./../../base/ERC721BatchTransferWithOperatorFiltererBase.sol";
import {ERC721MetadataBase} from "./../../base/ERC721MetadataBase.sol";
import {ERC721MintableBase} from "./../../base/ERC721MintableBase.sol";
import {ERC721DeliverableBase} from "./../../base/ERC721DeliverableBase.sol";
import {ERC2981Base} from "./../../../royalty/base/ERC2981Base.sol";
import {OperatorFiltererBase} from "./../../../royalty/base/OperatorFiltererBase.sol";
import {ContractOwnershipBase} from "./../../../../access/base/ContractOwnershipBase.sol";
import {AccessControlBase} from "./../../../../access/base/AccessControlBase.sol";
import {TokenRecoveryBase} from "./../../../../security/base/TokenRecoveryBase.sol";
import {InterfaceDetection} from "./../../../../introspection/InterfaceDetection.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ForwarderRegistryContextBase} from "./../../../../metatx/base/ForwarderRegistryContextBase.sol";
import {ForwarderRegistryContext} from "./../../../../metatx/ForwarderRegistryContext.sol";

contract ERC721FullProxied is
    ERC721WithOperatorFiltererBase,
    ERC721BatchTransferWithOperatorFiltererBase,
    ERC721MetadataBase,
    ERC721MintableBase,
    ERC721DeliverableBase,
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
        ERC721Storage.init();
        ERC721Storage.initERC721BatchTransfer();
        ERC721Storage.initERC721Metadata();
        ERC721Storage.initERC721Mintable();
        ERC721Storage.initERC721Deliverable();
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
