// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

interface IArkenStaker {
    function getPoolId(address lp) external view returns (uint256 pid);

    function deposit(uint256 _pid, uint256 _amount) external;

    function depositFor(
        uint256 _pid,
        address _for,
        uint256 _amount
    ) external;

    function withdraw(
        uint256 _pid,
        address _to,
        uint256 _amount
    ) external;

    function withdrawFor(
        uint256 _pid,
        address _user,
        address _to,
        uint256 _amount
    ) external;

    function pendingArken(uint256 _pid, address _user)
        external
        view
        returns (uint256 pending);
}
