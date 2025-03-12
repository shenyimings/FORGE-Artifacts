// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

interface IStakePoolEpochReward {
    event AllocateReward(uint256 blocktime, uint256 amount);
    event Deposit(address indexed account, uint256 amount);
    event PayRewardPool(uint256 indexed poolId, address indexed rewardToken, address indexed account, uint256 pendingReward, uint256 rebaseAmount, uint256 paidReward);
    event Withdraw(address indexed account, uint256 amount);

    function version() external view returns (uint256);
    function stakeToken() external view returns (address);
    function rewardToken() external view returns (address);
    function rewardFund() external view returns (address);
    function epochController() external view returns (address);

    function allowRecoverRewardToken(address _token) external view returns (bool);

    function epoch() external view returns (uint256);

    function nextEpochPoint() external view returns (uint256);

    function nextEpochLength() external view returns (uint256);

    function nextEpochAllocatedReward() external view returns (uint256);

    function earned(address _account) external view returns (uint256);

    function unlockWithdrawEpoch(address _account) external view returns (uint256);

    function unlockRewardEpoch(address _account) external view returns (uint256);

    function stake(uint256) external;

    function stakeFor(address _account) external;

    function withdraw(uint256) external;

    function claimReward() external;

    function emergencyWithdraw() external;

    function setEpochController(address) external;

    function setLockUp(uint256 _withdrawLockupEpochs, uint256 _rewardLockupEpochs) external;

    function allocateReward(uint256 _amount) external;
}
