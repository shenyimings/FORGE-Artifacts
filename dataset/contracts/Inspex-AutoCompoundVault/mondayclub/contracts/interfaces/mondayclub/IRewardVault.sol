// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRewardVault {
    function rewardToken() external view returns (IERC20);
    function transferReward(address _to, uint256 _amount) external;
    function transferNative(address payable _to, uint256 _amount) external;
}
