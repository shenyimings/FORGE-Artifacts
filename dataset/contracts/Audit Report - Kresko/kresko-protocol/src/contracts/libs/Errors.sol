// SPDX-License-Identifier: BUSL-1.1
pragma solidity <0.9.0;

/* solhint-disable max-line-length */

/**
 * @author Kresko
 * @title Error codes
 * @notice Kresko-specific revert return values and their explanation
 * @dev First number indicates the domain for the error
 */
library Error {
    /* -------------------------------------------------------------------------- */
    /*                                    Diamond                                 */
    /* -------------------------------------------------------------------------- */

    // Preserve readability for the diamond proxy
    string public constant DIAMOND_INVALID_FUNCTION_SIGNATURE = "krDiamond: function does not exist";
    string public constant DIAMOND_INVALID_PENDING_OWNER = "krDiamond: Must be pending contract owner";
    string public constant DIAMOND_INVALID_OWNER = "krDiamond: Must be diamond owner";

    /* -------------------------------------------------------------------------- */
    /*                                   1. General                               */
    /* -------------------------------------------------------------------------- */

    string public constant NOT_OWNER = "100"; // The sender must be owner
    string public constant NOT_OPERATOR = "101"; // The sender must be operator
    string public constant ZERO_WITHDRAW = "102"; // Withdraw must be greater than 0
    string public constant ZERO_DEPOSIT = "103"; // Deposit must be greater than 0
    string public constant ZERO_ADDRESS = "104"; // Address provided cannot be address(0)
    string public constant ALREADY_INITIALIZED = "105"; // Contract has already been initialized
    string public constant RE_ENTRANCY = "106"; // Function does not allow re-entrant calls
    string public constant NOT_ENOUGH_BALANCE = "107"; // Transfer of rebasing token exceeds value
    string public constant NOT_ENOUGH_ALLOWANCE = "108"; // TransferFrom of rebasing token exceeds allowance

    /* -------------------------------------------------------------------------- */
    /*                                   2. Minter                                 */
    /* -------------------------------------------------------------------------- */

    string public constant NOT_LIQUIDATABLE = "200"; // Account has collateral deposits exceeding minCollateralValue
    string public constant ZERO_MINT = "201"; // Mint amount must be greater than 0
    string public constant ZERO_BURN = "202"; // Burn amount must be greater than 0
    string public constant ADDRESS_INVALID_ORACLE = "203"; // Oracle address cant be set to address(0)
    string public constant ADDRESS_INVALID_NRWT = "204"; // Underlying rebasing token address cant be set to address(0)
    string public constant ADDRESS_INVALID_FEERECIPIENT = "205"; // Fee recipient address cant be set to address(0)
    string public constant ADDRESS_INVALID_COLLATERAL = "206"; // Collateral address cant be set to address(0)
    string public constant COLLATERAL_EXISTS = "207"; // Collateral has already been added into the protocol
    string public constant COLLATERAL_INVALID_FACTOR = "208"; // cFactor must be greater than 1FP
    string public constant COLLATERAL_WITHDRAW_OVERFLOW = "209"; // Withdraw amount cannot reduce accounts collateral value under minCollateralValue
    string public constant KRASSET_INVALID_FACTOR = "210"; // kFactor must be greater than 1FP
    string public constant KRASSET_BURN_AMOUNT_OVERFLOW = "211"; // Repaying more than account has debt
    string public constant KRASSET_EXISTS = "212"; // KrAsset is already added
    string public constant PARAM_CLOSE_FEE_TOO_HIGH = "213"; // "Close fee exceeds MAX_CLOSE_FEE"
    string public constant PARAM_LIQUIDATION_INCENTIVE_LOW = "214"; // "Liquidation incentive less than MIN_LIQUIDATION_INCENTIVE_MULTIPLIER"
    string public constant PARAM_LIQUIDATION_INCENTIVE_HIGH = "215"; // "Liquidation incentive greater than MAX_LIQUIDATION_INCENTIVE_MULTIPLIER"
    string public constant PARAM_MIN_COLLATERAL_RATIO_LOW = "216"; // Minimum collateral ratio less than MIN_COLLATERALIZATION_RATIO
    string public constant PARAM_MIN_DEBT_AMOUNT_HIGH = "217"; // Minimum debt param argument exceeds MAX_MIN_DEBT_VALUE
    string public constant COLLATERAL_DOESNT_EXIST = "218"; // Collateral does not exist within the protocol
    string public constant KRASSET_DOESNT_EXIST = "219"; // KrAsset does not exist within the protocol
    string public constant KRASSET_NOT_MINTABLE = "220"; // KrAsset is not mintable
    string public constant KRASSET_SYMBOL_EXISTS = "221"; // KrAsset with this symbol is already within the protocl
    string public constant KRASSET_COLLATERAL_LOW = "222"; // Collateral deposits do not cover the amount being minted
    string public constant KRASSET_MINT_AMOUNT_LOW = "223"; // Debt position must be greater than the minimum debt position value
    string public constant KRASSET_MAX_SUPPLY_REACHED = "224"; // KrAsset being minted has reached its current supply limit
    string public constant SELF_LIQUIDATION = "225"; // Account cannot liquidate itself
    string public constant ZERO_REPAY = "226"; // Cannot liquidate zero value
    string public constant STALE_PRICE = "227"; // Price for the asset is stale
    string public constant LIQUIDATION_OVERFLOW = "228"; // Repaying more USD value than allowed
    string public constant ADDRESS_INVALID_SAFETY_COUNCIL = "229"; // Account responsible for the safety council role must be a multisig
    string public constant SAFETY_COUNCIL_EXISTS = "230"; // Only one council role can exist
    string public constant NOT_SAFETY_COUNCIL = "231"; // Sender must have the role `Role.SAFETY_COUNCIL`
    string public constant ACTION_PAUSED_FOR_ASSET = "232"; // This action is currently paused for this asset
    string public constant INVALID_ASSET_SUPPLIED = "233"; // Asset supplied is not a collateral nor a krAsset
    string public constant KRASSET_NOT_ANCHOR = "234"; // Address is not the anchor for the krAsset
    string public constant INVALID_LT = "235"; // Liquidation threshold is greater than minimum collateralization ratio
    string public constant COLLATERAL_INSUFFICIENT_AMOUNT = "236"; // Insufficient amount of collateral to complete the operation
    string public constant MULTISIG_NOT_ENOUGH_OWNERS = "237"; // Multisig has invalid amount of owners
    string public constant PARAM_OPEN_FEE_TOO_HIGH = "238"; // "Close fee exceeds MAX_OPEN_FEE"
    string public constant INVALID_FEE_TYPE = "239"; // "Invalid fee type
    string public constant KRASSET_INVALID_ANCHOR = "240"; // krAsset anchor does not support the correct interfaceId
    string public constant KRASSET_INVALID_CONTRACT = "241"; // krAsset does not support the correct interfaceId
    string public constant KRASSET_MARKET_CLOSED = "242"; // KrAsset's market is currently closed
    string public constant NO_KRASSETS_MINTED = "243"; // Account has no active KreskoAsset positions
    string public constant NO_COLLATERAL_DEPOSITS = "244"; // Account has no active Collateral deposits
    string public constant INVALID_ORACLE_DECIMALS = "245"; // Oracle decimals do not match extOracleDecimals
    string public constant PARAM_LIQUIDATION_OVERFLOW_LOW = "246"; // Liquidation overflow is less than MIN_LIQUIDATION_OVERFLOW
    string public constant INVALID_ORACLE_DEVIATION_PCT = "247"; // Oracle deviation percentage is greater than 100%

    /* -------------------------------------------------------------------------- */
    /*                                   3. Staking                               */
    /* -------------------------------------------------------------------------- */

    string public constant REWARD_PER_BLOCK_MISSING = "300"; // Each reward token must have a reward per block value
    string public constant REWARD_TOKENS_MISSING = "301"; // Pool must include an array of reward token addresses
    string public constant POOL_EXISTS = "302"; // Pool with this deposit token already exists
    string public constant POOL_DOESNT_EXIST = "303"; // Pool with this deposit token does not exist
    string public constant ADDRESS_INVALID_REWARD_RECIPIENT = "304"; // Reward recipient cant be address(0)

    /* -------------------------------------------------------------------------- */
    /*                                   4. Libraries                             */
    /* -------------------------------------------------------------------------- */

    string public constant ARRAY_OUT_OF_BOUNDS = "400"; // Array out of bounds error
    string public constant PRICEFEEDS_MUST_MATCH_STATUS_FEEDS = "401"; // Supplied price feeds must match status feeds in length

    /* -------------------------------------------------------------------------- */
    /*                                   5. KrAsset                               */
    /* -------------------------------------------------------------------------- */

    string public constant REBASING_DENOMINATOR_LOW = "500"; // denominator of rebases must be >= 1
    string public constant ISSUER_NOT_KRESKO = "501"; // issue must be done by kresko
    string public constant REDEEMER_NOT_KRESKO = "502"; // redeem must be done by kresko
    string public constant DESTROY_OVERFLOW = "503"; // trying to destroy more than allowed
    string public constant ISSUE_OVERFLOW = "504"; // trying to destroy more than allowed
    string public constant MINT_OVERFLOW = "505"; // trying to destroy more than allowed
    string public constant DEPOSIT_OVERFLOW = "506"; // trying to destroy more than allowed
    string public constant REDEEM_OVERFLOW = "507"; // trying to destroy more than allowed
    string public constant WITHDRAW_OVERFLOW = "508"; // trying to destroy more than allowed
    string public constant ZERO_SHARES = "509"; // amount of shares must be greater than 0
    string public constant ZERO_ASSETS = "510"; // amount of assets must be greater than 0
    string public constant INVALID_SCALED_AMOUNT = "511"; // amount of debt scaled must be greater than 0

    /* -------------------------------------------------------------------------- */
    /*                              6. STABILITY RATES                            */
    /* -------------------------------------------------------------------------- */

    string public constant STABILITY_RATES_ALREADY_INITIALIZED = "601"; // stability rates for the asset are already initialized
    string public constant INVALID_OPTIMAL_RATE = "602"; // the optimal price rate configured is less than 1e27 for the asset
    string public constant INVALID_PRICE_RATE_DELTA = "603"; // the price rate delta configured is less than 1e27 for the asset
    string public constant STABILITY_RATES_NOT_INITIALIZED = "604"; // the stability rates for the asset are not initialized
    string public constant STABILITY_RATE_OVERFLOW = "605"; // the stability rates is > max uint128
    string public constant DEBT_INDEX_OVERFLOW = "606"; // the debt index is > max uint128
    string public constant KISS_NOT_SET = "607"; // the debt index is > max uint128
    string public constant STABILITY_RATE_REPAYMENT_AMOUNT_ZERO = "608"; // interest being repaid cannot be 0
    string public constant STABILITY_RATE_INTEREST_IS_ZERO = "609"; // account must have accrued interest to repay it
    string public constant INTEREST_REPAY_NOT_PARTIAL = "610"; // account must have accrued interest to repay it

    /* -------------------------------------------------------------------------- */
    /*                              7. AMM ORACLE                                 */
    /* -------------------------------------------------------------------------- */

    string public constant PAIR_ADDRESS_IS_ZERO = "701"; // Pair address to configure cannot be zero
    string public constant INVALID_UPDATE_PERIOD = "702"; // Update period must be greater than the minimum
    string public constant PAIR_ALREADY_EXISTS = "703"; // Pair with the address is already initialized
    string public constant PAIR_DOES_NOT_EXIST = "704"; // Pair supplied does not exist
    string public constant INVALID_LIQUIDITY = "706"; // Pair initializaition requires that the pair has liquidity
    string public constant UPDATE_PERIOD_NOT_FINISHED = "707"; // Update can only be called once per update period
    string public constant INVALID_PAIR = "708"; // Pair being consulted does not have the token that the price was requested for
    string public constant CALLER_NOT_ADMIN = "709"; // Caller must be the admin
    string public constant CONSTRUCTOR_INVALID_ADMIN = "710"; // Admin cannot be zero address in the constructor
    string public constant CONSTRUCTOR_INVALID_FACTORY = "711"; // Factory cannot be the zero address
    string public constant NO_INCENTIVES_LEFT = "712"; // No incentives left for updating the price

    /* -------------------------------------------------------------------------- */
    /*                              8. KISS                                 */
    /* -------------------------------------------------------------------------- */

    string public constant OPERATOR_WAIT_PERIOD_NOT_OVER = "800"; // Operator role has a cooldown period which has not passed
    string public constant OPERATOR_LIMIT_REACHED = "801"; // More minters cannot be assigned before existing one is removed
    string public constant CALLER_NOT_CONTRACT = "802"; // Caller of the function must be a contract
    string public constant OPERATOR_NOT_CONTRACT = "803"; // Operator role can only be granted to a contract
    string public constant KRESKO_NOT_CONTRACT = "804"; // Operator role can only be granted to a contract
    string public constant ADMIN_NOT_A_CONTRACT = "805"; // Operator role can only be granted to a contract
    string public constant OPERATOR_WAIT_PERIOD_TOO_SHORT = "806"; // Operator assignment cooldown period must be greater than 15 minutes
}
