// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

/// @title Cosolidated Errors from Synthetix v3 contracts
/// @notice This contract consolidates all necessary errors from Synthetix v3 contracts
/// and is used for testing purposes
/// @author JaredBorders (jaredborders@pm.me)
contract SynthetixV3Errors {
    error WrapperExceedsMaxAmount(
        uint256 maxWrappableAmount, uint256 currentSupply, uint256 amountToWrap
    );
}
