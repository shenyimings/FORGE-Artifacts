// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/radiant/LockedBalance.sol";
import "./interfaces/radpieReader/IRDNTVestManagerReader.sol";


interface ReaderDatatype {

    struct RadpieInfo {
        address masterRadpie;
        address radpieStaking;
        address rdntRewardManager;
        address rdntVestManager;
        address vlRDP;
        address radpieOFT;
        address RDNT;
        address WETH;
        address RDNT_LP;  
        address mDLP;
        uint256 minHealthFactor;
        uint256 systemHealthFactor;
        RadpieRDNTInfo systemRDNTInfo;
        RadpieEsRDNTInfo esRDNTInfo;
        RadpiePool[] pools;
    }    

    struct RadpieRDNTInfo {
        uint256 lockedDLPUSD;
        uint256 requiredDLPUSD;
        uint256 totalCollateralUSD;
        uint256 nextStartVestTime;
        uint256 lastHarvestTime;
        uint256 totalEarnedRDNT;
        uint256 systemVestable;
        uint256 systemVested;
        uint256 systemVesting;
        uint256 totalRDNTpersec;
        EarnedBalance[] vestingInfos;

        uint256 userVestedRDNT;
        uint256 userVestingRDNT;
        VestingSchedule[] userVestingSchedules;
    }

    struct RadpieEsRDNTInfo {
        address tokenAddress;
        uint256 balance;
        uint256 vestAllowance;
    }
    
    // by pools
    struct RadpiePool {
        uint256 poolId;
        uint256 sizeOfPool;
        uint256 tvl;
        uint256 debt;
        uint256 leveragedTVL;
        address stakingToken; // Address of staking token contract to be staked.
        address receiptToken; // Address of receipt token contract represent a staking position
        address asset;
        address rToken;
        address vdToken;
        address rewarder;
        address helper;
        bool    isActive;
        bool    isNative;
        string  poolType;
        uint256 assetPrice;
        uint256 maxCap;
        uint256 quotaLeft;
        uint256 RDPEmission;
        RadpieLendingInfo radpieLendingInfo;
        ERC20TokenInfo stakedTokenInfo;
        RadpieAccountInfo  accountInfo;
        RadpieRewardInfo rewardInfo;
        RadpieLegacyRewardInfo legacyRewardInfo;
        VlRadpieLockInfo vlRadpieLockInfo;

    }

    struct RadpieAccountInfo {
        uint256 balance;
        uint256 stakedAmount;  // receipttoken
        uint256 stakingAllowance; // asset allowance
        uint256 availableAmount; // current stake amount
        uint256 mDLPAllowance;
        uint256 lockRDPAllowance;
        uint256 rdntBalance;
        uint256 rdntDlpBalance;
        uint256 tvl;
    }

    struct RadpieRewardInfo {
        uint256 pendingRDP;
        address[]  bonusTokenAddresses;
        string[]  bonusTokenSymbols;
        uint256[]  pendingBonusRewards;
        uint256 entitledRDNT;
    }

    struct RadpieLendingInfo {
        uint256 healthFactor;
        uint256 depositRate;
        uint256 borrowRate;
        uint256 RDNTDepositRate;
        uint256 RDNTDBorrowRate;
        uint256 depositAPR;
        uint256 borrowAPR;
        uint256 RDNTAPR;
        uint256 RDNTpersec;
    }        

    struct RadpieLegacyRewardInfo {
        uint256[]  pendingBonusRewards;
        address[]  bonusTokenAddresses;
        string[] bonusTokenSymbols;
    }

    struct ERC20TokenInfo {
        address tokenAddress;
        string symbol;
        uint256 decimals;
    }

    struct VlRadpieLockInfo {
        uint256 userTotalLocked;
        uint256 userAmountInCoolDown;
        VlRadpieUserUnlocking[] userUnlockingSchedule;
        uint256 totalPenalty;
        uint256 nextAvailableUnlockSlot;
        bool isFull;
    }

    struct VlRadpieUserUnlocking {
        uint256 startTime;
        uint256 endTime;
        uint256 amountInCoolDown; // total amount comitted to the unlock slot, never changes except when reseting slot
        uint256 expectedPenaltyAmount;
        uint256 amountToUser;
    } 
}