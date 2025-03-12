// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface IMasterMeerkat {

    // Info of each user that stakes LP tokens.
    function userInfo(uint256 _pid, address account) external view returns(uint256 amount, uint256 rewardDebt);

    // Deposit LP tokens to MasterChef for MMF allocation.
    function deposit(uint256 _pid, uint256 _amount, address _referrer) external;

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) external;

}
