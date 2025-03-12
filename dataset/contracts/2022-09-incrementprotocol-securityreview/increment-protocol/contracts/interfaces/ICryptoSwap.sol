// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.16;

/// @dev Contract https://github.com/curvefi/curve-crypto-contract/blob/master/deployment-logs/2021-11-01.%20EURS%20on%20mainnet/CryptoSwap.vy
interface ICryptoSwap {
    function get_virtual_price() external view returns (uint256);

    function price_oracle() external view returns (uint256);

    function mid_fee() external view returns (uint256);

    function out_fee() external view returns (uint256);

    function admin_fee() external view returns (uint256);

    function A() external view returns (uint256);

    function gamma() external view returns (uint256);

    function price_scale() external view returns (uint256);

    function balances(uint256 i) external view returns (uint256);

    function D() external view returns (uint256);

    function owner() external view returns (address);

    function fee_calc(uint256[2] memory x) external view returns (uint256);

    function calc_token_fee(uint256[2] memory amounts, uint256[2] memory xp) external view returns (uint256);

    function future_A_gamma_time() external view returns (uint256);

    // Swap token i to j with amount dx and min amount min_dy
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external returns (uint256);

    function get_dy(uint256 i, uint256 j, uint256 dx) external view returns (uint256);

    function calc_token_amount(uint256[2] calldata amounts) external view returns (uint256);

    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external returns (uint256); // WARNING: Has to be memory to be called within the perpetual contract, but you should use calldata

    function remove_liquidity(uint256 _amount, uint256[2] memory min_amounts) external; // WARNING: Has to be memory to be called within the perpetual contract, but you should use calldata

    function ramp_A_gamma(uint256 future_A, uint256 future_gamma, uint256 future_time) external;

    function last_prices() external view returns (uint256);

    function token() external view returns (address);

    function coins(uint256 i) external view returns (address);

    function allowed_extra_profit() external view returns (uint256);

    function fee_gamma() external view returns (uint256);

    function adjustment_step() external view returns (uint256);

    function ma_half_time() external view returns (uint256);

    function virtual_price() external view returns (uint256);

    function xcp_profit() external view returns (uint256);

    function xcp_profit_a() external view returns (uint256);

    function claim_admin_fees() external;
}
