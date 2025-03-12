// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/// @dev Mock for testing. NOT to be deployed on mainnet!!!
interface IMockSsvNetwork {
    function setRegisterAuth(address userAddress, bool authOperators, bool authValidators) external;
}
