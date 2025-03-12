// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface ICurvePool {
    function add_liquidity(uint256[2] calldata, uint256) external;

    function add_liquidity(uint256[3] calldata, uint256) external;

    function add_liquidity(uint256[4] calldata, uint256) external;

    function remove_liquidity(uint256, uint256[2] calldata) external;

    function remove_liquidity(uint256, uint256[3] calldata) external;

    function remove_liquidity(uint256, uint256[4] calldata) external;

    function remove_liquidity_imbalance(uint256[2] calldata, uint256) external;

    function remove_liquidity_imbalance(uint256[3] calldata, uint256) external;

    function remove_liquidity_imbalance(uint256[4] calldata, uint256) external;

    function remove_liquidity_one_coin(
        uint256,
        int128,
        uint256
    ) external;

    function get_virtual_price() external view returns (uint256);
}
