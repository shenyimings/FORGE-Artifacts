// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {IBond} from "./interfaces/IBond.sol";

import {ERC20BurnableUpgradeable, IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {FixedPointMathLib} from "./utils/FixedPointMathLib.sol";

/**
    @title Bond
    @author Porter Finance
    @notice A custom ERC20 token that can be used to issue bonds.
    @notice The contract handles issuance, payment, conversion, and redemption.
    @dev External calls to tokens used for collateral and payment are used
        throughout to transfer and check balances. There is risk that these
        are non-standard and should be carefully inspected before being trusted.
        The contract does not inherit from ERC20Upgradeable or Initializable
        since ERC20BurnableUpgradeable inherits from them. Additionally,
        throughout the contract some state variables are redefined to save
        an extra SLOAD.
*/
contract Bond is
    IBond,
    OwnableUpgradeable,
    ERC20BurnableUpgradeable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20Metadata;
    using FixedPointMathLib for uint256;

    /**
        @notice A period of time after maturity in which bond redemption is
            disallowed for non fully paid bonds. This restriction is lifted 
            once the grace period has ended. The issuer has the ability to
            pay during this time to fully pay the bond. 
    */
    uint256 internal constant GRACE_PERIOD = 7 days;

    /// @inheritdoc IBond
    uint256 public maturity;

    /// @inheritdoc IBond
    address public paymentToken;

    /// @inheritdoc IBond
    address public collateralToken;

    /// @inheritdoc IBond
    uint256 public collateralRatio;

    /// @inheritdoc IBond
    uint256 public convertibleRatio;

    /**
        @dev Confirms the Bond has not yet matured. This is used on the
            `convert` function because bond shares are convertible only before
            maturity has been reached.
    */
    modifier beforeMaturity() {
        if (isMature()) {
            revert BondPastMaturity();
        }
        _;
    }

    /**
        @dev Confirms that the Bond is after the grace period or has been paid.
            This is used in the `redeem` function because bond shares can be
            redeemed when the Bond is fully paid or past the grace period.
    */
    modifier afterGracePeriodOrPaid() {
        if (isAfterGracePeriod() || amountUnpaid() == 0) {
            _;
        } else {
            revert BondBeforeGracePeriodOrPaid();
        }
    }

    /// @inheritdoc IBond
    function initialize(
        string memory bondName,
        string memory bondSymbol,
        address bondOwner,
        uint256 _maturity,
        address _paymentToken,
        address _collateralToken,
        uint256 _collateralRatio,
        uint256 _convertibleRatio,
        uint256 maxSupply
    ) external initializer {
        __ERC20_init(bondName, bondSymbol);
        _transferOwnership(bondOwner);

        maturity = _maturity;
        paymentToken = _paymentToken;
        collateralToken = _collateralToken;
        collateralRatio = _collateralRatio;
        convertibleRatio = _convertibleRatio;

        _mint(bondOwner, maxSupply);
    }

    /// @inheritdoc IBond
    function convert(uint256 bonds) external nonReentrant beforeMaturity {
        if (bonds == 0) {
            revert ZeroAmount();
        }
        uint256 convertibleTokensToSend = previewConvertBeforeMaturity(bonds);
        if (convertibleTokensToSend == 0) {
            revert ZeroAmount();
        }

        burn(bonds);

        address _collateralToken = collateralToken;

        IERC20Metadata(_collateralToken).safeTransfer(
            _msgSender(),
            convertibleTokensToSend
        );

        emit Convert(
            _msgSender(),
            _collateralToken,
            bonds,
            convertibleTokensToSend
        );
    }

    /// @inheritdoc IBond
    function pay(uint256 amount) external nonReentrant {
        if (amountUnpaid() == 0) {
            revert PaymentAlreadyMet();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }

        IERC20Metadata(paymentToken).safeTransferFrom(
            _msgSender(),
            address(this),
            amount
        );

        emit Payment(_msgSender(), amount);
    }

    /// @inheritdoc IBond
    function gracePeriodEnd()
        public
        view
        returns (uint256 gracePeriodEndTimestamp)
    {
        gracePeriodEndTimestamp = maturity + GRACE_PERIOD;
    }

    /// @inheritdoc IBond
    function redeem(uint256 bonds)
        external
        nonReentrant
        afterGracePeriodOrPaid
    {
        if (bonds == 0) {
            revert ZeroAmount();
        }

        (
            uint256 paymentTokensToSend,
            uint256 collateralTokensToSend
        ) = previewRedeemAtMaturity(bonds);

        if (paymentTokensToSend == 0 && collateralTokensToSend == 0) {
            revert ZeroAmount();
        }

        burn(bonds);

        address _paymentToken = paymentToken;
        address _collateralToken = collateralToken;

        if (paymentTokensToSend != 0) {
            IERC20Metadata(_paymentToken).safeTransfer(
                _msgSender(),
                paymentTokensToSend
            );
        }

        if (collateralTokensToSend != 0) {
            IERC20Metadata(_collateralToken).safeTransfer(
                _msgSender(),
                collateralTokensToSend
            );
        }

        emit Redeem(
            _msgSender(),
            _paymentToken,
            _collateralToken,
            bonds,
            paymentTokensToSend,
            collateralTokensToSend
        );
    }

    /// @inheritdoc IBond
    function withdrawExcessCollateral(uint256 amount, address receiver)
        external
        onlyOwner
    {
        if (amount > previewWithdrawExcessCollateral()) {
            revert NotEnoughCollateral();
        }

        address _collateralToken = collateralToken;

        IERC20Metadata(_collateralToken).safeTransfer(receiver, amount);

        emit CollateralWithdraw(
            _msgSender(),
            receiver,
            _collateralToken,
            amount
        );
    }

    /// @inheritdoc IBond
    function withdrawExcessPayment(address receiver) external onlyOwner {
        uint256 overpayment = previewWithdrawExcessPayment();
        if (overpayment <= 0) {
            revert NoPaymentToWithdraw();
        }

        address _paymentToken = paymentToken;

        IERC20Metadata(_paymentToken).safeTransfer(receiver, overpayment);

        emit ExcessPaymentWithdraw(
            _msgSender(),
            receiver,
            _paymentToken,
            overpayment
        );
    }

    /// @inheritdoc IBond
    function sweep(IERC20Metadata sweepingToken, address receiver)
        external
        onlyOwner
    {
        // To protect against tokens that may proxy transfers through different
        // addresses, compare the balances before and after.
        uint256 paymentTokenBalanceBefore = IERC20Metadata(paymentToken)
            .balanceOf(address(this));
        uint256 collateralTokenBalanceBefore = IERC20Metadata(collateralToken)
            .balanceOf(address(this));

        uint256 sweepingTokenBalance = sweepingToken.balanceOf(address(this));

        sweepingToken.safeTransfer(receiver, sweepingTokenBalance);

        uint256 paymentTokenBalanceAfter = IERC20Metadata(paymentToken)
            .balanceOf(address(this));
        uint256 collateralTokenBalanceAfter = IERC20Metadata(collateralToken)
            .balanceOf(address(this));

        if (
            paymentTokenBalanceBefore != paymentTokenBalanceAfter ||
            collateralTokenBalanceBefore != collateralTokenBalanceAfter
        ) {
            revert SweepDisallowedForToken();
        }

        emit TokenSweep(
            _msgSender(),
            receiver,
            sweepingToken,
            sweepingTokenBalance
        );
    }

    /// @inheritdoc IBond
    function previewConvertBeforeMaturity(uint256 bonds)
        public
        view
        returns (uint256 collateralTokens)
    {
        collateralTokens = bonds.mulWadDown(convertibleRatio);
    }

    /// @inheritdoc IBond
    function previewRedeemAtMaturity(uint256 bonds)
        public
        view
        returns (uint256 paymentTokensToSend, uint256 collateralTokensToSend)
    {
        uint256 bondSupply = totalSupply();
        if (bondSupply == 0) {
            return (0, 0);
        }
        uint256 paidAmount = amountUnpaid() == 0
            ? bondSupply
            : paymentBalance();
        paymentTokensToSend = bonds.mulDivDown(paidAmount, bondSupply);

        uint256 nonPaidAmount = bondSupply - paidAmount;
        collateralTokensToSend = collateralRatio.mulWadDown(
            bonds.mulDivDown(nonPaidAmount, bondSupply)
        );
    }

    /// @inheritdoc IBond
    function previewWithdrawExcessCollateral()
        public
        view
        returns (uint256 collateralTokens)
    {
        collateralTokens = previewWithdrawExcessCollateralAfterPayment(0);
    }

    /// @inheritdoc IBond
    function previewWithdrawExcessCollateralAfterPayment(uint256 payment)
        public
        view
        returns (uint256 collateralTokens)
    {
        uint256 tokensCoveredByPayment = paymentBalance() + payment;
        uint256 collateralTokensRequired = 0;
        uint256 bondSupply = totalSupply();
        if (tokensCoveredByPayment < bondSupply) {
            collateralTokensRequired = (bondSupply - tokensCoveredByPayment)
                .mulWadUp(collateralRatio);
        }

        uint256 convertibleTokensRequired = bondSupply.mulWadUp(
            convertibleRatio
        );

        uint256 totalRequiredCollateral;

        if (amountUnpaid() == 0) {
            totalRequiredCollateral = isMature()
                ? 0 // Paid
                : convertibleTokensRequired; // PaidEarly
        } else {
            totalRequiredCollateral = isMature()
                ? collateralTokensRequired // Defaulted
                : _max(convertibleTokensRequired, collateralTokensRequired); // Active
        }
        uint256 _collateralBalance = collateralBalance();
        if (totalRequiredCollateral >= _collateralBalance) {
            return 0;
        }

        collateralTokens = _collateralBalance - totalRequiredCollateral;
    }

    /// @inheritdoc IBond
    function previewWithdrawExcessPayment()
        public
        view
        returns (uint256 paymentTokens)
    {
        uint256 bondSupply = totalSupply();
        uint256 _paymentBalance = paymentBalance();

        if (bondSupply >= _paymentBalance) {
            return 0;
        }

        paymentTokens = _paymentBalance - bondSupply;
    }

    /// @inheritdoc IBond
    function collateralBalance()
        public
        view
        returns (uint256 collateralTokens)
    {
        collateralTokens = IERC20Metadata(collateralToken).balanceOf(
            address(this)
        );
    }

    /// @inheritdoc IBond
    function paymentBalance() public view returns (uint256 paymentTokens) {
        paymentTokens = IERC20Metadata(paymentToken).balanceOf(address(this));
    }

    /// @inheritdoc IBond
    function amountUnpaid() public view returns (uint256 paymentTokens) {
        uint256 bondSupply = totalSupply();
        uint256 _paymentBalance = paymentBalance();

        if (bondSupply <= _paymentBalance) {
            return 0;
        }

        paymentTokens = bondSupply - _paymentBalance;
    }

    /// @inheritdoc IBond
    function isMature() public view returns (bool isBondMature) {
        isBondMature = block.timestamp >= maturity;
    }

    /// @inheritdoc IERC20MetadataUpgradeable
    function decimals() public view override returns (uint8) {
        return IERC20Metadata(paymentToken).decimals();
    }

    /**
        @notice Checks if the grace period timestamp has passed.
        @return isGracePeriodOver Whether or not the Bond is past the
            grace period.
    */
    function isAfterGracePeriod()
        internal
        view
        returns (bool isGracePeriodOver)
    {
        isGracePeriodOver = block.timestamp >= gracePeriodEnd();
    }

    function _max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }
}
