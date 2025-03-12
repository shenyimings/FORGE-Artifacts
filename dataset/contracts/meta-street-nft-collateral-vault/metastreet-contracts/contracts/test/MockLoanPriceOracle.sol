// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "contracts/interfaces/ILoanPriceOracle.sol";

/**
 * @title Mock Loan Price Oracle
 */
contract MockLoanPriceOracle is ILoanPriceOracle {
    /**************************************************************************/
    /* Constants */
    /**************************************************************************/

    /**
     * @notice Mock error
     */
    enum MockError {
        None,
        UnsupportedCollateral,
        InsufficientTimeRemaining,
        ParameterOutOfBounds
    }

    /**************************************************************************/
    /* Properties */
    /**************************************************************************/

    IERC20 public override currencyToken;
    MockError private _error;
    uint256 private _price;

    /**************************************************************************/
    /* Constructor */
    /**************************************************************************/

    /**
     * @notice MockLoanPriceOracle constructor
     * @param currencyToken_ Currency token used for pricing
     */
    constructor(IERC20 currencyToken_) {
        currencyToken = currencyToken_;
    }

    /**************************************************************************/
    /* Implementation */
    /**************************************************************************/

    /**
     * @inheritdoc ILoanPriceOracle
     */
    function priceLoan(
        address collateralToken,
        uint256 collateralTokenId,
        uint256 principal,
        uint256 repayment,
        uint256 duration,
        uint256 maturity,
        uint256 utilization
    ) external view returns (uint256) {
        collateralToken;
        collateralTokenId;
        principal;
        repayment;
        duration;
        maturity;
        utilization;

        if (_error == MockError.UnsupportedCollateral) {
            revert UnsupportedCollateral();
        } else if (_error == MockError.InsufficientTimeRemaining) {
            revert InsufficientTimeRemaining();
        } else if (_error == MockError.ParameterOutOfBounds) {
            revert ParameterOutOfBounds(0);
        }

        return _price;
    }

    /**
     * @notice Set a mock error to be reverted by priceLoan()
     * @param error Mock error
     */
    function setError(MockError error) external {
        _error = error;
    }

    /**
     * @notice Set the price to be returned by priceLoan()
     * @param price Price
     */
    function setPrice(uint256 price) external {
        _price = price;
    }
}
