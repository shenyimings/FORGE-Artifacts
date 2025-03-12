// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC1155Storage} from "./../../../../token/ERC1155/libraries/ERC1155Storage.sol";
import {ContractOwnershipStorage} from "./../../../../access/libraries/ContractOwnershipStorage.sol";
import {InterfaceDetectionStorage} from "./../../../../introspection/libraries/InterfaceDetectionStorage.sol";
import {ERC1155Base} from "./../../../../token/ERC1155/base/ERC1155Base.sol";
import {ERC1155MintableBase} from "./../../../../token/ERC1155/base/ERC1155MintableBase.sol";
import {ContractOwnershipBase} from "./../../../../access/base/ContractOwnershipBase.sol";
import {AccessControlBase} from "./../../../../access/base/AccessControlBase.sol";
import {InterfaceDetection} from "./../../../../introspection/InterfaceDetection.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ForwarderRegistryContextBase} from "./../../../../metatx/base/ForwarderRegistryContextBase.sol";
import {ForwarderRegistryContext} from "./../../../../metatx/ForwarderRegistryContext.sol";

contract ERC1155WithoutOperatorFiltererProxiedMock is
    ERC1155Base,
    ERC1155MintableBase,
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
        ERC1155Storage.init();
        ERC1155Storage.initERC1155Mintable();
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
