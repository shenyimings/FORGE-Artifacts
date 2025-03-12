// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.16;

import {ICryptoSwap} from "./ICryptoSwap.sol";
import {IMath} from "./IMath.sol";

interface ICurveCryptoViews {
    function math() external view returns (IMath);

    function get_dy(ICryptoSwap cryptoSwap, uint256 i, uint256 j, uint256 dx) external view returns (uint256);

    function get_dy_no_fee_deduct(ICryptoSwap cryptoSwap, uint256 i, uint256 j, uint256 dx)
        external
        view
        returns (uint256);

    function get_dy_fees(ICryptoSwap cryptoSwap, uint256 i, uint256 j, uint256 dx) external view returns (uint256);

    function get_dy_fees_perc(ICryptoSwap cryptoSwap, uint256 i, uint256 j, uint256 dx)
        external
        view
        returns (uint256);

    function get_dx_ex_fees(ICryptoSwap cryptoSwap, uint256 i, uint256 j, uint256 dy) external view returns (uint256);
}
