// SPDX-License-Identifier: BUSL-1.1


pragma solidity ^0.8.0;


import "../lib/DataTypes.sol";

library History {
    
    function record(DataTypes.History storage param, DataTypes.ActionType actType, address user, uint data1, bool isInvestor) internal {
       record(param, actType, user, data1, 0, isInvestor);
    }
    
    function record(DataTypes.History storage param, DataTypes.ActionType actType, address user, uint data1, uint data2, bool isInvestor) internal {
        DataTypes.Action memory act = DataTypes.Action(uint128(actType), uint128(block.timestamp), data1, data2);
        if (isInvestor) {
            param.investor[user].push(act);
        } else {
            param.campaignOwner[user].push(act);
        }
    }
}


