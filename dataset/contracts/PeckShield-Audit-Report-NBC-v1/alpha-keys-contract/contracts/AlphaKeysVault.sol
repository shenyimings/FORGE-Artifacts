// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

import {IAlphaKeysVault} from "./interfaces/IAlphaKeysVault.sol";
import {AlphaKeysVaultStorage} from "./storage/AlphaKeysVaultStorage.sol";

import {BlockContext} from "./base/BlockContext.sol";
import {Multicall} from "./base/Multicall.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import {IAlphaKeysFactory} from "./interfaces/IAlphaKeysFactory.sol";

import {TransferHelper} from "./libraries/TransferHelper.sol";

contract AlphaKeysVault is
    IAlphaKeysVault,
    BlockContext,
    Multicall,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    AlphaKeysVaultStorage
{
    using AddressUpgradeable for address;

    function initialize(address factory) external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        //
        require(factory.isContract(), "AKF_VINC");
        _factory = factory;
        //
        TransferHelper.safeApprove(
            IAlphaKeysFactory(factory).getBTC(),
            factory,
            type(uint256).max
        );
    }
}
