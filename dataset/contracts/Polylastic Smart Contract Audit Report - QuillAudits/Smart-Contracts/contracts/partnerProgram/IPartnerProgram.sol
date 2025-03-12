// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IPartnerProgram {
    function setupRoleIndex(address index) external;

    function distributeTheReward(
        address referral,
        uint256 amount,
        address token
    ) external returns (uint256 amountWithoutTax);

    /// @notice set the referrer
    /// @param referrer rspecify the referrer address
    function setReferrer(address referrer) external;

    /// @notice Sets the amount of the reward and the number of levels in the referral program
    /// @dev The number of levels depends on the size of the array.
    /// * the data inside the array shows the percentage of reward at each level
    /// * Can only be called by a user with the right DAO_ADMIN_ROLE
    /// @param percentReward the data must be specified taking into account the precission
    /// * the amount of data inside the array is equal to the number of levels
    /// * example [10000000, 5000000] equal first level =10%, second level = 5%
    function setPercentReward(uint256[] memory percentReward) external;
}
