pragma solidity 0.6.6;

// SPDX-License-Identifier: Unlicensed

// This testing harness is not needed for production. 

import "./libraries/Proportional.sol";

contract ProportionalTest {
    
    using Proportional for Proportional.System;
    
    Proportional.System balance;
    bytes32[] assetIds;
    
    uint constant DISTRIBUTION_PERIOD = 30 days;
    uint CIRCULATING = 2000000000000000000000000; // 2 MILLION 
    
    bytes32 constant public ETH_ASSET = keccak256("Eth");
    bytes32 constant public HODL_ASSET = keccak256("HODL");
    
    constructor () public {
        assetIds.push(HODL_ASSET);
        assetIds.push(ETH_ASSET);
        balance.init(assetIds, HODL_ASSET, now, DISTRIBUTION_PERIOD, address(this));      
    }
    
    function add(bytes32 assetId, address user, uint toBalance, uint toControlled) public {
        balance.add(assetId, user, toBalance, toControlled);
    }
    
    function sub(bytes32 assetId, address user, uint fromBalance, uint fromControlled) public {
        balance.sub(assetId, user, fromBalance, fromControlled);
    }
    
    function increaseDistribution(bytes32 assetId, uint amount) public {
        balance.increaseDistribution(assetId, amount);
    }
    
    function processNextUserDistribution(bytes32 assetId, address user) public returns(uint amount) {
        amount = balance.processNextUserDistribution(assetId, user);
    }
    
    function poke(bytes32 assetId) public {
        balance.poke(assetId);
    }
    
    function nextUserDistributionDetails(bytes32 assetId, address user) 
        public 
        view
        returns(
            uint amount,
            uint balanceIndex,
            uint distributionIndex,
            bool closed)
    {
        return balance.nextUserDistributionDetails(assetId, user);
    }
    
    function configuration() public view returns(uint birthday, uint periodicity, address source, bytes32 shareAsset) {
        return balance.configuration();
    }
    
    function period() public view returns(uint periodNumber) {
        periodNumber = balance.period();
    }
    
    function balanceOf(bytes32 assetId, address user) public view returns(uint _balance) {
        _balance = balance.balanceOf(assetId, user);
    }    
    
    function additionalControlled(bytes32 assetId, address user) public view returns(uint controlled) {
        controlled = balance.additionalControlled(assetId, user);
    }

    function userBalanceCount(bytes32 assetId, address user) public view returns(uint count) {
        count = balance.userBalanceCount(assetId, user);
    }
    
    function userBalanceAtIndex(bytes32 assetId, address user, uint index) public view returns(uint _balance, uint controlled, uint _period) {
        return balance.userBalanceAtIndex(assetId, user, index);
    }
    
    function userLatestBalanceUpdate(bytes32 assetId, address user) public view returns(uint _balance, uint _period, uint controlled) {
        return balance.userLatestBalanceUpdate(assetId, user);
    }
    
    function circulatingSupply() public view returns(uint supply) {
        supply = CIRCULATING; // we do this to avoid a circulating dependency for this this test. 
    }
    
    function inspectCirculatingSupply() public view returns(uint supply) {
        supply = balance.circulatingSupply();
    }
    
    function distributionCount(bytes32 assetId) public view returns(uint count) {
        count = balance.distributionCount(assetId);
    }
    
    function distributionAtIndex(bytes32 assetId, uint index) public view returns(uint denominator, uint _balance, uint _period) {
        return balance.distributionAtIndex(assetId, index);
    }
}