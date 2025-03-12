// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IBonusProxy {
    function bonus(address user) external view returns (uint);
}
