// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface ICurvePool {
    function coins(uint256 i) external view returns (address);

    function remove_liquidity_one_coin(
        uint256 lp,
        int128 i,
        uint256 min_amount
    ) external;

    function calc_withdraw_one_coin(uint256 lp, int128 i) external view returns (uint256);

    function balanceOf(address user) external view returns (uint256);
}
