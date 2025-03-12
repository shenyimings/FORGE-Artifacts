// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./core/MainWorkflow.sol";
import "./interfaces/ICampaign.sol";

contract Campaign is ICampaign, MainWorkflow {

    using Generic for *;
    using Live for DataTypes.Live;
    using LpProvision for DataTypes.Lp;
    using Vesting for DataTypes.Vesting;
    using History for DataTypes.History;

    constructor(IManager manager, address campaignOwner) MainWorkflow(manager, campaignOwner) { }
    
    modifier init() {
        _require(_isConfigurator() && _canInitialize(), Error.Code.CannotInitialize);
        _;
        _setState(DataTypes.Ok.Config, false);
        _setState(DataTypes.Ok.BasicSetup, true);
    }
    
    modifier configure() {
        _require(_isConfigurator() && _canConfigure(), Error.Code.CannotConfigure);
        _;
        _setState(DataTypes.Ok.Config, false);
    }
    
    modifier onlyCampaignOwner() {
        _require(_campaignOwner == msg.sender, Error.Code.NoRights);
        _;
    }
     
    modifier onlyDeployer() {
        _require(_manager.getRoles().isDeployer(msg.sender), Error.Code.NoRights);
        _;
    }
    
    modifier campaignOwnerOrConfigurator() {
        _require(_campaignOwner == msg.sender || _isConfigurator(), Error.Code.NoRights);
        _;
    }
    
    
    //--------------------//
    // EXTERNAl FUNCTIONS //
    //--------------------//
    
    function initialize( 
        address token,
        uint[4] calldata dates, // subStart, subEnd, idoStart, idoEnd //
        uint[2] calldata caps, //softCap, hardCap
        uint tokenSalesQty,
        uint[4] calldata subInfo, // snapShotId, lotteryAmt, stdOverSubscribeAmt, eggBurnForOverSubscribe
        uint[2] calldata buyLimitsPublic, // the min and max buy limit for public round
        address currency,
        uint feePcnt
    ) external init {
        _store().initialize(token, dates, caps, tokenSalesQty, subInfo, buyLimitsPublic, currency, feePcnt, 
            _manager.getSvLaunchAddress(), _manager.getEggAddress());
    }
    
    function setupLp(
        DataTypes.LpSize size,
        uint sizeParam,
        uint rate, // in 1E18
        DataTypes.LpProvider[] calldata providers,
        uint[] calldata splits,
        uint[] calldata lockPcnts, 
        uint[] calldata lockDurations,
        bool swapToBnbBasedLp
    ) external configure {
        _lp().setup(size, sizeParam, rate, _data().softCap, _data().hardCap ,_data().token, _data().currency, swapToBnbBasedLp);
        _lp().setupLocks(providers, splits, lockPcnts, lockDurations, _getLpInterface());
    }
    
    function setupVestingPeriods(
        DataTypes.VestingReleaseType investorReleaseType,
        DataTypes.VestingReleaseType teamReleaseType,
        uint desiredUnlockTime,
        uint[] calldata investorLockPcnts,  // 1E6 is 100%
        uint[] calldata investorLockDurations,
        uint[] calldata teamLockPcnts,      // 1E6 is 100%
        uint[] calldata teamLockDurations
    ) external configure {
        _vesting().setup(investorReleaseType, teamReleaseType, desiredUnlockTime, investorLockPcnts, investorLockDurations, teamLockPcnts, teamLockDurations);
    }

    function setupWhitelistFcfs(uint duration, uint[] calldata minAmt, uint[] calldata maxAmt) external configure {
        _live().setupWhiteListFcfs(duration, minAmt, maxAmt);
    }

    function approveConfig() external {
        _require (_manager.getRoles().isApprover(msg.sender) && getState(DataTypes.Ok.BasicSetup), Error.Code.ValidationError);
        _setConfigApproved(true);
    }
    
    function finalize() external onlyDeployer notAborted {
        _require(getState(DataTypes.Ok.Config), Error.Code.UnApprovedConfig);
        _setState(DataTypes.Ok.Finalized, true);
    }
    
    function fundIn(uint amtAcknowledged) external onlyCampaignOwner {
        _fundIn(amtAcknowledged);
    }
    
    function fundOut(uint amtAcknowledged) external onlyCampaignOwner {
        _fundOut(amtAcknowledged);
    }
    
    function tallySubscriptionAuto() external onlyDeployer notAborted {
        (, uint a, uint b) = peekTally();
        uint ratio = (a==0 && b==0) ? Constant.PCNT_50 : (a * Constant.PCNT_100) / (a + b);
        _tallySubscription(ratio);
    }
    
    function tallySubscriptionManual(uint splitRatio) external onlyDeployer notAborted {
        _tallySubscription(splitRatio);
    }

    function addRemovePrivateWhitelist(address[] calldata addresses, uint tier, bool add) external campaignOwnerOrConfigurator {
        _live().addRemoveWhitelistFcfs(addresses, tier, add);
    }
   
    // To swap the amount used for LP to BNB with the purpose of creating a XYZ/BNB Pair LP token.
    function swapToWBnbBase(uint minAmountOut) external onlyDeployer {
        _lp().swapCurrencyToWBnb(getLpFund(), minAmountOut, _getLpInterface());
    }
    
    // Note: overrideStartVest: if set to true, will change the vesting's desiredUnlockTime to current time once LP is provided.
    function addAndLockLP(bool overrideStartVest, bool bypassSwap) public onlyDeployer {
        _require(getState(DataTypes.Ok.FinishedUp), Error.Code.CannotCreateLp);
        
        // Note: getLpFund() will return the raisedAmount after deducting for fee
        (uint tokenUnsed, uint fundUnused) = _lp().create(getLpFund(), bypassSwap);  
        _setState(DataTypes.Ok.LpCreated, true);
        
        if (overrideStartVest) {
            _vesting().setVestingTimeNow();
        }
        
        // In the event that after LP provision, there is some amount left, we need to return this amount to campaign owner
         _transferOut(_campaignOwner, tokenUnsed, DataTypes.FundType.Token);
        // return un-used fund in either WBNB (if swapped) or in currency
        _transferOut(_campaignOwner, fundUnused, _lp().swap.swapped ? DataTypes.FundType.WBnb : DataTypes.FundType.Currency);
    }
    
    function claimTokens() external  {
        _claim(true);
    }
    
    function claimFunds() external onlyCampaignOwner  {
        _claim(false);
    }
    
    function claimUnlockedLp(uint index) external onlyCampaignOwner notAborted {
        _require(getState(DataTypes.Ok.LpCreated), Error.Code.LpNotCreated);
        uint amt = _lp().claimUnlockedLp(index);
        _history().record(DataTypes.ActionType.ClaimLp, msg.sender, index, amt, false);
    }
    
    // Implements ICampaign
    function cancelCampaign() external override {
        // Can only cancel a campaign when finishUp() is not yet called.
        _require(msg.sender == address(_manager) && !getState(DataTypes.Ok.FinishedUp), Error.Code.ValidationError);
        
        // When a campaign is cancelled, the campaignOwner can take back his token & user can get back their fund using
        // RefundExcess() & returnFund()
        _store().finalState = DataTypes.FinalState.Aborted;
    }
    
    // Note: Only daoMultiSig address can perform emergenctWithdraw via the Manager contract.
    // The withdrawn fund will go directly into the dao MultiSig address only.
    function daoMultiSigEmergencyWithdraw(address tokenAddress, address to, uint amount) external override {
        _require(msg.sender == address(_manager), Error.Code.NoRights);
        _transferOut(to, tokenAddress, amount);
    }
    
    //--------------------//
    // PRIVATE FUNCTIONS //
    //--------------------//
    
    // Roles helper
    function _isConfigurator() private view returns (bool) {
        return _manager.getRoles().isConfigurator(msg.sender);
    }
    
}


