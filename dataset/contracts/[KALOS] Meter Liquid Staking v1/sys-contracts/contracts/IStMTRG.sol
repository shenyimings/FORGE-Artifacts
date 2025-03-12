// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStMTRG {
    function shareToValue(uint256 _share) external view returns (uint256);

    function valueToShare(uint256 _value) external view returns (uint256);
}
