// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IWETH} from "@src/interfaces/IWETH.sol";

import {CreditPosition, DebtPosition} from "@src/libraries/LoanLibrary.sol";
import {BorrowOffer, LoanOffer} from "@src/libraries/OfferLibrary.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

import {NonTransferrableScaledToken} from "@src/token/NonTransferrableScaledToken.sol";
import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";

struct User {
    // The user's loan offer
    LoanOffer loanOffer;
    // The user's borrow offer
    BorrowOffer borrowOffer;
    // The user-defined opening limit CR. If not set, the protocol's crOpening is used.
    uint256 openingLimitBorrowCR;
    // Whether the user has disabled all credit positions for sale
    bool allCreditPositionsForSaleDisabled;
}

struct FeeConfig {
    // annual percentage rate of the protocol swap fee
    uint256 swapFeeAPR;
    // fee for fractionalizing credit positions
    uint256 fragmentationFee;
    // percent of the futureValue to be given to the liquidator
    uint256 liquidationRewardPercent;
    // percent of collateral remainder to be split with protocol on profitable liquidations for overdue loans
    uint256 overdueCollateralProtocolPercent;
    // percent of collateral to be split with protocol on profitable liquidations
    uint256 collateralProtocolPercent;
    // address to receive protocol fees
    address feeRecipient;
}

struct RiskConfig {
    // minimum collateral ratio for opening a loan
    uint256 crOpening;
    // maximum collateral ratio for liquidation
    uint256 crLiquidation;
    // minimum credit value of loans
    uint256 minimumCreditBorrowAToken;
    // maximum amount of deposited borrowed aTokens
    uint256 borrowATokenCap;
    // minimum tenor for a loan
    uint256 minTenor;
    // maximum tenor for a loan
    uint256 maxTenor;
}

struct Oracle {
    // price feed oracle
    IPriceFeed priceFeed;
    // variable pool borrow rate
    uint128 variablePoolBorrowRate;
    // timestamp of the last update
    uint64 variablePoolBorrowRateUpdatedAt;
    // stale rate interval
    uint64 variablePoolBorrowRateStaleRateInterval;
}

struct Data {
    // mapping of User structs
    mapping(address => User) users;
    // mapping of DebtPosition structs
    mapping(uint256 => DebtPosition) debtPositions;
    // mapping of CreditPosition structs
    mapping(uint256 => CreditPosition) creditPositions;
    // next debt position id
    uint256 nextDebtPositionId;
    // next credit position id
    uint256 nextCreditPositionId;
    // Wrapped Ether contract address
    IWETH weth;
    // the token used by borrowers to collateralize their loans
    IERC20Metadata underlyingCollateralToken;
    // the token lent from lenders to borrowers
    IERC20Metadata underlyingBorrowToken;
    // Size deposit underlying collateral token
    NonTransferrableToken collateralToken;
    // Size deposit underlying borrow aToken
    NonTransferrableScaledToken borrowAToken;
    // Size tokenized debt
    NonTransferrableToken debtToken;
    // Variable Pool (Aave v3)
    IPool variablePool;
    // Multicall lock to check if multicall is in progress
    bool isMulticall;
}

struct State {
    // the fee configuration struct
    FeeConfig feeConfig;
    // the risk configuration struct
    RiskConfig riskConfig;
    // the oracle configuration struct
    Oracle oracle;
    // the protocol data (cannot be updated)
    Data data;
}

/// @title SizeStorage
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Storage for the Size protocol
/// @dev WARNING: Changing the order of the variables or inner structs in this contract may break the storage layout
abstract contract SizeStorage {
    State internal state;
}
