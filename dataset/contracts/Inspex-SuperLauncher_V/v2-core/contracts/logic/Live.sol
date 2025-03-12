// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../lib/DataTypes.sol";
import "../lib/Error.sol";

library Live {
    
    // Note: At least 1 tier (min, max) is required
    function setupWhiteListFcfs(
        DataTypes.Live storage param,
        uint duration,
        uint[] calldata minAmt,
        uint[] calldata maxAmt) external {
        
        _require(minAmt.length > 0 && minAmt.length == maxAmt.length, Error.Code.InvalidArray);
    
        // Remove existing tiers if exists //
        uint len = param.data.tiers.length;
        for (uint n=0; n<len; n++) {
            param.data.tiers.pop();
        }
        
        param.data.whitelistFcfsDuration = duration;
        
        len = minAmt.length;
        for (uint n=0; n<len; n++) {
            param.data.tiers.push(DataTypes.Tier(minAmt[n], maxAmt[n]));
        }
    }
    
     // Note: If a user appears in multiple whitelist tier, we will only take the first tier found
    function isWhitelisted(DataTypes.Live storage param, address user) public view returns (bool, uint) {
        uint len = param.data.tiers.length;
        for (uint n=0; n<len; n++) {
            if ( param.whitelistMap[n][user] == true ) {
                return (true, n);
            }
        }
        return (false,0);
    }
    
    // bool : whitelisted
    // uint : tier
    // uint : min buy limit
    // uint : max buy limit
    function getUserWhitelistInfo(DataTypes.Live storage param, address user) public view returns (bool, uint, uint, uint) {
        (bool whitelisted, uint tierNum) =  isWhitelisted(param, user);
        if (whitelisted) {
            DataTypes.Tier memory tier = param.data.tiers[tierNum];
            return (true, tierNum, tier.minBuyAmount, tier.maxBuyAmount);
        }
        return (false,0,0,0);
    }
    
    function addRemoveWhitelistFcfs(DataTypes.Live storage param, address[] calldata addresses, uint tier, bool add) external {
        uint len = addresses.length;
        _require(len>0 && tier<param.data.tiers.length, Error.Code.ValidationError);
        
        for (uint n=0; n<len; n++) {
            param.whitelistMap[tier][addresses[n]] = add;
        }
    }
    
    function getAllocLeftForLive(DataTypes.Live storage param) public view returns (uint) {
        if (param.allocSoldInLiveSoFar > 0) {
            return param.allocLeftAtOpen - param.allocSoldInLiveSoFar;
        }
        return param.allocLeftAtOpen;
    }
    
    // Returns the fundAmt
    function buyTokens(DataTypes.Store storage store, uint fund, bool isWhitelistPeriod) external {
        bool whitelisted;
        uint minLimit;
        uint maxLimit;
        uint bought;

        DataTypes.Live storage live = store.live;
        DataTypes.Data storage data = store.data;
        
        if (isWhitelistPeriod) {
            ( whitelisted, , minLimit, maxLimit) = getUserWhitelistInfo(live, msg.sender);
            _require(whitelisted, Error.Code.NotWhitelisted);
            bought = live.whitelistPurchases[msg.sender];
        } else {
            (minLimit, maxLimit) = (data.minBuyLimitPublic, data.maxBuyLimitPublic);
            bought = live.publicPurchases[msg.sender];
        }
        
        // If the amount of tokens left for sales is less than minLimit, it is ok to buy
        if (getAllocLeftForLive(live) > minLimit) {
            _require(fund >= minLimit, Error.Code.ValidationError);
        }
        _require(fund <= maxLimit, Error.Code.ValidationError);
    
        if (data.currency == address(0)) {
            _require(fund==msg.value, Error.Code.WrongValue);
        }
        
        // Are we able to buy or exceeded limit ?
        // User can buy in WL round and then public round 
        uint finalAmount =  bought + fund;
        _require(finalAmount <= maxLimit, Error.Code.ValueExceeded);
        
        // Proceed to buy 
        if (isWhitelistPeriod) {
            live.whitelistPurchases[msg.sender] = finalAmount;
        } else {
            live.publicPurchases[msg.sender] = finalAmount;
        }

        live.allocSoldInLiveSoFar += fund;
    }
    
    function _require(bool condition, Error.Code err) pure private {
        require(condition, Error.str(err));
    }
}



