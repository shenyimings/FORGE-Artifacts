// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "prb-math/contracts/PRBMathUD60x18.sol";

import "./interfaces/ILoanPriceOracle.sol";

/**
 * @title Loan Price Oracle
 */
contract LoanPriceOracle is Ownable, ILoanPriceOracle {
    /**************************************************************************/
    /* Constants */
    /**************************************************************************/

    /**
     * @notice Implementation version
     */
    string public constant IMPLEMENTATION_VERSION = "1.0";

    /**************************************************************************/
    /* Errors */
    /**************************************************************************/

    /**
     * @notice Unsupported token decimals
     */
    error UnsupportedTokenDecimals();

    /**
     * @notice Invalid address (e.g. zero address)
     */
    error InvalidAddress();

    /**************************************************************************/
    /* State */
    /**************************************************************************/

    /**
     * @notice Piecewise linear model parameters
     * @param slope1 Slope before kink in UD60x18
     * @param slope2 Slope after kink in UD60x18
     * @param target Value of kink in UD60x18
     * @param max Max input value in UD60x18
     */
    struct PiecewiseLinearModel {
        uint256 slope1;
        uint256 slope2;
        uint256 target;
        uint256 max;
    }

    /**
     * @notice Collateral parameters
     * @param collateralValue Collateral value in UD60x18
     * @param utilizationRateComponent Rate component model for utilization
     * @param loanToValueRateComponent Rate component model for loan to value
     * @param durationRateComponent Rate component model for duration
     * @param rateComponentWeights Weights for rate components, each 0 to 100
     */
    struct CollateralParameters {
        uint256 collateralValue; /* UD60x18 */
        PiecewiseLinearModel utilizationRateComponent;
        PiecewiseLinearModel loanToValueRateComponent;
        PiecewiseLinearModel durationRateComponent;
        uint8[3] rateComponentWeights; /* 0-100 */
    }

    /**
     * @dev Mapping of collateral token contract to collateral parameters
     */
    mapping(address => CollateralParameters) private _parameters;

    /**
     * @inheritdoc ILoanPriceOracle
     */
    IERC20 public immutable override currencyToken;

    /**
     * @notice Minimum discount rate in UD60x18 amount per second
     */
    uint256 public minimumDiscountRate;

    /**
     * @notice Minimum loan duration in seconds
     */
    uint256 public minimumLoanDuration;

    /**************************************************************************/
    /* Events */
    /**************************************************************************/

    /**
     * @notice Emitted when minimum discount rate is updated
     * @param rate New minimum discount rate in UD60x18 amount per second
     */
    event MinimumDiscountRateUpdated(uint256 rate);

    /**
     * @notice Emitted when minimum loan duration is updated
     * @param duration New minimum loan duration in seconds
     */
    event MinimumLoanDurationUpdated(uint256 duration);

    /**
     * @notice Emitted when collateral parameters are updated
     * @param collateralToken Address of collateral token
     */
    event CollateralParametersUpdated(address collateralToken);

    /**************************************************************************/
    /* Constructor */
    /**************************************************************************/

    /**
     * @notice LoanPriceOracle constructor
     * @param currencyToken_ Currency token used for pricing
     */
    constructor(IERC20 currencyToken_) {
        if (IERC20Metadata(address(currencyToken_)).decimals() != 18) revert UnsupportedTokenDecimals();

        currencyToken = currencyToken_;
    }

    /**************************************************************************/
    /* Internal Helper Functions */
    /**************************************************************************/

    /**
     * @dev Compute the output of the specified piecewise linear model with
     * input x
     * @param model Piecewise linear model to compute
     * @param x Input value in UD60x18
     * @param index Parameter index (for error reporting)
     * @return Result in UD60x18
     */
    function _computeRateComponent(
        PiecewiseLinearModel storage model,
        uint256 x,
        uint256 index
    ) internal view returns (uint256) {
        if (x > model.max) {
            revert ParameterOutOfBounds(index);
        }
        return
            (x <= model.target)
                ? minimumDiscountRate + PRBMathUD60x18.mul(x, model.slope1)
                : minimumDiscountRate +
                    PRBMathUD60x18.mul(model.target, model.slope1) +
                    PRBMathUD60x18.mul(x - model.target, model.slope2);
    }

    /**
     * @dev Compute the weighted rate
     * @param weights Weights to apply, each 0 to 100
     * @param components Components to weight, each UD60x18
     * @return Weighted rate in UD60x18
     */
    function _computeWeightedRate(uint8[3] storage weights, uint256[3] memory components)
        internal
        view
        returns (uint256)
    {
        return
            PRBMathUD60x18.div(
                PRBMathUD60x18.mul(components[0], PRBMathUD60x18.fromUint(weights[0])) +
                    PRBMathUD60x18.mul(components[1], PRBMathUD60x18.fromUint(weights[1])) +
                    PRBMathUD60x18.mul(components[2], PRBMathUD60x18.fromUint(weights[2])),
                PRBMathUD60x18.fromUint(100)
            );
    }

    /**************************************************************************/
    /* Primary API */
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
        /* Unused variables */
        collateralTokenId;
        duration;

        /* Calculate loan time remaining */
        uint256 loanTimeRemaining = maturity - block.timestamp;
        if (loanTimeRemaining < minimumLoanDuration) {
            revert InsufficientTimeRemaining();
        }

        /* Look up collateral parameters */
        CollateralParameters storage collateralParameters = _parameters[collateralToken];
        if (collateralParameters.collateralValue == 0) {
            revert UnsupportedCollateral();
        }

        /* Convert loan time remaining */
        loanTimeRemaining = PRBMathUD60x18.fromUint(loanTimeRemaining);

        /* Calculate loan to value */
        uint256 loanToValue = PRBMathUD60x18.div(principal, collateralParameters.collateralValue);

        /* Compute discount rate components for utilization, loan-to-value, and duration */
        uint256[3] memory rateComponents = [
            _computeRateComponent(collateralParameters.utilizationRateComponent, utilization, 0),
            _computeRateComponent(collateralParameters.loanToValueRateComponent, loanToValue, 1),
            _computeRateComponent(collateralParameters.durationRateComponent, loanTimeRemaining, 2)
        ];

        /* Calculate discount rate from components */
        uint256 discountRate = _computeWeightedRate(collateralParameters.rateComponentWeights, rateComponents);

        /* Calculate purchase price */
        /* Purchase Price = Loan Repayment Value / (1 + Discount Rate * t) */
        uint256 purchasePrice = PRBMathUD60x18.div(
            repayment,
            1e18 + PRBMathUD60x18.mul(discountRate, loanTimeRemaining)
        );

        return purchasePrice;
    }

    /**************************************************************************/
    /* Getters */
    /**************************************************************************/

    /**
     * @notice Get collateral parameters for token contract
     * @param collateralToken Collateral token contract
     * @return Collateral parameters
     */
    function getCollateralParameters(address collateralToken) external view returns (CollateralParameters memory) {
        return _parameters[collateralToken];
    }

    /**************************************************************************/
    /* Setters */
    /**************************************************************************/

    /**
     * @notice Set minimum discount rate
     *
     * Emits a {MinimumDiscountRateUpdated} event.
     *
     * @param rate Minimum discount rate in UD60x18 amount per second
     */
    function setMinimumDiscountRate(uint256 rate) external onlyOwner {
        minimumDiscountRate = rate;

        emit MinimumDiscountRateUpdated(rate);
    }

    /**
     * @notice Set minimum loan duration
     *
     * Emits a {MinimumLoanDurationUpdated} event.
     *
     * @param duration Minimum loan duration in seconds
     */
    function setMinimumLoanDuration(uint256 duration) external onlyOwner {
        minimumLoanDuration = duration;

        emit MinimumLoanDurationUpdated(duration);
    }

    /**
     * @notice Set collateral parameters
     *
     * Emits a {CollateralParametersUpdated} event.
     *
     * @param collateralToken Collateral token contract
     * @param packedCollateralParameters Collateral parameters, ABI-encoded
     */
    function setCollateralParameters(address collateralToken, bytes calldata packedCollateralParameters)
        external
        onlyOwner
    {
        if (collateralToken == address(0)) revert InvalidAddress();

        _parameters[collateralToken] = abi.decode(packedCollateralParameters, (CollateralParameters));

        emit CollateralParametersUpdated(collateralToken);
    }
}
