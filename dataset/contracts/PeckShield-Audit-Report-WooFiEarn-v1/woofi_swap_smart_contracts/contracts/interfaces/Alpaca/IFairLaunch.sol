// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IFairLaunch {
    function deposit(
        address _for,
        uint256 pid,
        uint256 _amount
    ) external; // staking

    function withdraw(
        address _for,
        uint256 _pid,
        uint256 _amount
    ) external; // unstaking

    function harvest(uint256 _pid) external;

    function pendingAlpaca(uint256 _pid, address _user) external returns (uint256);

    function userInfo(uint256, address)
        external
        view
        returns (
            uint256 amount,
            uint256 rewardDebt,
            uint256 bonusDebt,
            uint256 fundedBy
        );

    function poolInfo(uint256)
        external
        view
        returns (
            address stakeToken,
            uint256 allocPoint,
            uint256 lastRewardBlock,
            uint256 accAlpacaPerShare,
            uint256 accAlpacaPerShareTilBonusEnd
        );
}
