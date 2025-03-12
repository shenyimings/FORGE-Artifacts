// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import {ILiquidityModule} from "../modules/ILiquidityModule.sol";
import {IGeodePackage} from "./IGeodePackage.sol";

interface ILiquidityPool is ILiquidityModule, IGeodePackage {}
