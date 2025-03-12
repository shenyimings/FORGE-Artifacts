//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/governance/utils/IVotesUpgradeable.sol";

import "./components/IERC20VestableVotesUpgradeable.1.sol";

/// @title TLC Interface (v1)
/// @author Alluvial Finance Inc.
/// @notice TLC token interface
interface ITLCV1 is IERC20Upgradeable, IVotesUpgradeable, IERC20VestableVotesUpgradeableV1 {
    /// @notice Initializes the TLC Token
    /// @param _account The initial account to grant all the minted tokens
    function initTLCV1(address _account) external;

    /// @notice Migrates the vesting schedule state structures
    function migrateVestingSchedules() external;
}
