// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "../lib/DataTypes.sol";
import "../lib/Constant.sol";
import "../lib/Error.sol";


library Guaranteed {
    
    function subscribe(DataTypes.Guaranteed storage param, uint amount, uint maxAlloc) internal {
        _require(param.subscribedAmount[msg.sender] == 0, Error.Code.AlreadySubscribed); // User can only subscribe once only //
        _require(amount <= maxAlloc, Error.Code.ValueExceeded);
        
        param.subscribedAmount[msg.sender] = amount; 
        param.totalSubscribed += amount;
    }

    // uint : the guaranteed amount if guaranteed is true. Or else the amount will be the minFloorAmount. Unit in currency.
    // bool : Guaranteed.
    function getGuaranteedAmt(DataTypes.Store storage param, address user) view internal returns (uint, bool) {
        DataTypes.Guaranteed storage gtd = param.guaranteed;
        DataTypes.Lottery storage lottery = param.lottery;
        
        // Get svLaunch balance of user
        uint sv = ERC20Snapshot(param.data.svLaunchAddress).balanceOfAt(user, param.data.snapShotId);

        if (gtd.svLaunchSupplyAtSnapShot == 0 || sv < Constant.VALUE_100) {
            return (0, false);
        }
        
        if (sv > Constant.VALUE_10K) {
            sv = Constant.VALUE_10K;
        }
            
        // If the guaranteed amt is less than the _minGuaranteedFloorAmt, then it is not guaranteed.
        uint alloc = (sv * param.data.hardCap) / gtd.svLaunchSupplyAtSnapShot;
       
        bool guaranteed;
        if (alloc >= lottery.data.eachAllocationAmount) {
            guaranteed = true;
        } else {
            alloc = lottery.data.eachAllocationAmount; // This is the min allocation, But no guarantee.
        }
  
        return (alloc, guaranteed);
    }
    
    // uint : amount subscribed
    // bool : guaranteed (true), or pending lottery (false)
    function getGuaranteedSubscription(DataTypes.Store storage param, address user) view internal returns (uint, bool) {
        (, bool guaranteed) = getGuaranteedAmt(param, user);
        return (param.guaranteed.subscribedAmount[user], guaranteed); 
    }
       
    function _require(bool condition, Error.Code err) pure internal {
        require(condition, Error.str(err));
    }
}

