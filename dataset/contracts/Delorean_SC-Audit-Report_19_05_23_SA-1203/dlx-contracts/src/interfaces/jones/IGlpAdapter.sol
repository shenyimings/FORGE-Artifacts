// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IGlpAdapter {
    function depositGlp(uint256 _assets, bool _compound) external returns (uint256);
    function belowCap(uint256 _amount) external view returns (bool);
}
