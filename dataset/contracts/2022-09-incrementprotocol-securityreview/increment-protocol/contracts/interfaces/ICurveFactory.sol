// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.16;

// source: https://etherscan.io/address/0x0959158b6040D32d04c301A72CBFD6b39E21c9AE#code
// github: https://github.com/curvefi/curve-factory/blob/master/contracts/Factory.vy
interface ICurveFactory {
    function find_pool_for_coins(address _from, address _to, uint256 i) external view returns (address);

    function get_n_coins(address _pool) external view returns (uint256, uint256);

    function get_coins(address _pool) external view returns (address[2] memory);

    function get_underlying_coins(address _pool) external view returns (address[2] memory);

    function get_decimals(address _pool) external view returns (uint256[2] memory);

    function get_underlying_decimals(address _pool) external view returns (uint256[2] memory);

    function get_rates(address _pool) external view returns (uint256[2] memory);

    function get_balances(address _pool) external view returns (uint256[2] memory);

    function get_underlying_balances(address _pool) external view returns (uint256[2] memory);

    function get_A(address _pool) external view returns (uint256);

    function get_fees(address _pool) external view returns (uint256, uint256);

    function get_admin_balances(address _pool) external view returns (uint256[2] memory);

    function get_coin_indices(address _pool, address _from, address _to) external view returns (int128, int128, bool);

    function add_base_pool(address _base_pool, address _metapool_implementation, address _fee_receiver) external;

    // not sure wether arrays should be memory or calldata!

    function deploy_metapool(
        address _base_pool,
        string[32] memory _name,
        string[10] memory _symbol,
        address _coin,
        uint256 _A,
        uint256 _fee
    ) external returns (address);

    function commit_transfer_ownership(address addr) external;

    function accept_transfer_ownership() external;

    function set_fee_receiver(address _base_pool, address _fee_receiver) external;

    function convert_fees() external returns (bool);

    // @notice Deploy a new plain pool
    // @param _name Name of the new plain pool
    // @param _symbol Symbol for the new plain pool - will be
    //                concatenated with factory symbol
    // @param _coins List of addresses of the coins being used in the pool.
    // @param _A Amplification co-efficient - a lower value here means
    //           less tolerance for imbalance within the pool's assets.
    //           Suggested values include:
    //            * Uncollateralized algorithmic stablecoins: 5-10
    //            * Non-redeemable, collateralized assets: 100
    //            * Redeemable assets: 200-400
    // @param _fee Trade fee, given as an integer with 1e10 precision. The
    //             minimum fee is 0.04% (4000000), the maximum is 1% (100000000).
    //             50% of the fee is distributed to veCRV holders.
    // @param _asset_type Asset type for pool, as an integer
    //                    0 = USD, 1 = ETH, 2 = BTC, 3 = Other
    // @param _implementation_idx Index of the implementation to use. All possible
    //             implementations for a pool of N_COINS can be publicly accessed
    //             via `plain_implementations(N_COINS)`
    // @return Address of the deployed pool
    function deploy_plain_pool(
        string[32] memory _name,
        string[10] memory _symbol,
        address[2] memory _coins,
        uint256 _A,
        uint256 _fee,
        uint256 _asset_type,
        uint256 _implementation_idx
    ) external returns (address);
}
