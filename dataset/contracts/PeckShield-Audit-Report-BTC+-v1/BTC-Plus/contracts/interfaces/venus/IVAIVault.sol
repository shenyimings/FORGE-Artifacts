// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
pragma experimental ABIEncoderV2;

/**
 * @dev Interface for VAI Vault
 */
interface IVAIVault {

    /**
     * @notice Deposit VAI to VAIVault for XVS allocation
     * @param _amount The amount to deposit to vault
     */
    function deposit(uint256 _amount) external;

    /**
     * @notice Withdraw VAI from VAIVault
     * @param _amount The amount to withdraw from vault
     */
    function withdraw(uint256 _amount) external;

    /**
     * @notice Claim XVS from VAIVault
     */
    function claim() external;

    /**
     * @notice View function to see pending XVS on frontend
     * @param _user The user to see pending XVS
     */
    function pendingXVS(address _user) external view returns (uint256);

    /// @notice Info of each user.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    function userInfo(address _account) external view returns (UserInfo memory);
}