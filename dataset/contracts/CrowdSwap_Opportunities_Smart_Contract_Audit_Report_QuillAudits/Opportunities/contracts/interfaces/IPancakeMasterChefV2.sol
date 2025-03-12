// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IPancakeMasterChefV2 is IERC20Upgradeable {

    function userInfo(uint256 _pId, address _userAddress) view external returns (uint256 amount, uint256 rewardDebt, uint256 boostMultiplier);
    function deposit(uint256 _pId, uint256 _amount) external;
    function withdraw(uint256 _pId, uint256 _shares) external;
    function pendingCake(uint256 _pId, address _user) external view returns (uint256);
}
