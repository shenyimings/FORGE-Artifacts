// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

/// @dev https://github.com/bloxapp/ssv-network/blob/8c945e82cc063eb8e40c467d314a470121821157/contracts/interfaces/ISSVViews.sol
interface ISSVViews {
    /// @notice Gets operator details by ID
    /// @param operatorId The ID of the operator
    /// @return owner The owner of the operator
    /// @return fee The fee associated with the operator (SSV)
    /// @return validatorCount The count of validators associated with the operator
    /// @return whitelisted The whitelisted address of the operator, if any
    /// @return isPrivate A boolean indicating if the operator is private
    /// @return active A boolean indicating if the operator is active
    function getOperatorById(uint64 operatorId) external view returns (address owner, uint256 fee, uint32 validatorCount, address whitelisted, bool isPrivate, bool active);
}
