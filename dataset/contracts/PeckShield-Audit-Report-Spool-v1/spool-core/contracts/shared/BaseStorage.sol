// SPDX-License-Identifier: MIT

import "../interfaces/ISwapData.sol";

pragma solidity 0.8.11;

struct Strategy {
    uint128 totalShares;
    uint24 index; // denotes strategy completed index
    bool isRemoved; // denotes strategy completed index
    Pending pendingUser;
    Pending pendingUserNext; // used if strategies dohardwork hasn't been executed yet in the current index
    mapping(address => uint256) pendingRewards; // NOTE: Usually a temp variable when compounding
    uint128 pendingDepositReward; // NOTE: Usually a temp variable when compounding
    uint256 lpTokens; // amount of lp tokens the strategy holds, NOTE: not all strategies use it
    // ----- REALLOCATION VARIABLES -----
    bool isInDepositPhase;
    uint128 optimizedSharesWithdrawn; // NOTE: Used to store amount of optimized shares, so they can be substracted at the end. Only for temporary use, should be reset to 0 in same transaction
    uint128 pendingRedistributeDeposit; // NOTE: make sure to reset it to 0 after withdrawal
    uint128 pendingRedistributeOptimizedDeposit; // NOTE: make sure to reset it to 0 after withdrawal
    // ------------------------------------
    mapping(uint256 => TotalUnderlying) totalUnderlying; // total underlying amount at index
    mapping(uint256 => Batch) batches;
    mapping(uint256 => BatchReallocation) reallocationBatches;
    mapping(address => Vault) vaults;
    mapping(bytes32 => AdditionalStorage) additionalStorage; // future proof storage
    uint256 emergencyPending; // NOTE: make sure to reset it to 0 after withdrawal
}

struct Pending {
    uint128 deposit;
    uint128 sharesToWithdraw;
}

struct TotalUnderlying {
    uint128 amount;
    uint128 totalShares;
}

struct Batch {
    uint128 deposited;
    uint128 depositedRecieved;
    uint128 depositedSharesRecieved;
    uint128 withdrawnShares; 
    uint128 withdrawnRecieved;
}

struct BatchReallocation {
    uint128 depositedReallocation; //deposited amount recieved from reallocation
    uint128 depositedReallocationSharesRecieved; // recieved shares from reallocation
    uint128 withdrawnReallocationRecieved; // NOTE: used to know how much tokens was recieved for redistributing
    uint128 withdrawnReallocationShares; // amount of shares to withdraw for reallocation
}

// NOTE: vaultBatches could be refactored so we only have 2 structs current and next (see how Pending is working)
struct Vault {
    uint128 shares;
    uint128 withdrawnReallocationShares; // withdrawn amount as part of the reallocation
    mapping(uint256 => VaultBatch) vaultBatches; // index to action
}

struct VaultBatch {
    uint128 deposited; // vault index to deposited amount mapping
    uint128 withdrawnShares; // vault index to withdrawn user shares mapping
}

// used for reallocation calldata
struct VaultData {
    address vault;
    uint8 strategiesCount;
    uint256 strategiesBitwise;
    uint256 newProportions;
}

struct ReallocationWithdrawData {
    uint256[][] reallocationProportions;
    StratUnderlyingSlippage[] priceSlippages;
    RewardSlippages[] rewardSlippages;
    uint256[] stratIndexes;
    uint256[][] slippages;
}

struct ReallocationData {
    uint256[] stratIndexes;
    uint256[][] slippages;
}

// in case some adapters need extra storage
struct AdditionalStorage {
    uint256 value;
    address addressValue;
    uint96 value96;
}

struct StratUnderlyingSlippage {
    uint128 min;
    uint128 max;
}

struct RewardSlippages {
    bool doClaim;
    SwapData[] swapData;
}

struct PriceData {
    uint128 totalValue;
    uint128 totalShares;
}

struct ReallocationShares {
    uint128[] optimizedWithdraws;
    uint128[] optimizedShares;
    uint128[] totalSharesWithdrawn;
}

struct StrategiesShared {
    uint184 value;
    uint32 lastClaimBlock;
    uint32 lastUpdateBlock;
    uint8 stratsCount;
    mapping(uint256 => address) stratAddresses;
    mapping(bytes32 => uint256) bytesValues;
}

abstract contract BaseStorage {
    // Spool variables
    // ----- DHW VARIABLES -----
    bool public forceOneTxDoHardWork;
    uint24 public globalIndex;
    uint8 internal doHardWorksLeft;
    // ----- REALLOCATION VARIABLES -----
    // NOTE: Used for offchain execution to get the new reallocation table.
    bool internal logReallocationTable;

    uint8 public withdrawalDoHardWorksLeft;
    uint24 public reallocationIndex;
    bytes32 internal reallocationTableHash;
    // -----------------------------------

    mapping(address => bool) public isDoHardWorker;
    mapping(address => bool) public isAllocationProvider;

    mapping(bytes32 => StrategiesShared) internal strategiesShared;
    mapping(address => Strategy) public strategies;
    
    mapping(address => bool) internal _skippedDisable;
    mapping(address => bool) internal _awaitingEmergencyWithdraw;
}