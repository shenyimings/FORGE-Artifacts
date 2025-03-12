// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

/// @notice Referral interface
/// @author Romuald Hog.
interface IReferral {
    /// @notice Adds an address as referrer.
    /// @param user The address of the user.
    /// @param referrer The address would set as referrer of user.
    function addReferrer(address user, address referrer) external;

    /// @notice Updates referrer's last active timestamp.
    /// @param user The address would like to update active time.
    function updateReferrerActivity(address user) external;

    /// @notice Calculates and allocate referrer(s) credits to uplines.
    /// @param user Address of the gamer to find referrer(s).
    /// @param token The token to allocate.
    /// @param amount The number of tokens allocated for referrer(s).
    function payReferral(
        address user,
        address token,
        uint256 amount
    ) external returns (uint256);

    /// @notice Utils function for check whether an address has the referrer.
    /// @param user The address of the user.
    /// @return Whether user has a referrer.
    function hasReferrer(address user) external view returns (bool);
}
