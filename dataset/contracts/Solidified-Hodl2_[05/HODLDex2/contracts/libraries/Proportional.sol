pragma solidity 0.6.6;

// SPDX-License-Identifier: Unlicensed

import "@openzeppelin/contracts/math/SafeMath.sol";

interface ProportionalInterface {
    function circulatingSupply() external view returns(uint amount); 
}

library Proportional {
    
    using SafeMath for uint;
    
    uint constant PRECISION = 10 ** 18;
    
    struct System {
        uint birthday;
        uint periodicity;
        address source;
        bytes32 shareAsset;                 // The asset used to determine shares, e.g. use HODL shares to distribute Eth proportionally.
        mapping(bytes32 => Asset) asset;
    }
    
    struct Asset {
        Distribution[] distributions;
        mapping(address => User) users;
    }
    
    struct Distribution {
        uint denominator;                   // Usually the supply, used to calculate user shares, e.g. balance / circulating supply
        uint amount;                        // The distribution amount. Accumulates allocations. Does not decrement with claims. 
        uint period;                        // Timestamp when the accounting period was closed. 
    }
    
    struct User {
        UserBalance[] userBalances;
        uint processingDistributionIndex;   // The next distribution of *this asset* to process for the user.
        uint processingBalanceIndex;        // The *shareAsset* balance record to use to compute user shares for the next distribution.
    }
    
    struct UserBalance {
        uint balance;                       // Last observed user balance in an accounting period 
        uint controlled;                    // Additional funds controlled the the user, e.g. escrowed, time-locked, open sell orders 
        uint period;                        // The period observed
    }
    
    event IncreaseDistribution(address sender, bytes32 indexed assetId, uint period, uint amount);
    event DistributionClosed(address sender, bytes32 indexed assetId, uint distributionAmount, uint denominator, uint closedPeriod, uint newPeriod);
    event DistributionPaid(address indexed receiver, bytes32 indexed assetId, uint period, uint amount, uint balanceIndex, uint distributionIndex);
    event UserBalanceIncreased(address indexed sender, bytes32 indexed assetId, uint period, address user, uint toBalance, uint toControlled);
    event UserBalanceReduced(address indexed sender, bytes32 indexed assetId, uint period, address user, uint fromBalance, uint fromControlled);
    event UserFastForward(address indexed sender, bytes32 indexed assetId, uint balanceIndex);
 
    /*******************************************************************
     * Initialize before using the library
     *******************************************************************/   
    
    function init(System storage self, bytes32[] storage assetId, bytes32 shareAssetId, uint birthday, uint periodicity, address source) internal {
        Distribution memory d = Distribution({
            denominator: 0,
            amount: 0,
            period: 0
        });
        self.shareAsset = shareAssetId;
        self.birthday = birthday;
        self.periodicity = periodicity;
        self.source = source;
        for(uint i=0; i<assetId.length; i++) {
            Asset storage a = self.asset[assetId[i]];
            a.distributions.push(d); // initialize with an open distribution in row 0.
        }
    }
    
    /*******************************************************************
     * Adjust balances 
     *******************************************************************/ 
     
    function add(System storage self, bytes32 assetId, address user, uint toBalance, uint toControlled) internal {
        Asset storage a = self.asset[assetId];
        User storage u = a.users[user];
        (uint currentBalance, uint balancePeriod, uint controlled) = userLatestBalanceUpdate(self, assetId, user);
        uint balanceCount = u.userBalances.length;

        uint p = period(self);
        currentBalance = currentBalance.add(toBalance);
        controlled = controlled.add(toControlled);
        UserBalance memory b = UserBalance({
            balance: currentBalance,  
            period: p,
            controlled: controlled
        });
        
        emit UserBalanceIncreased(msg.sender, assetId, p, user, toBalance, toControlled);

        /**
          We can overwrite the current userBalance, if:
           - this is not the share asset used for calculating proportional shares of distributions
           - the last row is already tracking the current period. 
        */

        if(balanceCount > 0 && (assetId != self.shareAsset || balancePeriod == p)) {
            u.userBalances[balanceCount - 1] = b; // overwrite the last row;
            return;
        }

        /**
          A new user, not seen before, is not entitled to distributions that closed before the current period. 
          Therefore, we point to the last distribution if it is open, or beyond it to indicate that this user will 
          participate in the next future distribution, if any.
        */

        if(balanceCount == 0) {
            u.processingDistributionIndex = distributionCount(self, assetId) - 1; 
            if(a.distributions[u.processingDistributionIndex].period < p) {
                u.processingDistributionIndex++;
            }
        }

        /**
          There may be gaps in the distribution periods when no distribution was allocated. If the distribution pointer
          refers to a future, undefined distribution, then the balance to use is always the most recent known balance, 
          which is this update.
        */

        if(u.processingDistributionIndex == self.asset[assetId].distributions.length) {
            u.processingBalanceIndex = u.userBalances.length;
        }

        /**
          Appending a new userBalance preserves the user's closing balance in prior periods. 
        */

        u.userBalances.push(b); 
        return;

    }
    
    function sub(System storage self, bytes32 assetId, address user, uint fromBalance, uint fromControlled) internal {
        Asset storage a = self.asset[assetId];
        User storage u = a.users[user];
        uint balanceCount = u.userBalances.length;
        (uint currentBalance, uint balancePeriod, uint controlled) = userLatestBalanceUpdate(self, assetId, user); 
        
        uint p = period(self);
        currentBalance = currentBalance.sub(fromBalance, "Prop NSF");
        controlled = controlled.sub(fromControlled, "Prop nsf");
        UserBalance memory b = UserBalance({
            balance: currentBalance, 
            period: p,
            controlled: controlled
        });
        
        emit UserBalanceReduced(msg.sender, assetId, p, user, fromBalance, fromControlled);
        
        // re-use a userBalance row if possible
        if(balanceCount > 0 && (assetId != self.shareAsset || balancePeriod == p)) {
            u.userBalances[balanceCount - 1] = b; 
            return;
        }
        
        // if the distribution index points to a future distribution, then the balance index is the most recent balance
        if(u.processingDistributionIndex == self.asset[assetId].distributions.length) {
            u.processingBalanceIndex = u.userBalances.length;
        }

        // Append a new user balance row when we need to retain history or start a new user
        u.userBalances.push(b); // start a new row 
        return;
    }
    
    /*******************************************************************
     * Distribute 
     *******************************************************************/   
     
    function increaseDistribution(System storage self, bytes32 assetId, uint amount) internal {
        Asset storage a = self.asset[assetId];
        Distribution storage d = a.distributions[a.distributions.length - 1];
        if(d.period < period(self)) {
            _closeDistribution(self, assetId);
            d = a.distributions[a.distributions.length - 1];
        }
        if(amount> 0) {
            d.amount = d.amount.add(amount);
            emit IncreaseDistribution(msg.sender, assetId, period(self), amount);
        }
    }

    function _closeDistribution(System storage self, bytes32 assetId) private {
        Asset storage a = self.asset[assetId];
        Distribution storage d = a.distributions[a.distributions.length - 1];
        uint p = period(self);
        d.denominator = circulatingSupply(self);
        Distribution memory newDist = Distribution({
            denominator: 0,
            amount: 0,
            period: p
        });
        a.distributions.push(newDist); 
        emit DistributionClosed(msg.sender, assetId, d.amount, d.denominator, d.period, p);
    }    
    
    /*******************************************************************
     * Claim 
     *******************************************************************/   
     
    // look ahead in accounting history
    
    function peakNextUserBalancePeriod(User storage user, uint balanceIndex) private view returns(uint period) {
        if(balanceIndex + 1 < user.userBalances.length) {
            period = user.userBalances[balanceIndex + 1].period;
        } else {
            period = PRECISION; // never - this large number is a proxy for future, undefined
        }
    }
    
    function peakNextDistributionPeriod(System storage self, uint distributionIndex) private view returns(uint period) {
        Asset storage a = self.asset[self.shareAsset];
        if(distributionIndex + 1 < a.distributions.length) {
            period = a.distributions[distributionIndex + 1].period;
        } else {
            period = PRECISION - 1; // never - this large number is a proxy for future, undefined
        }
    }
    
    // move forward. Pointers are allowed to extend past the end by one row, meaning "next" period with activity.
    
    function nudgeUserBalanceIndex(System storage self, bytes32 assetId, address user, uint balanceIndex) private {
        if(balanceIndex < self.asset[self.shareAsset].users[user].userBalances.length) self.asset[assetId].users[user].processingBalanceIndex = balanceIndex + 1;
    }
    
    function nudgeUserDistributionIndex(System storage self, bytes32 assetId, address user, uint distributionIndex) private {
        if(distributionIndex < self.asset[self.shareAsset].distributions.length) self.asset[assetId].users[user].processingDistributionIndex = distributionIndex + 1;
    }

    function processNextUserDistribution(System storage self, bytes32 assetId, address user) internal returns(uint amount) {
        Asset storage a = self.asset[assetId];
        Asset storage s = self.asset[self.shareAsset];
        User storage ua = a.users[user];
        User storage us = s.users[user];
        
        /*
          Closing distributions on-the-fly 
          - enables all users to begin claiming their distributions
          - reduces the need for a manual "poke" to close a distribution when no allocations take place in the following period 
          - reduces gaps from periods when no allocation occured followed by an allocation 
          - reduces possible iteration over those gaps near 286.
        */

        poke(self, assetId);

        // begin processing next distribution
        uint balanceIndex;
        uint distributionIndex;
        bool closed;
        (amount, balanceIndex, distributionIndex, closed) = nextUserDistributionDetails(self, assetId, user); 
        if(!closed) return 0;
        
        Distribution storage d = a.distributions[distributionIndex];

        // transfer the amount from the distribution to the user
        emit DistributionPaid(msg.sender, assetId, d.period, amount, balanceIndex, distributionIndex);
        add(self, assetId, user, amount, 0);
        
        /****************************************************************
         * Adjust the index pointers to prepare for the next distribution 
         ****************************************************************/
         
        uint nextUserBalancePeriod = peakNextUserBalancePeriod(us, balanceIndex);
        uint nextDistributionPeriod = peakNextDistributionPeriod(self, distributionIndex);
        
        nudgeUserDistributionIndex(self, assetId, user, distributionIndex);
        
        // if the next distribution to process isn't open (nothing has been writen), 
        // then fast-forward to the lastest shareAsset balance
        if(ua.processingDistributionIndex == a.distributions.length) {
            ua.processingBalanceIndex = us.userBalances.length - 1;
            return amount;
        }
      
        /** 
         * Consider advancing to the next userBalance index/
         * A gap in distribution records is possible if no funds are distributed, no claims are processed and no one 
         * pokes the asset manually. Gaps are discouraged but this loop resolves them if/when they occur.
         ****/

        while(nextUserBalancePeriod <= nextDistributionPeriod) {
            nudgeUserBalanceIndex(self, assetId, user, balanceIndex);
            (amount, balanceIndex, distributionIndex, closed) = nextUserDistributionDetails(self, assetId, user);
            nextUserBalancePeriod = peakNextUserBalancePeriod(us, balanceIndex);
        }
    }
    
    /*******************************************************************
     * Force close a period to enable claims
     *******************************************************************/ 
    
    function poke(System storage self, bytes32 assetId) internal  {
        increaseDistribution(self, assetId, 0);
    }

    /********************************************************************
     * The user's historical shareBalance is used  to compute shares of a supply which is applied to an 
     * unclaimed distribution of the asset itself (assetId).  
     ********************************************************************/
    
    function nextUserDistributionDetails(System storage self, bytes32 assetId, address user) 
        internal 
        view
        returns(
            uint amount,
            uint balanceIndex,
            uint distributionIndex,
            bool closed)
    {
        
        Asset storage a = self.asset[assetId];
        Asset storage s = self.asset[self.shareAsset];
        User storage us = s.users[user]; 
        
        // shareAsset balance index, this asset distribution index
        balanceIndex = us.processingBalanceIndex;
        distributionIndex = us.processingDistributionIndex;

        // if the user distribution index points to an as-yet uninitialized period (future) then it is not payable
        if(a.distributions.length < distributionIndex + 1) return(0, balanceIndex, distributionIndex, false);
        
        // the distribution to work with (this asset) from the user's distribution index
        Distribution storage d = a.distributions[distributionIndex];
        // the demoninator for every asset snapshots the share asset supply when the distribution is closed
        uint supply = d.denominator;
        closed = supply != 0;
        
        // if the user has no balance history then there is no entitlement. If the distribution is open then it is not payable.
        if(us.userBalances.length < balanceIndex + 1 || !closed) return(0, balanceIndex, distributionIndex, closed);

        // the user balance to work with (share asset) from the user's balance index
        UserBalance storage ub = us.userBalances[balanceIndex];        
        
        // shares include both the unincumbered user balance and any controlled balances, e.g. open sell orders, escrow, etc.
        uint shares = ub.balance + ub.controlled;
        
        // distribution / suppler, e.g. amount per share 
        uint distroAmt = d.amount;
        uint globalRatio = (distroAmt * PRECISION) / supply;
        
        // the user receives the amount per unit * the units they have or control 
        amount = (shares * globalRatio) / PRECISION;
    }
    
    /*******************************************************************
     * Inspect Configuration
     *******************************************************************/    
    
    function configuration(System storage self) internal view returns(uint birthday, uint periodicity, address source, bytes32 shareAsset) {
        birthday = self.birthday;
        periodicity = self.periodicity;
        source = self.source;
        shareAsset = self.shareAsset;
    }

    /*******************************************************************
     * Inspect Periods 
     *******************************************************************/

    function period(System storage self) internal view returns(uint periodNumber) {
        uint age = now.sub(self.birthday, "P502");
        periodNumber = age / self.periodicity;
    }
    
    /*******************************************************************
     * Inspect User Balances 
     *******************************************************************/    

    function balanceOf(System storage self, bytes32 assetId, address user) internal view returns(uint balance) {
        Asset storage a = self.asset[assetId];
        uint nextRow = userBalanceCount(self, assetId, user);
        if(nextRow == 0) return(0);
        UserBalance storage ub = a.users[user].userBalances[nextRow - 1];
        return ub.balance;
    }
    
    function additionalControlled(System storage self, bytes32 assetId, address user) internal view returns(uint controlled) {
        Asset storage a = self.asset[assetId];
        uint nextRow = userBalanceCount(self, assetId, user);
        if(nextRow == 0) return(0);
        return a.users[user].userBalances[nextRow - 1].controlled;
    }
    
    // There are 0-1 userBalance records for each distribution period
    function userBalanceCount(System storage self, bytes32 assetId, address user) internal view returns(uint count) {
        Asset storage a = self.asset[assetId];
        return a.users[user].userBalances.length;
    }
    
    function userBalanceAtIndex(System storage self, bytes32 assetId, address user, uint index) internal view returns(uint balance, uint controlled, uint _period) {
        Asset storage a = self.asset[assetId];
        UserBalance storage ub = a.users[user].userBalances[index];
        return (ub.balance, ub.controlled, ub.period);
    }
    
    function userLatestBalanceUpdate(System storage self, bytes32 assetId, address user) internal view returns(uint balance, uint _period, uint controlled) {
        Asset storage a = self.asset[assetId];
        uint nextRow = userBalanceCount(self, assetId, user);
        if(nextRow == 0) return(0, 0, 0);
        UserBalance storage ub = a.users[user].userBalances[nextRow - 1];
        balance = ub.balance;
        _period = ub.period;
        controlled = ub.controlled;
    }
    
    /*******************************************************************
     * Inspect Distributions
     *******************************************************************/     

    function circulatingSupply(System storage self) internal view returns(uint supply) {
        supply = ProportionalInterface(self.source).circulatingSupply(); // Inspect the external source
    }
    
    function distributionCount(System storage self, bytes32 assetId) internal view returns(uint count) {
        count = self.asset[assetId].distributions.length;
    }
    
    function distributionAtIndex(System storage self, bytes32 assetId, uint index) internal view returns(uint denominator, uint amount, uint _period) {
        Asset storage a = self.asset[assetId];
        return (
            a.distributions[index].denominator,
            a.distributions[index].amount,
            a.distributions[index].period);
    }
}