// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IKalmOraclePrice {
    
    function kalmPrice() external view returns (uint256);
}
