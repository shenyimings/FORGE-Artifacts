// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface ICurvePoolV2 {
    function coins(int128 i) external view returns (address);
}
