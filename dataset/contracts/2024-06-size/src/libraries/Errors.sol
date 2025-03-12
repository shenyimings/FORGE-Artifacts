// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {LoanStatus} from "@src/libraries/LoanLibrary.sol";

/// @title Errors
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
library Errors {
    error USER_IS_UNDERWATER(address account, uint256 cr);
    error NULL_ADDRESS();
    error NULL_AMOUNT();
    error NULL_TENOR();
    error NULL_MAX_DUE_DATE();
    error NULL_ARRAY();
    error NULL_OFFER();
    error INVALID_MSG_VALUE(uint256 value);
    error TENORS_NOT_STRICTLY_INCREASING();
    error ARRAY_LENGTHS_MISMATCH();
    error INVALID_TOKEN(address token);
    error INVALID_KEY(string key);
    error INVALID_COLLATERAL_RATIO(uint256 cr);
    error INVALID_COLLATERAL_PERCENTAGE_PREMIUM(uint256 percentage);
    error INVALID_MAXIMUM_TENOR(uint256 maxTenor);
    error VALUE_GREATER_THAN_MAX(uint256 value, uint256 max);
    error INVALID_LIQUIDATION_COLLATERAL_RATIO(uint256 crOpening, uint256 crLiquidation);
    error PAST_DEADLINE(uint256 deadline);
    error PAST_MAX_DUE_DATE(uint256 maxDueDate);
    error APR_LOWER_THAN_MIN_APR(uint256 apr, uint256 minAPR);
    error APR_GREATER_THAN_MAX_APR(uint256 apr, uint256 maxAPR);
    error DUE_DATE_NOT_COMPATIBLE(uint256 dueDate1, uint256 dueDate2);
    error DUE_DATE_GREATER_THAN_MAX_DUE_DATE(uint256 dueDate, uint256 maxDueDate);
    error TENOR_OUT_OF_RANGE(uint256 tenor, uint256 minTenor, uint256 maxTenor);
    error INVALID_POSITION_ID(uint256 positionId);
    error INVALID_DEBT_POSITION_ID(uint256 debtPositionId);
    error INVALID_CREDIT_POSITION_ID(uint256 creditPositionId);
    error INVALID_LENDER(address account);
    error INVALID_LOAN_OFFER(address lender);
    error INVALID_BORROW_OFFER(address borrower);

    error CREDIT_NOT_FOR_SALE(uint256 creditPositionId);
    error NOT_ENOUGH_CREDIT(uint256 credit, uint256 required);
    error NOT_ENOUGH_CASH(uint256 cash, uint256 required);

    error BORROWER_IS_NOT_LENDER(address borrower, address lender);
    error COMPENSATOR_IS_NOT_BORROWER(address compensator, address borrower);
    error LIQUIDATOR_IS_NOT_LENDER(address liquidator, address lender);

    error NOT_ENOUGH_BORROW_ATOKEN_BALANCE(address account, uint256 balance, uint256 required);
    error NOT_ENOUGH_BORROW_ATOKEN_LIQUIDITY(uint256 liquidity, uint256 required);
    error CREDIT_LOWER_THAN_MINIMUM_CREDIT(uint256 credit, uint256 minimumCreditBorrowAToken);
    error CREDIT_LOWER_THAN_MINIMUM_CREDIT_OPENING(uint256 credit, uint256 minimumCreditBorrowAToken);

    error CREDIT_POSITION_ALREADY_CLAIMED(uint256 positionId);

    error CREDIT_POSITION_NOT_TRANSFERRABLE(uint256 creditPositionId, LoanStatus status, uint256 borrowerCR);

    error LOAN_ALREADY_REPAID(uint256 positionId);
    error LOAN_NOT_REPAID(uint256 positionId);
    error LOAN_NOT_ACTIVE(uint256 positionId);

    error LOAN_NOT_LIQUIDATABLE(uint256 debtPositionId, uint256 cr, LoanStatus status);
    error LOAN_NOT_SELF_LIQUIDATABLE(uint256 creditPositionId, uint256 cr, LoanStatus status);
    error LIQUIDATE_PROFIT_BELOW_MINIMUM_COLLATERAL_PROFIT(
        uint256 liquidatorProfitCollateralToken, uint256 minimumCollateralProfit
    );
    error CR_BELOW_OPENING_LIMIT_BORROW_CR(address account, uint256 cr, uint256 riskCollateralRatio);
    error LIQUIDATION_NOT_AT_LOSS(uint256 positionId, uint256 cr);

    error INVALID_DECIMALS(uint8 decimals);
    error INVALID_PRICE(address aggregator, int256 price);
    error STALE_PRICE(address aggregator, uint256 updatedAt);
    error NULL_STALE_PRICE();
    error NULL_STALE_RATE();
    error STALE_RATE(uint128 updatedAt);

    error BORROW_ATOKEN_INCREASE_EXCEEDS_DEBT_TOKEN_DECREASE(uint256 borrowATokenIncrease, uint256 debtTokenDecrease);
    error BORROW_ATOKEN_CAP_EXCEEDED(uint256 cap, uint256 amount);

    error NOT_SUPPORTED();

    error SEQUENCER_DOWN();
    error GRACE_PERIOD_NOT_OVER();
}
