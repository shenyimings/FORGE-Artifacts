// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

import "../interfaces/ISYMRate.sol";

contract SYMRate is ISYMRate, AccessControlEnumerable {
    // release rate in seconds
    Rate[] public rates;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function changeRate(Rate[] calldata _rates) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_rates.length > 0, "SYMRate: empty rate");
        require(_rates[_rates.length - 1].rate == 0, "SYMRate: never end");
        delete rates;
        uint t = 0;
        for (uint i = 0; i < _rates.length; ++i) {
            require(_rates[i].startTime > t, "SYMRate: invalid");
            t = _rates[i].startTime;
            rates.push(_rates[i]);
        }
    }

    function getSum(uint start, uint end) external view returns (uint sum) {
        uint len = rates.length;
        sum = 0;
        for (uint i = 0; i < len; ++i) {
            if (i + 1 < len && start >= rates[i + 1].startTime) continue;
            uint left = rates[i].startTime;
            if (end <= left) break;
            if (left < start) left = start;
            uint right = end;
            if (i + 1 < len && rates[i + 1].startTime < right) {
                right = rates[i + 1].startTime;
            }
            sum = sum + rates[i].rate * (right - left);
        }
    }
}
