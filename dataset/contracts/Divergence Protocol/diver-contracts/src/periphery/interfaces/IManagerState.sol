// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { PositionState, Position } from "../types/common.sol";

interface IManagerState {
    /**
     * @notice Get the position belong to a nft
     */
    function positions(uint256 tokenId) external view returns (Position memory);

    struct AccountPosition {
        address battleAddr;
        uint256 tokenId;
        Position position;
    }
    /**
     * @notice Get all positions belong to an account
     */

    function accountPositions(address account) external view returns (Position[] memory);
}
