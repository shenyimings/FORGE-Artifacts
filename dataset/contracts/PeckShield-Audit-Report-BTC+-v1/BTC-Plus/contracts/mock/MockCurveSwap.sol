// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "../interfaces/curve/ICurveFi.sol";

/**
 * @notice Mock Curve swap.
 */
contract MockCurveSwap is ICurveFi {

    function get_virtual_price() external pure override returns (uint256) {
        return 11 * 10**17;
    }

    function remove_liquidity_one_coin(uint256 token_amount, int128 iint128, uint256 min_amount) external override {}

    // ren pool/hbtc pool
    function add_liquidity(
        uint256[2] calldata amounts,
        uint256 min_mint_amount
    ) external override {}

    function remove_liquidity_imbalance(uint256[2] calldata amounts, uint256 max_burn_amount) external override {}

    function remove_liquidity(uint256 _amount, uint256[2] calldata amounts) external override {}

    // sbtc pool
    function add_liquidity(
        uint256[3] calldata amounts,
        uint256 min_mint_amount
    ) external override {}

    function remove_liquidity_imbalance(uint256[3] calldata amounts, uint256 max_burn_amount) external override {}

    function remove_liquidity(uint256 _amount, uint256[3] calldata amounts) external override {}

    // obtc pool
    function add_liquidity(
        uint256[4] calldata amounts,
        uint256 min_mint_amount
    ) external override {}

    function remove_liquidity_imbalance(uint256[4] calldata amounts, uint256 max_burn_amount) external override {}

    function remove_liquidity(uint256 _amount, uint256[4] calldata amounts) external override {}

    function exchange(
        int128 from,
        int128 to,
        uint256 _from_amount,
        uint256 _min_to_amount
    ) external override {}
}