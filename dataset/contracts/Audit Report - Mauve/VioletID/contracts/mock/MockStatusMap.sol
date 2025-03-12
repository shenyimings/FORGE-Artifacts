// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { StatusMap } from "../StatusMap.sol";

contract MockStatusMap is StatusMap {
    function isStatusSet(address account, uint8 index) public view returns (bool) {
        return _isStatusSet(account, index);
    }

    function areStatusesSet(address account, uint256 mask) public view returns (bool) {
        return _areStatusesSet(account, mask);
    }

    function overwriteStatusTo(address account, uint8 index, bool value) public {
        _overwriteStatusTo(account, index, value);
    }

    function assignMultipleStatuses(address account, uint256 indicesMask) public {
        _assignMultipleStatuses(account, indicesMask);
    }

    function assignStatus(address account, uint8 index) public {
        _assignStatus(account, index);
    }

    function unassignStatus(address account, uint8 index) public {
        _unassignStatus(account, index);
    }
}
