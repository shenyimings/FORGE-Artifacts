// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.6.10;

interface ICurvePool {
    function get_virtual_price() external view returns (uint256);
}
