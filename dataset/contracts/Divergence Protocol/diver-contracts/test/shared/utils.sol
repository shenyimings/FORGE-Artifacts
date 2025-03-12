// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

enum Period {
    DAILY,
    WEEKLY,
    BIWEEKLY,
    MONTHLY
}

function getTS(Period period) view returns (uint256 start, uint256 end) {
    uint256 offset = 0;
    if (period == Period.DAILY) {
        start = block.timestamp - ((block.timestamp - 28_800) % 86_400);
        start = start + 86_400 * offset;
        end = start + 86_400;
    } else if (period == Period.WEEKLY) {
        start = block.timestamp - ((block.timestamp - 115_200) % 604_800);
        start = start + 604_800 * offset;
        end = start + 604_800;
    } else if (period == Period.BIWEEKLY) {
        // 1 => BIWEEKLY
        start = block.timestamp - ((block.timestamp - 115_200) % 604_800);
        start = start + 1_209_600 * offset;
        end = start + 1_209_600;
    } else if (period == Period.MONTHLY) {
        // 2 => MONTHLY
        // for (uint256 i; i < monStartTS.length; i++) {
        //     if (block.timestamp >= monStartTS[i] && block.timestamp <=
        // monStartTS[i + 1]) {
        //         uint256 index = i + offset;
        //         start = monStartTS[index];
        //         end = monStartTS[index + 1];
        //     }
        // }
        // require(start != 0, "not known start ts");
        // require(end != 0, "not known end ts");
    }
}
