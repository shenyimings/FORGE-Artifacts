// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./VotingEscrowCallback.sol";

contract VotingEscrowCallbackRelayer is VotingEscrowCallback, AccessControlEnumerable {
    using EnumerableSet for EnumerableSet.AddressSet;

    event CallbackHandleAdded(address callbackHandle);
    event CallbackHandleRemoved(address callbackHandle);

    EnumerableSet.AddressSet private _handles;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function getCallbackHandles() external view returns (address[] memory handles) {
        uint length = _handles.length();
        handles = new address[](length);
        for (uint i = 0; i < length; i++) {
            handles[i] = _handles.at(i);
        }
    }

    function addCallbackHandle(address callbackHandle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_handles.add(callbackHandle)) {
            emit CallbackHandleAdded(callbackHandle);
        }
    }

    function removeCallbackHandle(address callbackHandle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_handles.remove(callbackHandle)) {
            emit CallbackHandleRemoved(callbackHandle);
        }
    }

    function syncWithVotingEscrow(address _account) external override {
        uint len = _handles.length();
        for (uint i = 0; i < len; ++i) {
            VotingEscrowCallback(_handles.at(i)).syncWithVotingEscrow(_account);
        }
    }
}
