// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC721Storage} from "./../../../../token/ERC721/libraries/ERC721Storage.sol";
import {ContractOwnershipStorage} from "./../../../../access/libraries/ContractOwnershipStorage.sol";
import {InterfaceDetectionStorage} from "./../../../../introspection/libraries/InterfaceDetectionStorage.sol";
import {ERC721Base} from "./../../../../token/ERC721/base/ERC721Base.sol";
import {ERC721BatchTransferBase} from "./../../../../token/ERC721/base/ERC721BatchTransferBase.sol";
import {ERC721MintableBase} from "./../../../../token/ERC721/base/ERC721MintableBase.sol";
import {ContractOwnershipBase} from "./../../../../access/base/ContractOwnershipBase.sol";
import {AccessControlBase} from "./../../../../access/base/AccessControlBase.sol";
import {InterfaceDetection} from "./../../../../introspection/InterfaceDetection.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ForwarderRegistryContextBase} from "./../../../../metatx/base/ForwarderRegistryContextBase.sol";
import {ForwarderRegistryContext} from "./../../../../metatx/ForwarderRegistryContext.sol";

contract ERC721WithoutOperatorFiltererProxiedMock is
    ERC721Base,
    ERC721BatchTransferBase,
    ERC721MintableBase,
    ContractOwnershipBase,
    AccessControlBase,
    InterfaceDetection,
    ForwarderRegistryContext
{
    using ContractOwnershipStorage for ContractOwnershipStorage.Layout;
    using InterfaceDetectionStorage for InterfaceDetectionStorage.Layout;

    constructor(IForwarderRegistry forwarderRegistry) ForwarderRegistryContext(forwarderRegistry) {}

    function init() external {
        ContractOwnershipStorage.layout().proxyInit(_msgSender());
        ERC721Storage.init();
        ERC721Storage.initERC721BatchTransfer();
        ERC721Storage.initERC721Mintable();
    }

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
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
