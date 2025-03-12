// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./IRoleAccess.sol";


interface IManager {
    function addCampaign(address newContract, address projectOwner) external;
    function getFeeVault() external view returns (address);
    function getSvLaunchAddress() external view returns (address);
    function getEggAddress() external view returns (address);
    function getRoles() external view returns (IRoleAccess);
}

