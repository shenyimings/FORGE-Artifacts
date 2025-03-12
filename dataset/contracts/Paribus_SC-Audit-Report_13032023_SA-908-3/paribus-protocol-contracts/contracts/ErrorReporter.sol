// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.5.17;

contract ComptrollerErrorReporter {
    enum Error {
        NO_ERROR, // 0
        UNAUTHORIZED, // 1
        COMPTROLLER_MISMATCH, // 2
        INSUFFICIENT_SHORTFALL, // 3
        INSUFFICIENT_LIQUIDITY, // 4
        INVALID_CLOSE_FACTOR, // 5
        INVALID_COLLATERAL_FACTOR, // 6
        INVALID_LIQUIDATION_INCENTIVE, // 7
        MARKET_NOT_ENTERED, // 8
        MARKET_NOT_LISTED, // 9
        MARKET_ALREADY_LISTED, // 10
        MATH_ERROR, // 11
        NONZERO_BORROW_BALANCE, // 12
        PRICE_ERROR, // 13
        REJECTION, // 14
        SNAPSHOT_ERROR, // 15
        TOO_MANY_ASSETS, // 16
        TOO_MUCH_REPAY // 17
    }

    enum FailureInfo {
        ACCEPT_ADMIN_PENDING_ADMIN_CHECK, // 0
        ACCEPT_PENDING_IMPLEMENTATION_ADDRESS_CHECK, // 1
        EXIT_MARKET_BALANCE_OWED, // 2
        EXIT_MARKET_REJECTION, // 3
        SET_CLOSE_FACTOR_OWNER_CHECK, // 4
        SET_CLOSE_FACTOR_VALIDATION, // 5
        SET_COLLATERAL_FACTOR_OWNER_CHECK, // 6
        SET_COLLATERAL_FACTOR_NO_EXISTS, // 7
        SET_COLLATERAL_FACTOR_VALIDATION, // 8
        SET_COLLATERAL_FACTOR_WITHOUT_PRICE, // 9
        SET_IMPLEMENTATION_OWNER_CHECK, // 10
        SET_LIQUIDATION_INCENTIVE_OWNER_CHECK, // 11
        SET_LIQUIDATION_INCENTIVE_VALIDATION, // 12
        SET_MAX_ASSETS_OWNER_CHECK, // 13
        SET_PENDING_ADMIN_OWNER_CHECK, // 14
        SET_PENDING_IMPLEMENTATION_OWNER_CHECK, // 15
        SET_PRICE_ORACLE_OWNER_CHECK, // 16
        SUPPORT_MARKET_EXISTS, // 17
        SUPPORT_MARKET_OWNER_CHECK, // 18
        SET_PAUSE_GUARDIAN_OWNER_CHECK // 19
    }

    /**
      * @dev `error` corresponds to enum Error; `info` corresponds to enum FailureInfo, and `detail` is an arbitrary
      * contract-specific code that enables us to report opaque error codes from upgradeable contracts.
      **/
    event Failure(uint error, uint info, uint detail);

    /**
      * @dev use this when reporting a known error from the money market or a non-upgradeable collaborator
      */
    function fail(Error err, FailureInfo info) internal returns (uint) {
        emit Failure(uint(err), uint(info), 0);

        return uint(err);
    }

    /**
      * @dev use this when reporting an opaque error from an upgradeable collaborator contract
      */
    function failOpaque(Error err, FailureInfo info, uint opaqueError) internal returns (uint) {
        emit Failure(uint(err), uint(info), opaqueError);

        return uint(err);
    }
}

contract TokenErrorReporter {
    enum Error {
        NO_ERROR, // 0
        UNAUTHORIZED, // 1
        BAD_INPUT, // 2
        COMPTROLLER_REJECTION, // 3
        COMPTROLLER_CALCULATION_ERROR, // 4
        INTEREST_RATE_MODEL_ERROR, // 5
        INVALID_ACCOUNT_PAIR, // 6
        INVALID_CLOSE_AMOUNT_REQUESTED, // 7
        INVALID_COLLATERAL_FACTOR, // 8
        MATH_ERROR, // 9
        MARKET_NOT_FRESH, // 10
        MARKET_NOT_LISTED, // 11
        TOKEN_INSUFFICIENT_ALLOWANCE, // 12
        TOKEN_INSUFFICIENT_BALANCE, // 13
        TOKEN_INSUFFICIENT_CASH, // 14
        TOKEN_TRANSFER_IN_FAILED, // 15
        TOKEN_TRANSFER_OUT_FAILED // 16
    }

    /*
     * Note: FailureInfo (but not Error) is kept in alphabetical order
     *       This is because FailureInfo grows significantly faster, and
     *       the order of Error has some meaning, while the order of FailureInfo
     *       is entirely arbitrary.
     */
    enum FailureInfo {
        ACCEPT_ADMIN_PENDING_ADMIN_CHECK, // 0
        ACCRUE_INTEREST_ACCUMULATED_INTEREST_CALCULATION_FAILED, // 1
        ACCRUE_INTEREST_BORROW_RATE_CALCULATION_FAILED, // 2
        ACCRUE_INTEREST_NEW_BORROW_INDEX_CALCULATION_FAILED, // 3
        ACCRUE_INTEREST_NEW_TOTAL_BORROWS_CALCULATION_FAILED, // 4
        ACCRUE_INTEREST_NEW_TOTAL_RESERVES_CALCULATION_FAILED, // 5
        ACCRUE_INTEREST_SIMPLE_INTEREST_FACTOR_CALCULATION_FAILED, // 6
        BORROW_ACCUMULATED_BALANCE_CALCULATION_FAILED, // 7
        BORROW_ACCRUE_INTEREST_FAILED, // 8
        BORROW_CASH_NOT_AVAILABLE, // 9
        BORROW_FRESHNESS_CHECK, // 10
        BORROW_NEW_TOTAL_BALANCE_CALCULATION_FAILED, // 11
        BORROW_NEW_ACCOUNT_BORROW_BALANCE_CALCULATION_FAILED, // 12
        BORROW_MARKET_NOT_LISTED, // 13
        BORROW_COMPTROLLER_REJECTION, // 14
        LIQUIDATE_ACCRUE_BORROW_INTEREST_FAILED, // 15
        LIQUIDATE_ACCRUE_COLLATERAL_INTEREST_FAILED, // 16
        LIQUIDATE_COLLATERAL_FRESHNESS_CHECK, // 17
        LIQUIDATE_COMPTROLLER_REJECTION, // 18
        LIQUIDATE_COMPTROLLER_CALCULATE_AMOUNT_SEIZE_FAILED, // 19
        LIQUIDATE_CLOSE_AMOUNT_IS_UINT_MAX, // 20
        LIQUIDATE_CLOSE_AMOUNT_IS_ZERO, // 21
        LIQUIDATE_FRESHNESS_CHECK, // 22
        LIQUIDATE_LIQUIDATOR_IS_BORROWER, // 23
        LIQUIDATE_REPAY_BORROW_FRESH_FAILED, // 24
        LIQUIDATE_SEIZE_BALANCE_INCREMENT_FAILED, // 25
        LIQUIDATE_SEIZE_BALANCE_DECREMENT_FAILED, // 26
        LIQUIDATE_SEIZE_COMPTROLLER_REJECTION, // 27
        LIQUIDATE_SEIZE_LIQUIDATOR_IS_BORROWER, // 28
        LIQUIDATE_SEIZE_TOO_MUCH, // 29
        MINT_ACCRUE_INTEREST_FAILED, // 30
        MINT_COMPTROLLER_REJECTION, // 31
        MINT_EXCHANGE_CALCULATION_FAILED, // 32
        MINT_EXCHANGE_RATE_READ_FAILED, // 33
        MINT_FRESHNESS_CHECK, // 34
        MINT_NEW_ACCOUNT_BALANCE_CALCULATION_FAILED, // 35
        MINT_NEW_TOTAL_SUPPLY_CALCULATION_FAILED, // 36
        MINT_TRANSFER_IN_FAILED, // 37
        MINT_TRANSFER_IN_NOT_POSSIBLE, // 38
        REDEEM_ACCRUE_INTEREST_FAILED, // 39
        REDEEM_COMPTROLLER_REJECTION, // 40
        REDEEM_EXCHANGE_TOKENS_CALCULATION_FAILED, // 41
        REDEEM_EXCHANGE_AMOUNT_CALCULATION_FAILED, // 42
        REDEEM_EXCHANGE_RATE_READ_FAILED, // 43
        REDEEM_FRESHNESS_CHECK, // 44
        REDEEM_NEW_ACCOUNT_BALANCE_CALCULATION_FAILED, // 45
        REDEEM_NEW_TOTAL_SUPPLY_CALCULATION_FAILED, // 46
        REDEEM_TRANSFER_OUT_NOT_POSSIBLE, // 47
        REDUCE_RESERVES_ACCRUE_INTEREST_FAILED, // 48
        REDUCE_RESERVES_ADMIN_CHECK, // 49
        REDUCE_RESERVES_CASH_NOT_AVAILABLE, // 50
        REDUCE_RESERVES_FRESH_CHECK, // 51
        REDUCE_RESERVES_VALIDATION, // 52
        REPAY_BEHALF_ACCRUE_INTEREST_FAILED, // 53
        REPAY_BORROW_ACCRUE_INTEREST_FAILED, // 54
        REPAY_BORROW_ACCUMULATED_BALANCE_CALCULATION_FAILED, // 55
        REPAY_BORROW_COMPTROLLER_REJECTION, // 56
        REPAY_BORROW_FRESHNESS_CHECK, // 57
        REPAY_BORROW_NEW_ACCOUNT_BORROW_BALANCE_CALCULATION_FAILED, // 58
        REPAY_BORROW_NEW_TOTAL_BALANCE_CALCULATION_FAILED, // 59
        REPAY_BORROW_TRANSFER_IN_NOT_POSSIBLE, // 60
        SET_COLLATERAL_FACTOR_OWNER_CHECK, // 61
        SET_COLLATERAL_FACTOR_VALIDATION, // 62
        SET_COMPTROLLER_OWNER_CHECK, // 63
        SET_INTEREST_RATE_MODEL_ACCRUE_INTEREST_FAILED, // 64
        SET_INTEREST_RATE_MODEL_FRESH_CHECK, // 65
        SET_INTEREST_RATE_MODEL_OWNER_CHECK, // 66
        SET_MAX_ASSETS_OWNER_CHECK, // 67
        SET_ORACLE_MARKET_NOT_LISTED, // 68
        SET_PENDING_ADMIN_OWNER_CHECK, // 69
        SET_RESERVE_FACTOR_ACCRUE_INTEREST_FAILED, // 70
        SET_RESERVE_FACTOR_ADMIN_CHECK, // 71
        SET_RESERVE_FACTOR_FRESH_CHECK, // 72
        SET_RESERVE_FACTOR_BOUNDS_CHECK, // 73
        TRANSFER_COMPTROLLER_REJECTION, // 74
        TRANSFER_NOT_ALLOWED, // 75
        TRANSFER_NOT_ENOUGH, // 76
        TRANSFER_TOO_MUCH, // 77
        ADD_RESERVES_ACCRUE_INTEREST_FAILED, // 78
        ADD_RESERVES_FRESH_CHECK, // 79
        ADD_RESERVES_TRANSFER_IN_NOT_POSSIBLE // 80
    }

    /**
      * @dev `error` corresponds to enum Error; `info` corresponds to enum FailureInfo, and `detail` is an arbitrary
      * contract-specific code that enables us to report opaque error codes from upgradeable contracts.
      **/
    event Failure(uint error, uint info, uint detail);

    /**
      * @dev use this when reporting a known error from the money market or a non-upgradeable collaborator
      */
    function fail(Error err, FailureInfo info) internal returns (uint) {
        emit Failure(uint(err), uint(info), 0);

        return uint(err);
    }

    /**
      * @dev use this when reporting an opaque error from an upgradeable collaborator contract
      */
    function failOpaque(Error err, FailureInfo info, uint opaqueError) internal returns (uint) {
        emit Failure(uint(err), uint(info), opaqueError);

        return uint(err);
    }
}
