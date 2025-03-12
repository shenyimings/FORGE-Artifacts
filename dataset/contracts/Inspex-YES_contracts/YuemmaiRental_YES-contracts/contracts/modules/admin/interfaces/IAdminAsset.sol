//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IAdminAsset {
    function isSuperAdmin(address _addr, string calldata _token) external view returns (bool);
}