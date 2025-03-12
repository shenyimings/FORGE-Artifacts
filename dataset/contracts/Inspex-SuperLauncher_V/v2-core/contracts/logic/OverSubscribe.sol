// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../lib/DataTypes.sol";
import "../lib/Constant.sol";
import "../lib/Error.sol";

library OverSubscribe {
    

    // Note: totalEgg is for checking
    function subscribe (DataTypes.OverSubscriptions storage param, uint amount, uint priority, uint totalEgg) external {
        _require(amount > 0 && 
            amount <= param.data.stdOverSubQty &&
            priority <= Constant.PRIORITY_MAX, Error.Code.ValidationError);
        
        // already subscribed ??
        DataTypes.OverSubItem memory item = param.items[msg.sender];
        _require(item.amount == 0, Error.Code.AlreadySubscribed);
        
        // Get total egg to burn //
        uint eggsRequired = getEggBurnQty(param, amount, priority);
        _require(eggsRequired==totalEgg, Error.Code.InvalidAmount);
        
        // Update Bucket system
        insertIntoBucket(param, msg.sender, priority, amount, totalEgg);
    }
    
    function getEggBurnQty(DataTypes.OverSubscriptions storage param, uint amount, uint priority) public view returns (uint) {
        return (param.data.stdEggBurnQty * amount * (Constant.PCNT_100 + (Constant.PCNT_10 * priority))) / (param.data.stdOverSubQty * Constant.PCNT_100);
    }

   function getTotal(DataTypes.OverSubscriptions storage param) external view returns (uint) {
        uint total;
        for (uint n=0; n<=Constant.PRIORITY_MAX; n++) {
            total += param.buckets[n].total;
        }
        return total;
    }

    function tally(DataTypes.OverSubscriptions storage param, uint allocAmt) external {
        param.allocatedAmount = allocAmt;
        // Use the priority buckets and FastLookup table to determine the last person that won the over-subscribe
    
        // If under-subscribed
        if (param.totalOverSubAmount <= param.allocatedAmount ) {
            param.result.winningBucket = 0;
            param.result.firstLoserIndex = param.buckets[0].users.length;
            param.result.leftOverAmount = param.allocatedAmount - param.totalOverSubAmount;
            param.result.burnableEggs = param.totalMaxBurnableEggs;
        } else {
            // Over-subscribed. We need to perform FCFS 
            (uint bucket, uint amtLeft, uint eggUsedSoFar) = traverseToLast(param);
            param.result.winningBucket = bucket;
            (param.result.firstLoserIndex, param.result.leftOverAmount, param.result.burnableEggs) = findFirstLoserIndex(param, bucket, amtLeft);
            param.result.burnableEggs += eggUsedSoFar;
        }
        param.result.tallyCompleted = true;
    }
    
    // bool : has subscribed 
    // uint : amount Over-subscribed
    // uint : priority
    // uint : eggBurn Qty
    function getSubscription(DataTypes.OverSubscriptions storage param, address user) external view returns (bool, uint, uint, uint) {
        
        DataTypes.OverSubItem memory item = param.items[user];
        bool hasSubscribed = (item.amount > 0);
        uint totalEggsBurn;
        
        if (hasSubscribed) {
            totalEggsBurn = getEggBurnQty(param, item.amount, item.priority );
        }
        return (hasSubscribed, item.amount, item.priority, totalEggsBurn);
    }
    
    // bool : participated ?
    // bool : won ? 
    // uint : amount (Os),  (regardless of whether user win or lose)
    // uint : amount (egg), (regardless of whether user win or lose)
    // uint : priority      (regardless of whether user win or lose)
    function isWinner(DataTypes.OverSubscriptions storage param, address user) public view returns (bool, bool, uint, uint, uint) {
        DataTypes.OverSubItem memory item = param.items[user];
        bool participated = (item.amount > 0);
        
        if (!participated || !param.result.tallyCompleted) {
            return (participated, false, 0, 0, 0);
        }
        
        // Is user in the required priority bucket ?
        bool won = (item.priority > param.result.winningBucket);
        if (item.priority == param.result.winningBucket) {
            won = (item.index < param.result.firstLoserIndex);
        }
        uint eggBurn = getEggBurnQty(param, item.amount, item.priority);
        
        return (participated, won, item.amount, eggBurn, item.priority);
    }
    
    // uint : currency refundable
    // uint : eggs refundable
    function getRefundable(DataTypes.OverSubscriptions storage param, address user) external view returns(uint, uint) {
        
        (bool participated, bool won, uint amtFund, uint amtEgg, ) = isWinner(param, user);
        
        if (!participated) {
            return (0,0);
        }
        // Refund if user participate in Oversubscribe but didn't gets allocated due to priority.
        return won ? (0, 0) : (amtFund, amtEgg);
    }
    
    function getBurnableEggs(DataTypes.OverSubscriptions storage param, address user) external view returns (uint) {
        (bool participated, bool won, , uint amtEgg, ) = isWinner(param, user);
        return (participated && won) ? amtEgg : 0;
    }
    
    function getFinalLeftOver(DataTypes.OverSubscriptions storage param) external view returns (uint) {
        return param.result.leftOverAmount;
    } 
    
    function getResult(DataTypes.OverSubscriptions storage param) external view returns (uint, uint, uint) {
        return (param.result.winningBucket, param.result.firstLoserIndex, param.result.leftOverAmount);
    }
    
    function getBurnableEggsAfterTally(DataTypes.OverSubscriptions storage param) external view returns (uint) {
        return param.result.tallyCompleted ? param.result.burnableEggs : 0;
    }
    
    // Helpers
    function insertIntoBucket(DataTypes.OverSubscriptions storage param, address user, uint priority, uint amount, uint totalEgg) private {
        DataTypes.Bucket storage bucket = param.buckets[priority];
        uint index = bucket.users.length;
        bucket.users.push(user);
        bucket.total += amount;
        bucket.totalEggs += totalEgg;
        
         // Update info
        DataTypes.OverSubItem storage item = param.items[user];
        item.amount = amount;
        item.priority = priority;
        item.index = index;
        item.cumulativeEggBurn = bucket.totalEggs; // save the current cummulative amount of egg Burn.
        
        param.totalOverSubAmount += amount;
        param.totalMaxBurnableEggs += totalEgg;
      
       // Update the Fast Lookup table
       // Example :
       // [0] : 0-9, 10-19, ...
       // [1] : 0-99, 100-199, ...
       // [2] : 0-999, 1000-1999, ...
       // ...
       index++;
       for (uint n=1; n<= DataTypes.LUT_SIZE; n++) {
           if (index % (10**n) == 0) {
               bucket.fastLookUp[n-1].push(bucket.total);
           } else {
               return;
           }
       }
    }
    
    // Note: this is only needed when the allocatedAmount is NOT enough to cover all over-subscriptions
    // uint : bucket
    // uint : amtLeft
    // uint : eggUsed
    function traverseToLast(DataTypes.OverSubscriptions storage param) private view returns (uint, uint, uint) {
        uint amtLeft = param.allocatedAmount; 
        uint totalInBucket;
        uint totalEggUsed;
    
        // Priority from 0 to 100. A total of 101 levels.
        // Careful for n-- underflow //
        for (uint n=Constant.PRIORITY_MAX+1; n>0; n--) {
              
            totalInBucket = param.buckets[n-1].total;
            
            if ( amtLeft < totalInBucket) {
                return (n-1, amtLeft, totalEggUsed);
            } else {
                amtLeft -= totalInBucket;
                totalEggUsed += param.buckets[n-1].totalEggs;
            }
        }
        return (0, amtLeft, totalEggUsed); // Should not happen, as we have checked for condition : param.totalOverSubAmt > param.allocatedAmt
    }
    
    struct FindParam {
        uint foundAt; 
        uint startAt;
        uint len; 
        uint value; 
        uint crossed; 
        uint amtAt; 
        uint jumpToIndex;
        uint userAmt;
        uint end;
    }
    // uint : firstLoserIndex, 
    // uint : leftOverAmount
    // uint : eggUsed
    function findFirstLoserIndex(DataTypes.OverSubscriptions storage param, uint index, uint leftOver) private view returns (uint, uint, uint) {
        // Edge condition: If nothing is left 
        if (leftOver == 0) {
            return (0,0,0);
        }
        
        // Proceed to find the FirstLoserIndex
        DataTypes.Bucket memory bucket = param.buckets[index];
        
        FindParam memory p;
        uint n;
        uint m;
       
        // Careful for n-- underflow //
        for (n = DataTypes.LUT_SIZE; n > 0; n--) {
            
            p.len = bucket.fastLookUp[n-1].length;
            p.crossed = 0;
            p.startAt = p.foundAt / (10**n);
            for (m=p.startAt; m<p.len; m++) {
                
                p.value = bucket.fastLookUp[n-1][m];
                if (p.value < leftOver) {
                  p.crossed = m+1;
                  p.amtAt = p.value;
                } else {
                    break;
                }
            }
            
            if (p.crossed > 0) {
                p.jumpToIndex = (10**n) * p.crossed;
                p.foundAt += p.jumpToIndex;
            }
       }
       
       // We are at the last LookupTable offset. We have found "foundAt" & "amtAt".
       // So we just need to find the firstLoserIndex by looping a max of 10 items 
       uint bucketLen = bucket.users.length;
       p.end = p.foundAt + 10;
       if (p.end > bucketLen) {
           p.end = bucketLen;
       }
       
       for (n = p.foundAt; n < p.end; n++) {
           
           p.userAmt = param.items[bucket.users[n]].amount;
           p.amtAt += p.userAmt;
           if (p.amtAt >= leftOver) {
               // We found it //
               
               if (p.amtAt==leftOver) {
                   return (n+1, 0, param.items[bucket.users[n]].cumulativeEggBurn);
               } else {
                   
                   uint cummulative;
                   if (n>0) {
                       cummulative = param.items[bucket.users[n-1]].cumulativeEggBurn;
                   }
                   return (n, leftOver + p.userAmt - p.amtAt, cummulative);
               }
           }
       }
       
       // This should not happen
      assert(false);
      return(0,0,0);
    }
    
    function _require(bool condition, Error.Code err) pure private {
        require(condition, Error.str(err));
    }
    
}

