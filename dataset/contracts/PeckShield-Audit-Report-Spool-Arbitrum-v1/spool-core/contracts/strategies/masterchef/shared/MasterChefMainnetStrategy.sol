// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "./MasterChefStrategyBase.sol";
import "../../../shared/SwapHelperMainnet.sol";

/**
 * @notice Mainnet MasterChef strategy implementation
 */
abstract contract MasterChefMainnetStrategy is MasterChefStrategyBase, SwapHelperMainnet {}

