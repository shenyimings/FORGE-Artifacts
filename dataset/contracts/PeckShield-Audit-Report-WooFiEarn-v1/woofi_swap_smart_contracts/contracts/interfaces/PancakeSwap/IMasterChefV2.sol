// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IMasterChefV2 {
    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function pendingCake(uint256 _pid, address _user) external view returns (uint256);

    function poolInfo(uint256 _pid)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            bool
        );

    function lpToken(uint256 _pid) external view returns (address);

    function userInfo(uint256 _pid, address _user)
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        );

    function emergencyWithdraw(uint256 _pid) external;
}
