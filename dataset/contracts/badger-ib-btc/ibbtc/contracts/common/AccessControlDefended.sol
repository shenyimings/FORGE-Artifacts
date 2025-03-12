// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import {GovernableProxy} from "./proxy/GovernableProxy.sol";

contract AccessControlDefended is GovernableProxy {
    mapping (address => bool) public approved;
    mapping(address => uint256) public blockLock;
    uint256[50] private __gap;

    modifier defend() {
        require(msg.sender == tx.origin || approved[msg.sender], "ACCESS_DENIED");
        _;
    }

    modifier blockLocked() {
        require(blockLock[msg.sender] < block.number, "BLOCK_LOCKED");
        _;
    }

    function _lockForBlock(address account) internal {
        blockLock[account] = block.number;
    }

    function approveContractAccess(address account) external onlyGovernance {
        approved[account] = true;
    }

    function revokeContractAccess(address account) external onlyGovernance {
        approved[account] = false;
    }
}
