// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.16;

// source: https://etherscan.io/address/0xf18056bbd320e96a48e3fbf8bc061322531aac99
// github: https://github.com/curvefi/curve-factory-crypto/blob/e2a59ab163b5b715b38500585a5d1d9c0671eb34/contracts/Factory.vy#L151-L164
// twitter1: https://twitter.com/adamscochran/status/1482099244127428614?t=6RdLKo_QIzk0nM6cbG88NQ&s=09
// twitter2: https://twitter.com/CurveFinance/status/1483933324360003590
interface ICurveCryptoFactory {
    /*
     @notice: define _name / _symbol as string instead of string[x] to avoid decoding issues
              seem to work in practice: https://etherscan.io/tx/0x985039e1ef998dfe019b835a8bcb88fc3db9c9c684ffe6583ed038c93bcf6e04
    */
    function deploy_pool(
        string memory _name,
        string memory _symbol,
        address[2] memory _coins,
        uint256 A,
        uint256 gamma,
        uint256 mid_fee,
        uint256 out_fee,
        uint256 allowed_extra_profit,
        uint256 fee_gamma,
        uint256 adjustment_step,
        uint256 admin_fee,
        uint256 ma_half_time,
        uint256 initial_price
    ) external returns (address);

    function find_pool_for_coins(address _from, address _to, uint256 i) external view returns (address);

    function admin() external view returns (address);

    function fee_receiver() external view returns (address);
}
