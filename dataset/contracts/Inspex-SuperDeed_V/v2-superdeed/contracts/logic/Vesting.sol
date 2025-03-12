
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;
import "../lib/DataType.sol";
import "../lib/Constant.sol";

library Vesting {

    function defineVesting(DataType.Groups storage groups, uint groupId, DataType.VestingItem[] calldata vestItems) internal returns (uint) {
        
        uint len = vestItems.length;
        _require(groupId < groups.items.length && len > 0, "Invalid parameter");

        DataType.Group storage item = groups.items[groupId];

        // Clear existing vesting items
        delete item.vestItems;

        // Append items
        uint totalPercent;
        for (uint n=0; n<len; n++) {

            DataType.VestingReleaseType relType = vestItems[n].releaseType;

            _require(relType < DataType.VestingReleaseType.Unsupported, "Invalid type");
            _require(!(relType == DataType.VestingReleaseType.Linear && vestItems[n].duration == 0), "Linear type cannot have 0 duration");
            _require(vestItems[n].percent > 0, "Invalid percent");
            
            totalPercent += vestItems[n].percent;
            item.vestItems.push(vestItems[n]);
        }
        // The total percent have to add up to 100 %
        _require(totalPercent == Constant.PCNT_100, "Must add up to 100%");
        return len;
    }

    function getClaimable(DataType.Groups storage groups, uint groupId) internal view returns (uint claimablePercent) {

        _require(groupId < groups.items.length, "Invalid group Id");

        uint start = groups.vestingStartTime;
        uint end = block.timestamp;

        // Vesting not started yet ?
        if (start == 0 || end <= start) {
            return 0;
        }

        DataType.VestingItem[] storage items = groups.items[groupId].vestItems;
        uint len = items.length;
       
        for (uint n=0; n<len; n++) {

            (uint percent, bool continueNext, uint traverseBy) = getRelease(items[n], start, end);
            claimablePercent += percent;

            if (continueNext) {
                start += traverseBy;
            } else {
                break;
            }
        }
    }

    function getRelease(DataType.VestingItem storage item, uint start, uint end) internal view returns (uint releasedPercent, bool continueNext, uint traverseBy) {

        releasedPercent = 0;
        bool passedDelay = (end > (start + item.delay));
        if (passedDelay) {
           
            if (item.releaseType == DataType.VestingReleaseType.LumpSum) {
                releasedPercent = item.percent;
                continueNext = true;
                traverseBy = item.delay;
            } else if (item.releaseType == DataType.VestingReleaseType.Linear) {
                uint elapsed = end - start - item.delay;
                releasedPercent = min(item.percent, (item.percent * elapsed) / item.duration);
                continueNext = (end > (start + item.delay + item.duration));
                traverseBy = (item.delay+item.duration);
            } 
            else {
                assert(false);
            }
        } 
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _require(bool condition, string memory error) pure internal {
        require(condition, error);
    }
}
