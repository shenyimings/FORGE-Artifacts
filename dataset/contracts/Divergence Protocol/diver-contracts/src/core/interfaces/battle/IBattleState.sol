// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// import { PositionInfo } from "../../types/common.sol";
// import { Position } from "../../libs/Position.sol";
// import { Outcome } from "../../types/enums.sol";
// import { BattleKey } from "../../types/common.sol";
// import { BaseInfo } from "../../types/comddmon.sol/BaseInfo.sol";
// import { GrowthX128 } from "../../types/common.sol";
import "../../types/common.sol";

interface IBattleState {
    /// @notice Get slotInfo by slotKey.
    /// @param pk positon key check how slotKey is generated in Position.sol
    /// @param info check PositionInfo in PositionTypes.sol
    function positions(bytes32 pk) external view returns (PositionInfo memory info);

    /// @notice The result of battle.
    /// @return result check different battle result type in Outcome.sol
    function battleOutcome() external view returns (Outcome);

    /// @notice A battleKey can uniquely identify a battle
    function battleKey() external view returns (BattleKey memory key);

    /// @notice Get Manager address in this battle
    function manager() external view returns (address);

    /// @notice BaseInfo includes current sqrtPriceX96, current tick
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, bool unlocked);

    function spearAndShield() external view returns (address, address);

    function startAndEndTS() external view returns (uint256, uint256);

    function spearBalanceOf(address account) external view returns (uint256 amount);

    function shieldBalanceOf(address account) external view returns (uint256 amount);

    function spear() external view returns (address);

    function shield() external view returns (address);

    function getInsideLast(int24 tickLower, int24 tickUpper) external view returns (GrowthX128 memory);
}
