// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "./IRoleAccess.sol";

interface IDeedManager {
    function addDeed(address deedContract, address projectOwner) external;   
    function getRoles() external view returns (IRoleAccess);
    function getDeedsCount() external view returns(uint);
}

