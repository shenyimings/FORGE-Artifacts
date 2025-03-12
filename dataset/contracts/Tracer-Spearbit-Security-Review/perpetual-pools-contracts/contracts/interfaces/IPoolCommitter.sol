//SPDX-License-Identifier: CC-BY-NC-ND-4.0
pragma solidity 0.8.7;

/// @title The interface for the contract that handles pool commitments
interface IPoolCommitter {
    /// Type of commit
    enum CommitType {
        ShortMint, // Mint short tokens
        ShortBurn, // Burn short tokens
        LongMint, // Mint long tokens
        LongBurn, // Burn long tokens
        LongBurnShortMint, // Burn Long tokens, then instantly mint in same upkeep
        ShortBurnLongMint // Burn Short tokens, then instantly mint in same upkeep
    }

    // Pool balances and supplies
    struct BalancesAndSupplies {
        uint256 shortBalance;
        uint256 longBalance;
        uint256 longTotalSupplyBefore;
        uint256 shortTotalSupplyBefore;
    }

    // User aggregate balance
    struct Balance {
        uint256 longTokens;
        uint256 shortTokens;
        uint256 settlementTokens;
    }

    // Token Prices
    struct Prices {
        bytes16 longPrice;
        bytes16 shortPrice;
    }

    // Commit information
    struct Commit {
        uint256 amount;
        CommitType commitType;
        uint40 created;
        address owner;
    }

    // Commit information
    struct TotalCommitment {
        uint256 longMintAmount;
        uint256 longBurnAmount;
        uint256 shortMintAmount;
        uint256 shortBurnAmount;
        uint256 shortBurnLongMintAmount;
        uint256 longBurnShortMintAmount;
        uint256 updateIntervalId;
    }

    // User updated aggregate balance
    struct BalanceUpdate {
        uint256 _updateIntervalId;
        uint256 _newLongTokensSum;
        uint256 _newShortTokensSum;
        uint256 _newSettlementTokensSum;
        uint256 _balanceLongBurnAmount;
        uint256 _balanceShortBurnAmount;
        uint256 _longBurnFee;
        uint256 _shortBurnFee;
    }

    // Track how much of a user's commitments are being done from their aggregate balance
    struct UserCommitment {
        uint256 longMintAmount;
        uint256 longBurnAmount;
        uint256 balanceLongBurnAmount;
        uint256 shortMintAmount;
        uint256 shortBurnAmount;
        uint256 balanceShortBurnAmount;
        uint256 shortBurnLongMintAmount;
        uint256 balanceShortBurnMintAmount;
        uint256 longBurnShortMintAmount;
        uint256 balanceLongBurnMintAmount;
        uint256 updateIntervalId;
    }

    /**
     * @notice Creates a notification when a commit is created
     * @param user The user making the commitment
     * @param amount Amount of the commit
     * @param commitType Type of the commit (Short v Long, Mint v Burn)
     * @param appropriateUpdateIntervalId Id of update interval where this commit can be executed as part of upkeep
     * @param fromAggregateBalance whether or not to commit from aggregate (unclaimed) balance
     * @param payForClaim whether or not to request this commit be claimed automatically
     * @param mintingFee Minting fee at time of commit creation
     */
    event CreateCommit(
        address indexed user,
        uint256 indexed amount,
        CommitType indexed commitType,
        uint256 appropriateUpdateIntervalId,
        bool fromAggregateBalance,
        bool payForClaim,
        bytes16 mintingFee
    );

    /**
     * @notice Creates a notification when a user's aggregate balance is updated
     */
    event AggregateBalanceUpdated(address indexed user);

    /**
     * @notice Creates a notification when commits for a given update interval are executed
     * @param updateIntervalId Unique identifier for the relevant update interval
     * @param burningFee Burning fee at the time of commit execution
     */
    event ExecutedCommitsForInterval(uint256 indexed updateIntervalId, bytes16 burningFee);

    /**
     * @notice Creates a notification when a claim is made, depositing pool tokens in user's wallet
     */
    event Claim(address indexed user);

    /**
     * @notice Indicates that both the quote and pool addresses have been modified
     * @param quote Address of new quote token
     * @param pool Address of new `LeveragedPool`
     */
    event QuoteAndPoolChanged(address indexed quote, address indexed pool);

    /*
     * @notice Creates a notification when the burningFee is updated
     */
    event BurningFeeSet(uint256 indexed _burningFee);

    /**
     * @notice Creates a notification when the mintingFee is updated
     */
    event MintingFeeSet(uint256 indexed _mintingFee);

    /**
     * @notice Creates a notification when the changeInterval is updated
     */
    event ChangeIntervalSet(uint256 indexed _changeInterval);

    /**
     * @notice Creates a notification when the feeController is updated
     */
    event FeeControllerSet(address indexed _feeController);

    // #### Functions

    function initialize(
        address _factory,
        address _invariantCheckContract,
        address _autoClaim,
        address _factoryOwner,
        address _feeController,
        uint256 mintingFee,
        uint256 burningFee,
        uint256 _changeInterval
    ) external;

    function commit(
        CommitType commitType,
        uint256 amount,
        bool fromAggregateBalance,
        bool payForClaim
    ) external payable;

    function updateIntervalId() external view returns (uint128);

    function totalPendingMints() external view returns (uint256);

    function totalPendingShortBurns() external view returns (uint256);

    function totalPendingLongBurns() external view returns (uint256);

    function claim(address user) external;

    function executeCommitments() external;

    function updateAggregateBalance(address user) external;

    function getAggregateBalance(address user) external view returns (Balance memory _balance);

    function getAppropriateUpdateIntervalId() external view returns (uint128);

    function setQuoteAndPool(address _quoteToken, address _leveragedPool) external;

    function setBurningFee(uint256 _burningFee) external;

    function setMintingFee(uint256 _mintingFee) external;

    function setChangeInterval(uint256 _changeInterval) external;

    function setFeeController(address _feeController) external;
}
