// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

interface IGnosisSafeL2 {
    function isOwner(address owner) external view returns (bool);

    function getOwners() external view returns (address[] memory);
}
