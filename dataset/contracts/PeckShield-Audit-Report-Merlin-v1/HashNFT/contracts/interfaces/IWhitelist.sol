
// contracts/Whitelist.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWhitelist {
    function verify(address address_) external view returns(bool);
}