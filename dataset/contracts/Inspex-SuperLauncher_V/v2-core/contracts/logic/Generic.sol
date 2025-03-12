// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../lib/DataTypes.sol";
import "../lib/Constant.sol";
import "../lib/Error.sol";
import "../logic/Guaranteed.sol";
import "../logic/Lottery.sol";
import "../logic/OverSubscribe.sol";


library Generic {

    using Guaranteed for DataTypes.Store;
    using Lottery for DataTypes.Lottery;
    using OverSubscribe for DataTypes.OverSubscriptions;
    
    function initialize(
        DataTypes.Store storage store,
        address token,
        uint[4] calldata dates, // subStart, subEnd, idoStart, idoEnd //
        uint[2] calldata caps, //softCap, hardCap
        uint tokenSalesQty,
        uint[4] calldata subInfo, // snapShotId, lotteryAmt, stdOverSubscribeAmt, eggBurnForOverSubscribe   
        uint[2] calldata buyLimitsPublic, // min, max
        address currency, 
        uint feePcnt,
        address svLaunchAddress, 
        address eggAddress
    ) external {
        _require(dates[0]<dates[1] && dates[2]<dates[3], Error.Code.ValidationError);
        _require(caps[0] > 0 && caps[1] > 0 && caps[0]<caps[1], Error.Code.ValidationError);
        _require(tokenSalesQty > 0, Error.Code.InvalidAmount);
        
        _require(buyLimitsPublic[0] > 0 && buyLimitsPublic[0] < buyLimitsPublic[1], Error.Code.ValidationError);
        _require(subInfo[0] > 0 && subInfo[1] > 0 && subInfo[2] > 0, Error.Code.ValidationError);
       
        // After this setup, the basic config is done.
        DataTypes.Data storage data = store.data;
        DataTypes.Guaranteed storage guaranteed = store.guaranteed;
        DataTypes.OverSubscriptions storage overSub = store.overSubscription;
         
        data.svLaunchAddress = svLaunchAddress;
        data.eggAddress = eggAddress;
        
        data.token = token;
        data.subStart = dates[0];
        data.subEnd = dates[1];
        data.idoStart = dates[2];
        data.idoEnd = dates[3];
        data.softCap = caps[0];
        data.hardCap = caps[1];
        data.tokenSalesQty = tokenSalesQty;
        data.minBuyLimitPublic = buyLimitsPublic[0];
        data.maxBuyLimitPublic = buyLimitsPublic[1];
        data.feePcnt = feePcnt;
        data.snapShotId = subInfo[0];
        
        // To support differnt dp (eg dp9), tokensPerCapital is multiplied by e18 to avoid truncational error.
        data.tokensPerCapital = (tokenSalesQty * Constant.VALUE_E18) / data.hardCap;
        
        // Setup Guaranteed     
        guaranteed.svLaunchSupplyAtSnapShot = ERC20Snapshot(store.data.svLaunchAddress).totalSupplyAt(data.snapShotId);
        
        // Setup Lottery
        store.lottery.data.eachAllocationAmount = subInfo[1];
        
        // Setup OverSubscribe 
        overSub.data.stdOverSubQty = subInfo[2];
        overSub.data.stdEggBurnQty = subInfo[3];
        
        // Currency
        store.data.currency = currency;
        
    }
    
    function getSubscriptionResult(DataTypes.Store storage store, address user) external view returns (DataTypes.SubscriptionResultParams memory) {
        DataTypes.SubscriptionResultParams memory p;
        p.resultAvailable = true;
            
        (p.guaranteedAmount, p.guaranteed) = store.getGuaranteedSubscription(user);
            
        bool participated;
        bool won;
        uint amountFund;
        uint amountEgg;
        (participated, won, amountFund) = store.lottery.isWinner(user);
        if (participated) {
            p.wonLottery = won;
            p.lotteryAmount = won ? amountFund : 0;
        }
            
        ( participated, won, amountFund, amountEgg, ) =  store.overSubscription.isWinner(user);
        if (participated) {
            p.wonOverSub = won;
            p.overSubAmount = won ? amountFund : 0;
            p.eggBurnAmount = won ? amountEgg : 0;
        }
        return p;
    }
    
    function getPurchaseDetail(DataTypes.Store storage store, address user, bool tallyOk, bool includeRefundable) external view returns (DataTypes.PurchaseDetail memory) {
        DataTypes.PurchaseDetail memory p;
        
        p.guaranteedAmount = store.guaranteed.subscribedAmount[user];
        p.lotteryAmount = store.lottery.items[user].exist ? store.lottery.data.eachAllocationAmount : 0;
        p.overSubscribeAmount = store.overSubscription.items[user].amount;
        p.liveWlFcfsAmount = store.live.whitelistPurchases[user];
        p.livePublicAmount = store.live.publicPurchases[user];
        p.hasReturnedFund =  store.returnFunds.amount[user] > 0;
        
        // If subscription tally completed, we exclude any refund amount in lottery & over-subscribe
        if (!includeRefundable && tallyOk) {
            
            bool participated;
            bool won;
            uint amt;

            (participated, won, amt) = store.lottery.isWinner(user);
            if (participated && !won) {
                p.lotteryAmount = 0;
            }

            (participated, won, amt, , ) = store.overSubscription.isWinner(user);
            if (participated && !won) {
                p.overSubscribeAmount = 0;
            }
        }
        p.total = (p.guaranteedAmount + p.lotteryAmount + p.overSubscribeAmount + p.liveWlFcfsAmount + p.livePublicAmount);
        return p;
    }
    
    
    function _require(bool condition, Error.Code err) pure private {
        require(condition, Error.str(err));
    }
}





