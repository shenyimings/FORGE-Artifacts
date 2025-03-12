// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IManagerActions } from "./IManagerActions.sol";
import { IManagerState } from "./IManagerState.sol";
import { IBattleInitializer } from "./IBattleInitializer.sol";
import { IPeripheryImmutableState } from "./IPeripheryImmutableState.sol";
import { IPeripheryPayments } from "./IPeripheryPayments.sol";

interface IManager is
    IBattleInitializer,
    IManagerActions,
    IManagerState
{ }
