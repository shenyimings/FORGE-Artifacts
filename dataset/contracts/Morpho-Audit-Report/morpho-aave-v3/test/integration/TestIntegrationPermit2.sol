// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {SignatureVerification} from "@permit2/libraries/SignatureVerification.sol";
import {SafeCast160} from "@permit2/libraries/SafeCast160.sol";
import {SignatureExpired} from "@permit2/PermitErrors.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "test/helpers/IntegrationTest.sol";

contract TestIntegrationPermit2 is IntegrationTest {
    using SafeTransferLib for ERC20;
    using WadRayMath for uint256;
    using PermitHash for IAllowanceTransfer.PermitSingle;

    function _signPermit2(
        address underlying,
        address delegator,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint256 privateKey
    ) internal view returns (Types.Signature memory sig) {
        (,, uint48 nonce) = PERMIT2.allowance(delegator, address(underlying), spender);
        IAllowanceTransfer.PermitDetails memory details = IAllowanceTransfer.PermitDetails({
            token: address(underlying),
            amount: SafeCast160.toUint160(amount),
            // Use an unlimited expiration because it most
            // closely mimics how a standard approval works.
            expiration: type(uint48).max,
            nonce: nonce
        });
        IAllowanceTransfer.PermitSingle memory permitSingle =
            IAllowanceTransfer.PermitSingle({details: details, spender: spender, sigDeadline: deadline});

        bytes32 hashed = ECDSA.toTypedDataHash(PERMIT2.DOMAIN_SEPARATOR(), permitSingle.hash());

        (sig.v, sig.r, sig.s) = vm.sign(privateKey, hashed);
    }

    function testSupplyWithPermit2(
        uint256 privateKey,
        uint256 deadline,
        uint256 amount,
        uint256 seed,
        uint256 timestamp
    ) public {
        deadline = bound(deadline, block.timestamp, type(uint32).max);
        privateKey = bound(privateKey, 1, type(uint160).max);
        address delegator = vm.addr(privateKey);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        amount = _boundSupply(market, amount);

        address spender = address(morpho);

        Types.Signature memory sig = _signPermit2(market.underlying, delegator, spender, amount, deadline, privateKey);
        vm.prank(delegator);
        ERC20(market.underlying).safeApprove(address(PERMIT2), type(uint256).max);

        timestamp = bound(timestamp, 0, Math.min(deadline, type(uint48).max) - block.timestamp);
        vm.warp(block.timestamp + timestamp);

        _deal(market.underlying, delegator, amount);

        uint256 balanceBefore = ERC20(market.underlying).balanceOf(delegator);
        uint256 balanceSupplyBefore = morpho.supplyBalance(market.underlying, delegator);

        vm.prank(delegator);
        morpho.supplyWithPermit(market.underlying, amount, delegator, DEFAULT_MAX_ITERATIONS, deadline, sig);
        /// The maximum gap needs to be 4 because sometimes the timestamp is very big, otherwise the test reverts.
        assertApproxEqAbs(
            morpho.supplyBalance(market.underlying, delegator), balanceSupplyBefore + amount, 4, "Incorrect Supply"
        );
        assertEq(ERC20(market.underlying).balanceOf(delegator), balanceBefore - amount, "Incorrect Balance");
    }

    function testSupplyCollateralWithPermit2(
        uint256 privateKey,
        uint256 deadline,
        uint256 amount,
        uint256 seed,
        address onBehalf,
        uint256 timestamp
    ) public {
        deadline = bound(deadline, block.timestamp, type(uint32).max);
        privateKey = bound(privateKey, 1, type(uint160).max);
        address delegator = vm.addr(privateKey);

        onBehalf = _boundOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomCollateral(seed)];

        amount = _boundSupply(market, amount);

        address spender = address(morpho);

        Types.Signature memory sig = _signPermit2(market.underlying, delegator, spender, amount, deadline, privateKey);

        vm.prank(delegator);
        ERC20(market.underlying).safeApprove(address(PERMIT2), type(uint256).max);

        timestamp = bound(timestamp, 0, Math.min(deadline, type(uint48).max) - block.timestamp);
        vm.warp(block.timestamp + timestamp);

        _deal(market.underlying, delegator, amount);

        uint256 balanceBefore = ERC20(market.underlying).balanceOf(delegator);
        uint256 balanceSupplyBefore = morpho.supplyBalance(market.underlying, delegator);

        vm.prank(delegator);
        morpho.supplyCollateralWithPermit(market.underlying, amount, onBehalf, deadline, sig);

        assertApproxEqAbs(
            morpho.collateralBalance(market.underlying, onBehalf),
            balanceSupplyBefore + amount,
            4,
            "collateralBalanceAfter - collateralBalanceBefore != amouunt"
        );

        assertEq(
            ERC20(market.underlying).balanceOf(delegator),
            balanceBefore - amount,
            "balanceBefore - balanceAfter != amount"
        );
    }

    function testRepayWithPermit2(
        uint256 privateKey,
        uint256 deadline,
        uint256 amount,
        uint256 seed,
        address onBehalf,
        uint256 timestamp
    ) public {
        deadline = bound(deadline, block.timestamp, type(uint32).max);
        privateKey = bound(privateKey, 1, type(uint160).max);
        address delegator = vm.addr(privateKey);

        onBehalf = _boundOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        amount = _boundBorrow(market, amount);

        address spender = address(morpho);

        _borrowWithoutCollateral(onBehalf, market, amount, onBehalf, onBehalf, DEFAULT_MAX_ITERATIONS);

        vm.prank(delegator);
        ERC20(market.underlying).safeApprove(address(PERMIT2), type(uint256).max);

        timestamp = bound(timestamp, 0, Math.min(deadline, type(uint48).max) - block.timestamp);
        vm.warp(block.timestamp + timestamp);

        amount = morpho.borrowBalance(market.underlying, onBehalf) - 1;
        Types.Signature memory sig = _signPermit2(market.underlying, delegator, spender, amount, deadline, privateKey);

        _deal(market.underlying, delegator, amount);

        uint256 balanceBefore = ERC20(market.underlying).balanceOf(delegator);

        vm.prank(delegator);
        morpho.repayWithPermit(market.underlying, amount, onBehalf, deadline, sig);

        assertApproxEqAbs(morpho.borrowBalance(market.underlying, onBehalf), 0, 1, "Incorrect Borrow Balance");
        assertEq(ERC20(market.underlying).balanceOf(delegator), balanceBefore - amount, "Incorrect Balance");
    }

    function testRepayAllWithPermit2(
        uint256 privateKey,
        uint256 deadline,
        uint256 amount,
        uint256 seed,
        address onBehalf,
        uint256 timestamp
    ) public {
        deadline = bound(deadline, block.timestamp, type(uint32).max);
        privateKey = bound(privateKey, 1, type(uint160).max);
        address delegator = vm.addr(privateKey);

        onBehalf = _boundOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        amount = _boundBorrow(market, amount);

        address spender = address(morpho);

        _borrowWithoutCollateral(onBehalf, market, amount, onBehalf, onBehalf, DEFAULT_MAX_ITERATIONS);

        vm.prank(delegator);
        ERC20(market.underlying).safeApprove(address(PERMIT2), type(uint256).max);

        timestamp = bound(timestamp, 0, Math.min(deadline, type(uint48).max) - block.timestamp);
        vm.warp(block.timestamp + timestamp);

        Types.Signature memory sig =
            _signPermit2(market.underlying, delegator, spender, type(uint160).max, deadline, privateKey);

        _deal(market.underlying, delegator, type(uint160).max);

        vm.prank(delegator);
        morpho.repayWithPermit(market.underlying, type(uint160).max, onBehalf, deadline, sig);

        assertEq(morpho.borrowBalance(market.underlying, onBehalf), 0, "Incorrect Borrow Balance");
    }

    function testSupplyWithPermit2ShouldRevertBecauseDeadlinePassed(
        uint256 privateKey,
        uint256 deadline,
        uint256 amount,
        uint256 seed,
        address onBehalf,
        uint256 timestamp
    ) public {
        deadline = bound(deadline, block.timestamp, type(uint32).max - 1);
        privateKey = bound(privateKey, 1, type(uint160).max);
        address delegator = vm.addr(privateKey);

        onBehalf = _boundOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        amount = _boundSupply(market, amount);

        address spender = address(morpho);
        Types.Signature memory sig = _signPermit2(market.underlying, delegator, spender, amount, deadline, privateKey);

        vm.prank(delegator);
        ERC20(market.underlying).safeApprove(address(PERMIT2), type(uint256).max);

        _deal(market.underlying, delegator, amount);

        timestamp = bound(timestamp, deadline + 1, type(uint256).max);
        vm.warp(timestamp);

        vm.prank(delegator);
        vm.expectRevert(abi.encodeWithSelector(SignatureExpired.selector, deadline));
        morpho.supplyWithPermit(market.underlying, amount, onBehalf, DEFAULT_MAX_ITERATIONS, deadline, sig);
    }

    function testSupplyWithPermit2ShouldRevertIfSignatureUsedTwice(
        uint256 privateKey,
        uint256 deadline,
        uint256 amount,
        uint256 seed,
        address onBehalf,
        uint256 timestamp
    ) public {
        deadline = bound(deadline, block.timestamp, type(uint32).max);
        privateKey = bound(privateKey, 1, type(uint160).max);
        address delegator = vm.addr(privateKey);

        onBehalf = _boundOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        amount = _boundSupply(market, amount);

        address spender = address(morpho);

        Types.Signature memory sig = _signPermit2(market.underlying, delegator, spender, amount, deadline, privateKey);

        vm.prank(delegator);
        ERC20(market.underlying).safeApprove(address(PERMIT2), type(uint256).max);

        _deal(market.underlying, delegator, 2 * amount);

        timestamp = bound(timestamp, 0, Math.min(deadline, type(uint48).max) - block.timestamp);
        vm.warp(block.timestamp + timestamp);

        vm.prank(delegator);
        morpho.supplyWithPermit(market.underlying, amount, onBehalf, DEFAULT_MAX_ITERATIONS, deadline, sig);

        vm.prank(delegator);
        vm.expectRevert(SignatureVerification.InvalidSigner.selector);
        morpho.supplyWithPermit(market.underlying, amount, onBehalf, DEFAULT_MAX_ITERATIONS, deadline, sig);
    }

    function testShouldRevertIfSomeoneImpersonateSignerOfPermit2(
        uint256 privateKey,
        uint256 deadline,
        uint256 amount,
        uint256 seed,
        address pranker,
        uint256 timestamp
    ) public {
        deadline = bound(deadline, block.timestamp, type(uint32).max);
        privateKey = bound(privateKey, 1, type(uint160).max);
        address delegator = vm.addr(privateKey);
        pranker = _boundAddressValid(pranker);
        vm.assume(pranker != delegator && pranker.code.length == 0);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        amount = _boundSupply(market, amount);

        address spender = address(morpho);

        Types.Signature memory sig = _signPermit2(market.underlying, delegator, spender, amount, deadline, privateKey);

        vm.prank(delegator);
        ERC20(market.underlying).safeApprove(address(PERMIT2), type(uint256).max);

        _deal(market.underlying, delegator, amount);

        timestamp = bound(timestamp, 0, Math.min(deadline, type(uint48).max) - block.timestamp);
        vm.warp(block.timestamp + timestamp);

        vm.prank(pranker);
        vm.expectRevert(SignatureVerification.InvalidSigner.selector);
        morpho.supplyWithPermit(market.underlying, amount, delegator, DEFAULT_MAX_ITERATIONS, deadline, sig);
    }

    function testShouldRevertIfSupplyAnotherAmountThanTheOneSigned(
        uint256 privateKey,
        uint256 deadline,
        uint256 amount,
        uint256 seed,
        uint256 supplied,
        uint256 timestamp
    ) public {
        deadline = bound(deadline, block.timestamp, type(uint32).max);
        privateKey = bound(privateKey, 1, type(uint160).max);
        address delegator = vm.addr(privateKey);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        amount = _boundSupply(market, amount);
        supplied = bound(supplied, 0, amount - 1);

        address spender = address(morpho);

        Types.Signature memory sig = _signPermit2(market.underlying, delegator, spender, amount, deadline, privateKey);

        vm.prank(delegator);
        ERC20(market.underlying).safeApprove(address(PERMIT2), type(uint256).max);

        _deal(market.underlying, delegator, amount);

        timestamp = bound(timestamp, 0, Math.min(deadline, type(uint48).max) - block.timestamp);
        vm.warp(block.timestamp + timestamp);

        vm.prank(delegator);
        vm.expectRevert(SignatureVerification.InvalidSigner.selector);
        morpho.supplyWithPermit(market.underlying, supplied, delegator, DEFAULT_MAX_ITERATIONS, deadline, sig);
    }

    function testShouldRevertIfPermit2SignWithWrongPrivateKey(
        uint256 privateKey,
        uint256 wrongPrivateKey,
        uint256 deadline,
        uint256 amount,
        uint256 seed,
        uint256 timestamp
    ) public {
        deadline = bound(deadline, block.timestamp, type(uint32).max);
        privateKey = bound(privateKey, 1, type(uint160).max);
        address delegator = vm.addr(privateKey);

        wrongPrivateKey = bound(wrongPrivateKey, 1, type(uint160).max);
        vm.assume(wrongPrivateKey != privateKey);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        amount = _boundSupply(market, amount);

        address spender = address(morpho);

        Types.Signature memory sig =
            _signPermit2(market.underlying, delegator, spender, amount, deadline, wrongPrivateKey);

        vm.prank(delegator);
        ERC20(market.underlying).safeApprove(address(PERMIT2), type(uint256).max);

        _deal(market.underlying, delegator, amount);

        timestamp = bound(timestamp, 0, Math.min(deadline, type(uint48).max) - block.timestamp);
        vm.warp(block.timestamp + timestamp);

        vm.prank(delegator);
        vm.expectRevert(SignatureVerification.InvalidSigner.selector);
        morpho.supplyWithPermit(market.underlying, amount, delegator, DEFAULT_MAX_ITERATIONS, deadline, sig);
    }
}
