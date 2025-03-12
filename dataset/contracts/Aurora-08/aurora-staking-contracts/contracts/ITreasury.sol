// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface ITreasury {
    function payRewards(
        address _user,
        address _token,
        uint256 _deposit
    ) external;
}
