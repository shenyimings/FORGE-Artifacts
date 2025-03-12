// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../lib/DataTypes.sol";
import "../lib/Constant.sol";
import "../lib/Error.sol";
import "../logic/Generic.sol";

contract DataStore {
        
    using Generic for *;
        
    DataTypes.Store private _dataStore;
    
    //--------------------//
    // EXTERNAL FUNCTIONS //
    //--------------------//

    function getCampaignInfo() external view returns (
        DataTypes.Data memory, 
        DataTypes.OverSubData memory,
        uint, // lotteryAmount
        uint, //whitelistFcfsDuration
        uint //desiredUnlockTime
        ){
            return (_dataStore.data, 
                _dataStore.overSubscription.data,
                _dataStore.lottery.data.eachAllocationAmount,
                _dataStore.live.data.whitelistFcfsDuration,
                _dataStore.vesting.data.desiredUnlockTime);
    }

    function getVestingInfo(bool investor) external view returns (uint count, DataTypes.VestingReleaseType releaseType) {
        count = investor ? _dataStore.vesting.data.investorsLock.pcnts.length  : _dataStore.vesting.data.teamLock.pcnts.length;
        releaseType = investor ? _dataStore.vesting.data.investorsLock.releaseType  : _dataStore.vesting.data.teamLock.releaseType;
    }
        
    function getVestingData(bool investor, uint index) external view returns (uint, uint) {
        if (investor) {
            return (_dataStore.vesting.data.investorsLock.pcnts[index], _dataStore.vesting.data.investorsLock.durations[index]);
        } else {
            return (_dataStore.vesting.data.teamLock.pcnts[index], _dataStore.vesting.data.teamLock.durations[index]);
        } 
    }
    
    function getWhitelistTiersInfo() external view returns (uint, uint) {
        return (_live().data.whitelistFcfsDuration, _live().data.tiers.length);
    }
    
    function getWhitelistTiersData(uint index) external view returns (uint, uint) {
        return (_live().data.tiers[index].minBuyAmount, _live().data.tiers[index].maxBuyAmount);
    }
    
    function getLpInfo() external view returns ( DataTypes.LpSize, uint, uint, uint, uint, uint, bool, bool,  uint) {
        return (_dataStore.lp.data.size, 
            _dataStore.lp.data.sizeParam, 
            _dataStore.lp.data.rate, 
            _dataStore.lp.data.splits.length,
            _dataStore.lp.locks.startTime,
            _dataStore.lp.locks.pcnts.length,
            _dataStore.lp.swap.needSwap,
            _dataStore.lp.swap.swapped,
            _dataStore.lp.swap.newCurrencyAmount);
    }
    
    function getLpRouterSplits(uint index) external view returns (address, address, uint) {
        return (_dataStore.lp.data.routers[index], _dataStore.lp.data.factory[index], _dataStore.lp.data.splits[index]);
    }
        
    function getLpLock(uint index) external view returns (uint, uint) {
        return (_dataStore.lp.locks.pcnts[index], _dataStore.lp.locks.durations[index]);
    }

    
    //--------------------//
    // PUBLIC FUNCTIONS   //
    //--------------------//
    function getFundInTokenRequired() public view virtual returns(uint) {
        return _dataStore.data.tokenSalesQty;
    }
    
    function getAllocLeftForLive() public view returns (uint) {
        return _hasOpened() ? _dataStore.live.allocLeftAtOpen - _dataStore.live.allocSoldInLiveSoFar : 0;
    }
    
    function getState(DataTypes.Ok stat) public view returns (bool) {
        return (_dataStore.state & (1 << uint8(stat))) > 0;
    }
    
    function getFinalState() external view returns (DataTypes.FinalState) {
        return _dataStore.finalState;
    }
    
    function getTokensForCapital(uint capital) public view returns (uint) {
        return (_dataStore.data.tokensPerCapital * capital)/Constant.VALUE_E18;
    }
    
    // Get the current total sales in raised currency 
    function getTotalAllocSold() public view returns (uint) {
        return _hasOpened() ? _dataStore.data.hardCap - getAllocLeftForLive() : 0;
    }
    
    function getCurrentPeriod() public view returns (DataTypes.Period) {
        if (!getState(DataTypes.Ok.BasicSetup)) {
            return DataTypes.Period.None;
        }
        // IDO Ended ?
        if (block.timestamp >= _dataStore.data.idoEnd) {
            return DataTypes.Period.IdoEnded;
        }
        // IDO Period ?
        if (block.timestamp >= _dataStore.data.idoStart && block.timestamp < _dataStore.data.idoEnd) {
            uint duration = _dataStore.live.data.whitelistFcfsDuration;
            if (duration > 0) {
                if (block.timestamp <= (_dataStore.data.idoStart + duration)) {
                    return DataTypes.Period.IdoWhitelisted;
                }
            }
            return DataTypes.Period.IdoPublic;
        }
        // Subscriptio Period ?
        if (block.timestamp >= _dataStore.data.subStart && block.timestamp < _dataStore.data.subEnd) {
            return DataTypes.Period.Subscription;
        }
        return DataTypes.Period.Setup;
    }
    
    
    //--------------------//
    // INTERNAL FUNCTIONS //
    //--------------------//
    function _store() internal view returns (DataTypes.Store storage) {
        return _dataStore;
    }
    
    function _data() internal view returns (DataTypes.Data storage) {
        return _dataStore.data;
    }
    
    function _subscriptions() internal view returns (DataTypes.Subscriptions storage) {
        return _dataStore.subscriptions;
    }
 
    function _guaranteed() internal view returns (DataTypes.Guaranteed storage) {
        return _dataStore.guaranteed;
    }
    
    function _lottery() internal view returns (DataTypes.Lottery storage) {
        return _dataStore.lottery;
    }
 
    function _overSubscriptions() internal view returns (DataTypes.OverSubscriptions storage) {
        return _dataStore.overSubscription;
    }
    
    function _live() internal view returns (DataTypes.Live storage) {
        return _dataStore.live;
    }
    
    function _vesting() internal view returns (DataTypes.Vesting storage) {
        return _dataStore.vesting;
    }
    
    function _lp() internal view returns (DataTypes.Lp storage) {
        return _dataStore.lp;
    }
    
    function _history() internal view returns (DataTypes.History storage) {
        return _dataStore.history;
    }
    
    function _setState(DataTypes.Ok stat, bool on) internal {
        if (on) {
            _dataStore.state |= (1 << uint8(stat));
        } else {
            _dataStore.state &= ~(1 << uint8(stat));
        }
    }
    
    function _setConfigApproved(bool approved) internal {
        _setState(DataTypes.Ok.Config, approved);
    }

    function _isBnbCurrency() internal view returns (bool) {
        return _dataStore.data.currency == address(0);
    }
  
    function _canInitialize() internal view returns (bool) {
        return (!getState(DataTypes.Ok.Finalized) && _isPeriod(DataTypes.Period.None));
    }
    
    function _canConfigure() internal view returns (bool) {
        return (getState(DataTypes.Ok.BasicSetup) && !getState(DataTypes.Ok.Finalized) && _isPeriod(DataTypes.Period.Setup));
    }
    
    function _canTally() internal view returns (bool) {
        return (getState(DataTypes.Ok.Finalized) && !getState(DataTypes.Ok.Tally) && _isPeriod(DataTypes.Period.Setup));
    }
    
    function _isAborted() internal view returns (bool) {
        return _dataStore.finalState == DataTypes.FinalState.Aborted;
    }

    function _isLivePeriod() internal view returns (bool) {
        return (getState(DataTypes.Ok.Tally) && block.timestamp >= _dataStore.data.idoStart && block.timestamp < _dataStore.data.idoEnd);
    }
    
    function _isPeriod(DataTypes.Period period) internal view returns (bool) {
        return (period == getCurrentPeriod());
    }
    
    function _hasOpened() internal view returns (bool) {
        return (getState(DataTypes.Ok.Tally) && block.timestamp >= _dataStore.data.idoStart);
    }
    
    function _raisedAmount(bool deductFee) internal view returns (uint) {
        uint raised = _hasOpened() ? _dataStore.data.hardCap - getAllocLeftForLive() : 0;
        
        if (deductFee && _dataStore.data.feePcnt > 0) {
            raised = (raised * (Constant.PCNT_100 - _dataStore.data.feePcnt))/Constant.PCNT_100;
        }
        return raised;
    }
    
    function _getFeeAmount(uint totalAmount) internal view returns (uint) {
        return (totalAmount * _dataStore.data.feePcnt) / Constant.PCNT_100;
    }
    
    
    // Used to optimise bytecode size
    function _require(bool condition, Error.Code err) pure internal {
        require(condition, Error.str(err));
    }
}