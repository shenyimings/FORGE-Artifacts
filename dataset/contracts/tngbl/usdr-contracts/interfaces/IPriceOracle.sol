// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

interface IPriceOracle {
    function quote(uint256 amountIn) external view returns (uint256);
}
