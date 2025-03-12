// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IPoolHelper {

    function totalSupply() external view returns (uint256);

    /// @notice get the amount of reward per token deposited by a user
    /// @param token the token to get the number of rewards
    /// @return the amount of claimable tokens
    function rewardPerToken(address token) external view returns (uint256);

    /// @notice get the total amount of shares of a user
    /// @param _address the user
    /// @return the amount of shares
    function balance(address _address) external view returns (uint256);

    /// @notice get the total amount of stables deposited by a user
    /// @return the amount of stables deposited
    function depositTokenBalance() external view returns (uint256);

    /// @notice deposit stables in mainStaking, autostake in masterchief of VTX
    /// @dev performs a harvest of PTP just before depositing
    /// @param amount the amount of stables to deposit
    function deposit(uint256 amount) external;

    /// @notice withdraw stables from mainStaking, auto unstake from masterchief of VTX
    /// @dev performs a harvest of PTP before withdrawing
    /// @param amount the amount of stables to deposit
    function withdraw(uint256 amount, uint256 minAmount) external;

    /// @notice Harvest VTX and PTP rewards
    function getReward() external;

}
