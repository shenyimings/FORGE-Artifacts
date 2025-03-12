// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { ILiquidatorStorage } from "./interfaces/ILiquidatorStorage.sol";

abstract contract LiquidatorStorage is ILiquidatorStorage {

    address public override collateralAsset;
    address public override fundsAsset;
    address public override loanManager;

    uint256 public override collateralRemaining;

    uint256 internal locked;

}
