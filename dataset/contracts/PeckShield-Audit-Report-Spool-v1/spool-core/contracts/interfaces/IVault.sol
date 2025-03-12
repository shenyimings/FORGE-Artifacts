// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./vault/IVaultRestricted.sol";
import "./vault/IVaultIndexActions.sol";
import "./vault/IRewardDrip.sol";
import "./vault/IVaultBase.sol";
import "./vault/IVaultImmutable.sol";

interface IVault is IVaultRestricted, IVaultIndexActions, IRewardDrip, IVaultBase, IVaultImmutable {}
