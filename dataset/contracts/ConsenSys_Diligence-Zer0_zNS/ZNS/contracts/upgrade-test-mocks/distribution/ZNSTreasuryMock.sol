// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ZNSTreasury } from "../../treasury/ZNSTreasury.sol";
import { UpgradeMock } from "../UpgradeMock.sol";

 /* solhint-disable */
contract ZNSTreasuryUpgradeMock is ZNSTreasury, UpgradeMock {}
