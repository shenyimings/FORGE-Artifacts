// SPDX-License-Identifier: ISC

pragma solidity ^0.8.13;

interface IWETH {
    function approve(address guy, uint wad) external returns (bool);
}
