// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "../lib/DataTypes.sol";
import "../lib/Constant.sol";
import "../lib/Error.sol";

library Vesting {
    
    using Math for uint256;
    
    function setup(
        DataTypes.Vesting storage param,
        DataTypes.VestingReleaseType investorReleaseType,
        DataTypes.VestingReleaseType teamReleaseType,
        uint desiredUnlockTime,
        uint[] calldata investorLockPcnts, 
        uint[] calldata investorLockDurations,
        uint[] calldata teamLockPcnts,
        uint[] calldata teamLockDurations
    ) external {
        _require( (investorLockPcnts.length > 0 && teamLockPcnts.length > 0) &&
            (investorLockPcnts.length == investorLockDurations.length) &&
            (teamLockPcnts.length == teamLockDurations.length) && 
            (desiredUnlockTime > 0), Error.Code.ValidationError);
        
        // If the release type is ByLinearContinuous, then we will have only 1 item in the array of tokens, durations 
        if (investorReleaseType == DataTypes.VestingReleaseType.ByLinearContinuous) {
            _require(investorLockPcnts.length == 1, Error.Code.SingleItemRequired);
        }
        if (teamReleaseType == DataTypes.VestingReleaseType.ByLinearContinuous) {
            _require(teamLockPcnts.length == 1, Error.Code.SingleItemRequired);
        }
        
        param.data.desiredUnlockTime = desiredUnlockTime;
        param.data.investorsLock.pcnts = investorLockPcnts;
        param.data.investorsLock.durations = investorLockDurations;
        param.data.investorsLock.releaseType = investorReleaseType;
        param.data.teamLock.pcnts = teamLockPcnts;
        param.data.teamLock.durations = teamLockDurations;
        param.data.teamLock.releaseType = teamReleaseType;
    }
    
    // Note: This is used to override the desiredUnlockTime to current time. This is triggered from AddAndLockLP only.
    function setVestingTimeNow(DataTypes.Vesting storage param) external {
        // Vesting unlock time should not have started yet
        _require(param.data.desiredUnlockTime > block.timestamp, Error.Code.ValidationError);
        param.data.desiredUnlockTime = block.timestamp;
    }
    
    
    // uint claimedSoFar; // 1E6 means 100%
    // uint claimable;    // 1E6 means 100%
    // uint lockedAmount;  // 1E6 means 100%
    // uint newStartTime;
    // uint endTime;
    function getClaimableByLinear(DataTypes.Vesting storage param, address user, bool investor) public view returns (DataTypes.ClaimLinearResult memory) {
        DataTypes.ClaimLinearResult memory result;
         
        DataTypes.LockInfo storage lock = investor ? param.data.investorsLock : param.data.teamLock;
        if (lock.releaseType != DataTypes.VestingReleaseType.ByLinearContinuous ||
            lock.durations.length == 0 ||
            lock.durations[0] == 0 ||
            block.timestamp < param.data.desiredUnlockTime) {
            return result;
        }
        
        result.newStartTime = block.timestamp;
        result.endTime = param.data.desiredUnlockTime + lock.durations[0];
        
        DataTypes.ClaimInfo storage item = investor ? param.claims.investors[user] : param.claims.team[user];
        uint timeElapsed = block.timestamp - param.data.desiredUnlockTime;
        uint totalClaimPointer = Math.min(Constant.PCNT_100, (Constant.PCNT_100 * timeElapsed) / lock.durations[0]); // 1E6 means 100%
        result.claimedSoFar = item.amount;
        result.claimable = totalClaimPointer - item.amount; // 1E6 means 100% //
        result.lockedAmount = Constant.PCNT_100 - totalClaimPointer;
        
        return result;
    }


    // uint claimedSoFar;   // 1E6 means 100%
    // uint claimable;      // 1E6 means 100%
    // uint nextLockedAmount;// 1E6 means 100%
    // uint claimStartIndex;
    // uint numClaimableSlots;
    // uint nextUnlockIndex;
    // uint nextUnlockTime;
    function getClaimableByIntervals(DataTypes.Vesting storage param, address user, bool investor) public view returns (DataTypes.ClaimIntervalResult memory) {
        DataTypes.ClaimIntervalResult memory result;
        
        DataTypes.LockInfo storage lock = investor ? param.data.investorsLock : param.data.teamLock;
        if (lock.releaseType != DataTypes.VestingReleaseType.ByIntervals ||
            block.timestamp < param.data.desiredUnlockTime ||
            lock.durations.length == 0) {
            return result;
        }
         
        DataTypes.ClaimInfo storage item = investor ? param.claims.investors[user] : param.claims.team[user];
        
        result.claimedSoFar = item.amount;
        uint startIndex = firstFalseIndex(item.claimed);
        result.claimStartIndex = startIndex;
        
        // Find the claimable info
        uint len = lock.durations.length;
        uint lockedSlotIndex = len; // default at the end+1 of the array //
        for (uint n=startIndex; n< len; n++) {
            if (block.timestamp >= (param.data.desiredUnlockTime + lock.durations[n])) {
                result.claimable += lock.pcnts[n];
                result.numClaimableSlots++;
            } else {
                lockedSlotIndex = n;
                break;
            }
        }
        
        if ( lockedSlotIndex < len) {
            result.nextLockedAmount = lock.pcnts[lockedSlotIndex];
            result.nextUnlockIndex = lockedSlotIndex;
            result.nextUnlockTime = param.data.desiredUnlockTime + lock.durations[lockedSlotIndex];
        }
        return result;
    }

    function scaleBy(DataTypes.ClaimIntervalResult memory param, uint amount) external pure returns (DataTypes.ClaimIntervalResult memory) {
        param.claimedSoFar = (param.claimedSoFar*amount)/Constant.PCNT_100;
        param.claimable = (param.claimable*amount)/Constant.PCNT_100;
        param.nextLockedAmount = (param.nextLockedAmount*amount)/Constant.PCNT_100;
        return param;
    }

    function scaleBy(DataTypes.ClaimLinearResult memory param, uint amount) external pure returns (DataTypes.ClaimLinearResult memory) {
        param.claimedSoFar = (param.claimedSoFar*amount)/Constant.PCNT_100;
        param.claimable = (param.claimable*amount)/Constant.PCNT_100;
        param.lockedAmount = (param.lockedAmount*amount)/Constant.PCNT_100;
        return param;
    }
    
    function updateClaim(DataTypes.Vesting storage param, address user, bool investor) external returns (uint) {
        bool ok;
        uint releasePcnt;
        DataTypes.LockInfo storage lock = investor ? param.data.investorsLock : param.data.teamLock;
        DataTypes.ClaimInfo storage item = investor ? param.claims.investors[user] : param.claims.team[user];
         
        if (lock.releaseType == DataTypes.VestingReleaseType.ByLinearContinuous) {
            if (lock.durations[0] > 0) {
              
                DataTypes.ClaimLinearResult memory result = getClaimableByLinear(param, user, investor);
                releasePcnt = result.claimable;
                ok = true;
            }
        } else {
            
            DataTypes.ClaimIntervalResult memory result = getClaimableByIntervals(param, user, investor);
            // Check to make sure the specified claim index is same as underlying data
            if (result.numClaimableSlots > 0) {
                uint from = result.claimStartIndex;
                uint to = result.claimStartIndex + result.numClaimableSlots - 1;
                // Check whether claimed before ?
                _require(from == item.claimed.length, Error.Code.AlreadyClaimed);
                    
                for (uint n=from; n<=to; n++) {
                    item.claimed.push(true);
                }
                releasePcnt = result.claimable;
                ok = true;
            }
        }
        item.amount += releasePcnt;
        _require(ok, Error.Code.ClaimFailed);
        return (releasePcnt);
    }
    
    
    function hasTeamVesting(DataTypes.Vesting storage param) external view returns (bool) {
        return (param.data.teamLock.pcnts.length > 0);
    }
    
    function firstFalseIndex(bool[] storage values) private view returns (uint) {
        uint len = values.length;
        for (uint n=0; n<len; n++) {
            if(values[n] == false) {
                return n;
            }
        }
        return len;
    }
    
    function _require(bool condition, Error.Code err) pure private {
        require(condition, Error.str(err));
    }
}

