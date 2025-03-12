// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IBattleActions } from "./IBattleActions.sol";
import { IBattleState } from "./IBattleState.sol";
import { IBattleInit } from "./IBattleInit.sol";

interface IBattle is IBattleActions, IBattleInit, IBattleState { }
