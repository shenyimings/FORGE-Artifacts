// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IPoolHelper {
    function balance(address _address) external view returns (uint256);

    function depositToken() external view returns (address);

    function depositTokenBalance() external view returns (uint256);

    function rewardPerToken(address token) external view returns (uint256);

    function update() external;

    function deposit(uint256 amount) external;

    function stake(uint256 _amount) external;

    function withdraw(uint256 amount, uint256 minAmount) external;

    /// @notice Harvest VTX and PTP rewards for msg.sender
    function getReward() external;

    function mainStaking() external view returns (address);
}
