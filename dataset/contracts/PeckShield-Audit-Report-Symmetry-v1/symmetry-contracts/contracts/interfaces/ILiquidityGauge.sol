// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface ILiquidityGauge {
    /*=== struct ===*/

    // user info
    struct UserInfo {
        uint amount; // Amount of tokens the user staked.
        uint workingPower; // boosted user share.
        uint rewardPerShare; // Accumulated reward per share.
    }

    /*=== event ===*/
    event Deposit(address indexed user, uint amount);
    event Withdraw(address indexed user, uint amount);
    event UpdateWorkingPower(address indexed user, uint workingPower);

    /*=== function ===*/
    function symRate() external view returns (address);

    function accRewardPerShare() external view returns (uint);

    function deposit(uint _amount) external returns (uint);

    function depositAfterMint(address _account, uint _amount) external returns (uint reward);

    function k() external view returns (uint);

    function lastRewardTime() external view returns (uint);

    function lpToken() external view returns (address);

    function token() external view returns (address);

    function totalStaked() external view returns (uint);

    function totalWorkingPower() external view returns (uint);

    function update() external;

    function userInfo(address) external view returns (uint amount, uint workingPower, uint rewardPerShare);

    function votingEscrow() external view returns (address);

    function withdraw(uint _amount) external returns (uint reward);
}
