// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IAmmStaker {
    function shutdown() external;

    function setAmmToken(address _ammToken) external;

    function claimRewards() external returns (uint256);

    function executeInflationRateUpdate() external;

    function claimableRewards(address user) external view returns (uint256);

    function stakeFor(address account, uint256 amount) external;

    function unstakeFor(address dst, uint256 amount) external;

    function globalCheckpoint() external returns (bool);
}
