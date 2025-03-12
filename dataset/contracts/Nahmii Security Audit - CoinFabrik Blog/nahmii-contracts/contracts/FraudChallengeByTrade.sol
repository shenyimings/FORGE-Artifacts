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
import {SafeMathIntLib} from "./SafeMathIntLib.sol";

/**
 * @title FraudChallengeByTrade
 * @notice Where driips are challenged wrt fraud by mismatch in single trade property values
 */
contract FraudChallengeByTrade is Ownable, FraudChallengable, Challenge, Validatable,
SecurityBondable, WalletLockable {
    using SafeMathIntLib for int256;

    //
    // Events
    // -----------------------------------------------------------------------------------------------------------------
    event ChallengeByTradeEvent(bytes32 tradeHash, address challenger, address lockedBuyer, address lockedSeller);

    //
    // Constructor
    // -----------------------------------------------------------------------------------------------------------------
    constructor(address deployer) Ownable(deployer) public {
    }

    //
    // Functions
    // -----------------------------------------------------------------------------------------------------------------
    /// @notice Submit a trade candidate in continuous Fraud Challenge (FC)
    /// @param trade Fraudulent trade candidate
    function challenge(NahmiiTypesLib.Trade trade) public
    onlyOperationalModeNormal
    onlySealedTrade(trade)
    {
        // Genuineness affected by buyer
        bool genuineBuyerAndFee = validator.isTradeIntendedCurrencyNonFungible(trade) ?
        validator.isGenuineTradeBuyerOfNonFungible(trade) && validator.isGenuineTradeBuyerFeeOfNonFungible(trade) :
        validator.isGenuineTradeBuyerOfFungible(trade) && validator.isGenuineTradeBuyerFeeOfFungible(trade);

        // Genuineness affected by seller
        bool genuineSellerAndFee = validator.isTradeConjugateCurrencyNonFungible(trade) ?
        validator.isGenuineTradeSellerOfNonFungible(trade) && validator.isGenuineTradeSellerFeeOfNonFungible(trade) :
        validator.isGenuineTradeSellerOfFungible(trade) && validator.isGenuineTradeSellerFeeOfFungible(trade);

        // Require existence of fraud signal
        require(!(genuineBuyerAndFee && genuineSellerAndFee));

        // Toggle operational mode exit
        configuration.setOperationalModeExit();

        // Tag trade (hash) as fraudulent
        fraudChallenge.addFraudulentTradeHash(trade.seal.hash);

        // Reward stake fraction
        securityBond.reward(msg.sender, configuration.fraudStakeFraction(), 0);

        // Lock amount of size equivalent to trade intended and conjugate amounts of buyer
        if (!genuineBuyerAndFee) {
            walletLocker.lockFungibleByProxy(
                trade.buyer.wallet, msg.sender, trade.amount, trade.currencies.intended.ct, trade.currencies.intended.id
            );
            walletLocker.lockFungibleByProxy(
                trade.buyer.wallet, msg.sender, trade.amount.div(trade.rate), trade.currencies.conjugate.ct, trade.currencies.conjugate.id
            );
        }

        // Lock amount of size equivalent to trade intended and conjugate amounts of seller
        if (!genuineSellerAndFee) {
            walletLocker.lockFungibleByProxy(
                trade.seller.wallet, msg.sender, trade.amount, trade.currencies.intended.ct, trade.currencies.intended.id
            );
            walletLocker.lockFungibleByProxy(
                trade.seller.wallet, msg.sender, trade.amount.div(trade.rate), trade.currencies.conjugate.ct, trade.currencies.conjugate.id
            );
        }

        // Emit event
        emit ChallengeByTradeEvent(
            trade.seal.hash, msg.sender,
            genuineBuyerAndFee ? address(0) : trade.buyer.wallet,
            genuineSellerAndFee ? address(0) : trade.seller.wallet
        );
    }
}