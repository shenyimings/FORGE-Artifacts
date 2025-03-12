// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC20} from "./../ERC20.sol";
import {ERC20Detailed} from "./../ERC20Detailed.sol";
import {ERC20Metadata} from "./../ERC20Metadata.sol";
import {ERC20Permit} from "./../ERC20Permit.sol";
import {ERC20SafeTransfers} from "./../ERC20SafeTransfers.sol";
import {ERC20BatchTransfers} from "./../ERC20BatchTransfers.sol";
import {ERC20Mintable} from "./../ERC20Mintable.sol";
import {ERC20Burnable} from "./../ERC20Burnable.sol";
import {TokenRecovery} from "./../../../security/TokenRecovery.sol";
import {ContractOwnership} from "./../../../access/ContractOwnership.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ForwarderRegistryContextBase} from "./../../../metatx/base/ForwarderRegistryContextBase.sol";
import {ForwarderRegistryContext} from "./../../../metatx/ForwarderRegistryContext.sol";

/// @title ERC20 Fungible Token Standard, mintable and burnable preset contract (immutable version).
contract ERC20MintBurn is
    ERC20,
    ERC20Detailed,
    ERC20Metadata,
    ERC20Permit,
    ERC20SafeTransfers,
    ERC20BatchTransfers,
    ERC20Mintable,
    ERC20Burnable,
    TokenRecovery,
    ForwarderRegistryContext
{
    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        IForwarderRegistry forwarderRegistry
    ) ERC20Detailed(tokenName, tokenSymbol, tokenDecimals) ForwarderRegistryContext(forwarderRegistry) ContractOwnership(msg.sender) {}

    /// @inheritdoc ForwarderRegistryContextBase
    function _msgSender() internal view virtual override(Context, ForwarderRegistryContextBase) returns (address) {
        return ForwarderRegistryContextBase._msgSender();
    }

    /// @inheritdoc ForwarderRegistryContextBase
    function _msgData() internal view virtual override(Context, ForwarderRegistryContextBase) returns (bytes calldata) {
        return ForwarderRegistryContextBase._msgData();
    }
}
