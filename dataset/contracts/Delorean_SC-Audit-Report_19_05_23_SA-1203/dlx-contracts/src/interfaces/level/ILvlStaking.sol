// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

interface ILvlStaking {
    function LVL() external view returns (address);
    function LLP() external view returns (address);
    function WETH() external view returns (address);

    function userInfo(address) external view returns (uint256, int256);

    function pendingRewards(address _to) external view returns (uint256);
    function stake(address _to, uint256 _amount) external;
    function unstake(address _to, uint256 _amount) external;
    function claimRewards(address _to) external;
    function update() external;
}
