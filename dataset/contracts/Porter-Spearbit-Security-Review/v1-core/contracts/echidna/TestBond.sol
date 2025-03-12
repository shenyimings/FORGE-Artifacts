// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {Bond} from "../Bond.sol";
import {TestERC20} from "../test/TestERC20.sol";

contract TestBond {
    event AssertionFailed(string);
    Bond public bond;

    TestERC20 public paymentToken;
    TestERC20 public collateralToken;

    uint256 public constant MAX_SUPPLY = 50000000 ether;
    uint256 internal constant COLLATERAL_RATIO = 1.5 ether;
    uint256 internal constant CONVERTIBLE_RATIO = .5 ether;
    uint256 internal constant ONE = 1e18;
    uint256 internal constant MAX_INT = 2**256 - 1;
    uint256 internal maturity;

    constructor() {
        maturity = block.timestamp + 365 days;

        paymentToken = new TestERC20("PT", "PT", MAX_INT, 6);
        collateralToken = new TestERC20("CT", "CT", MAX_INT, 18);

        bond = new Bond();
        try
            bond.initialize(
                "bondName",
                "bondSymbol",
                address(this),
                maturity,
                address(paymentToken),
                address(collateralToken),
                COLLATERAL_RATIO,
                CONVERTIBLE_RATIO,
                MAX_SUPPLY
            )
        {} catch Error(string memory reason) {
            emit AssertionFailed(reason);
        }

        /**
            The BondFactory withdraws this collateral when creating a bond under
            normal circumstances, but we are initializing the bond directly here.
        */
        collateralToken.transfer(
            address(bond),
            (MAX_SUPPLY * COLLATERAL_RATIO) / ONE
        );
        paymentToken.transfer(address(this), MAX_SUPPLY);
    }

    function approvePaymentTokenForBond() public {
        paymentToken.approve(address(bond), MAX_INT);
    }

    function convertBonds(uint256 amount) public {
        amount = amount % MAX_SUPPLY;
        uint256 sharesOwned = bond.balanceOf(address(this));

        if (sharesOwned < amount || block.timestamp >= maturity) {
            try bond.convert(amount) {
                emit AssertionFailed("convertBonds//did not revert");
            } catch {}
        } else {
            try bond.convert(amount) {} catch Error(string memory reason) {
                emit AssertionFailed(reason);
            }
            if (bond.balanceOf(address(this)) != sharesOwned - amount) {
                emit AssertionFailed("convertBonds//bond invariant");
            }
        }

        checkGeneralInvariants();
    }

    function payPayment(uint256 amount) public {
        amount = amount % MAX_SUPPLY;
        if (
            paymentToken.allowance(address(this), address(bond)) > amount &&
            paymentToken.balanceOf(address(this)) > amount
        ) {
            try bond.pay(amount) {} catch Error(string memory reason) {
                emit AssertionFailed(reason);
            }
            if (paymentToken.balanceOf(address(bond)) > bond.totalSupply()) {
                emit AssertionFailed("payPayment//payment invariant");
            }
        }

        checkGeneralInvariants();
    }

    function redeemBonds(uint256 amountToRedeem) public {
        if (
            bond.balanceOf(address(this)) < amountToRedeem ||
            block.timestamp < maturity
        ) {
            try bond.redeem(amountToRedeem) {
                emit AssertionFailed("redeemBonds//did not revert");
            } catch {}
        } else {
            try bond.redeem(amountToRedeem) {} catch Error(
                string memory reason
            ) {
                emit AssertionFailed(reason);
            }
        }
        checkGeneralInvariants();
    }

    function withdrawExcessCollateral() public {
        try
            bond.withdrawExcessCollateral(
                bond.previewWithdrawExcessCollateral(),
                msg.sender
            )
        {} catch Error(string memory reason) {
            emit AssertionFailed(reason);
        }
        checkGeneralInvariants();
    }

    function checkGeneralInvariants() internal {
        if (bond.totalSupply() > MAX_SUPPLY) {
            emit AssertionFailed("generalInvariants//max supply invariant");
        }
        if (
            collateralToken.balanceOf(address(bond)) <
            (bond.totalSupply() * COLLATERAL_RATIO) / ONE
        ) {
            emit AssertionFailed("generalInvariants//collateral invariant");
        }
    }
}
