// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/**
 * @dev Interface for ForTube Rewards
 */
interface IForTubeReward {

    function checkBalance(address _account) external view returns (uint256);

    function claimReward() external;

}
