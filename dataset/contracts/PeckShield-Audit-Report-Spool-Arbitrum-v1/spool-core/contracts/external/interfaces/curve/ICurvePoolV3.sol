// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface ICurvePoolV3 {
    function coins(uint256 i) external view returns (address);
}
