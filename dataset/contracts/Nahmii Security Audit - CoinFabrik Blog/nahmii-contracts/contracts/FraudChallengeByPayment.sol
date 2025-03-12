/*
 * Hubii Nahmii
 *
 * Compliant with the Hubii Nahmii specification v0.12.
 *
 * Copyright (C) 2017-2018 Hubii AS
 */

pragma solidity ^0.4.25;
pragma experimental ABIEncoderV2;

import {Ownable} from "./Ownable.sol";
import {FraudChallengable} from "./FraudChallengable.sol";
import {Challenge} from "./Challenge.sol";
import {Validatable} from "./Validatable.sol";
import {SecurityBondable} from "./SecurityBondable.sol";
import {WalletLockable} from "./WalletLockable.sol";
import {NahmiiTypesLib} from "./NahmiiTypesLib.sol";

/**
 * @title FraudChallengeByPayment
 * @notice Where driips are challenged wrt fraud by mismatch in single trade property values
 */
contract FraudChallengeByPayment is Ownable, FraudChallengable, Challenge, Validatable,
SecurityBondable, WalletLockable {
    //
    // Events
    // -----------------------------------------------------------------------------------------------------------------
    event ChallengeByPaymentEvent(bytes32 paymentHash, address challenger,
        address lockedSender, address lockedRecipient);

    //
    // Constructor
    // -----------------------------------------------------------------------------------------------------------------
    constructor(address deployer) Ownable(deployer) public {
    }

    //
    // Functions
    // -----------------------------------------------------------------------------------------------------------------
    /// @notice Submit a payment candidate in continuous Fraud Challenge (FC)
    /// @param payment Fraudulent payment candidate
    function challenge(NahmiiTypesLib.Payment payment)
    public
    onlyOperationalModeNormal
    onlyOperatorSealedPayment(payment)
    {
        require(validator.isGenuinePaymentWalletHash(payment));

        // Genuineness affected by wallet not having signed the payment
        bool genuineWalletSignature = validator.isGenuineWalletSignature(
            payment.seals.wallet.hash, payment.seals.wallet.signature, payment.sender.wallet
        );

        // Genuineness affected by sender and recipient
        (bool genuineSenderAndFee, bool genuineRecipient) =
        validator.isPaymentCurrencyNonFungible(payment) ?
        (
            validator.isGenuinePaymentSenderOfNonFungible(payment) && validator.isGenuinePaymentFeeOfNonFungible(payment),
            validator.isGenuinePaymentRecipientOfNonFungible(payment)
        ) :
        (
            validator.isGenuinePaymentSenderOfFungible(payment) && validator.isGenuinePaymentFeeOfFungible(payment),
            validator.isGenuinePaymentRecipientOfFungible(payment)
        );

        // Require existence of fraud signal
        require(!(genuineWalletSignature && genuineSenderAndFee && genuineRecipient));

        // Toggle operational mode exit
        configuration.setOperationalModeExit();

        // Tag payment (hash) as fraudulent
        fraudChallenge.addFraudulentPaymentHash(payment.seals.operator.hash);

        // Reward stake fraction
        securityBond.reward(msg.sender, configuration.fraudStakeFraction(), 0);

        // Lock amount of size equivalent to payment amount of sender
        if (!genuineSenderAndFee)
            walletLocker.lockFungibleByProxy(
                payment.sender.wallet, msg.sender, payment.amount, payment.currency.ct, payment.currency.id
            );

        // Lock amount of size equivalent to payment amount of recipient
        if (!genuineRecipient)
            walletLocker.lockFungibleByProxy(
                payment.recipient.wallet, msg.sender, payment.amount, payment.currency.ct, payment.currency.id
            );

        // Emit event
        emit ChallengeByPaymentEvent(
            payment.seals.operator.hash, msg.sender,
            genuineSenderAndFee ? address(0) : payment.sender.wallet,
            genuineRecipient ? address(0) : payment.recipient.wallet
        );
    }
}