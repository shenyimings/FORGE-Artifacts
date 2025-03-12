//SPDX-License-Identifier: MIT
pragma solidity >= 0.5.0;

interface IKYC {
    function kycsLevel(address _addr) external view returns (uint256);
}