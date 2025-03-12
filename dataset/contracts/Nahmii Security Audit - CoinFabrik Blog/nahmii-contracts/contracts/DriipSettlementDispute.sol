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
import {Configurable} from "./Configurable.sol";
import {Validatable} from "./Validatable.sol";
import {SecurityBondable} from "./SecurityBondable.sol";
import {WalletLockable} from "./WalletLockable.sol";
import {FraudChallengable} from "./FraudChallengable.sol";
import {CancelOrdersChallengable} from "./CancelOrdersChallengable.sol";
import {SafeMathIntLib} from "./SafeMathIntLib.sol";
import {SafeMathUintLib} from "./SafeMathUintLib.sol";
import {MonetaryTypesLib} from "./MonetaryTypesLib.sol";
import {NahmiiTypesLib} from "./NahmiiTypesLib.sol";
import {SettlementTypesLib} from "./SettlementTypesLib.sol";
import {DriipSettlementChallenge} from "./DriipSettlementChallenge.sol";

/**
 * @title DriipSettlementDispute
 * @notice The workhorse of driip settlement challenges, utilized by DriipSettlementChallenge
 */
contract DriipSettlementDispute is Ownable, Configurable, Validatable, SecurityBondable, WalletLockable,
FraudChallengable, CancelOrdersChallengable {
    using SafeMathIntLib for int256;
    using SafeMathUintLib for uint256;

    //
    // Variables
    // -----------------------------------------------------------------------------------------------------------------
    DriipSettlementChallenge public driipSettlementChallenge;

    //
    // Events
    // -----------------------------------------------------------------------------------------------------------------
    event SetDriipSettlementChallengeEvent(DriipSettlementChallenge oldDriipSettlementChallenge,
        DriipSettlementChallenge newDriipSettlementChallenge);
    event ChallengeByOrderEvent(address wallet, uint256 nonce,
        bytes32 driipHash, NahmiiTypesLib.DriipType driipType,
        bytes32 candidateHash, address challenger);
    event UnchallengeOrderCandidateByTradeEvent(address wallet, uint256 nonce,
        bytes32 driipHash, NahmiiTypesLib.DriipType driipType,
        bytes32 challengeCandidateHash, address challenger,
        bytes32 unchallengeCandidateHash, address unchallenger);
    event ChallengeByTradeEvent(address wallet, uint256 nonce,
        bytes32 driipHash, NahmiiTypesLib.DriipType driipType,
        bytes32 candidateHash, address challenger);
    event ChallengeByPaymentEvent(address wallet, uint256 nonce,
        bytes32 driipHash, NahmiiTypesLib.DriipType driipType,
        bytes32 candidateHash, address challenger);

    //
    // Constructor
    // -----------------------------------------------------------------------------------------------------------------
    constructor(address deployer) Ownable(deployer) public {
    }

    /// @notice Set the driip settlement challenge contract
    /// @param newDriipSettlementChallenge The (address of) DriipSettlementChallenge contract instance
    function setDriipSettlementChallenge(DriipSettlementChallenge newDriipSettlementChallenge) public
    onlyDeployer
    notNullAddress(newDriipSettlementChallenge)
    {
        DriipSettlementChallenge oldDriipSettlementChallenge = driipSettlementChallenge;
        driipSettlementChallenge = newDriipSettlementChallenge;
        emit SetDriipSettlementChallengeEvent(oldDriipSettlementChallenge, driipSettlementChallenge);
    }

    /// @notice Challenge the driip settlement by providing order candidate
    /// @param order The order candidate that challenges the challenged driip
    /// @param challenger The address of the challenger
    /// @dev If (candidate) order has buy intention consider _conjugate_ currency and amount, else
    /// if (candidate) order has sell intention consider _intended_ currency and amount
    function challengeByOrder(NahmiiTypesLib.Order order, address challenger) public
    onlyDriipSettlementChallenge
    onlySealedOrder(order)
    {
        // Require that candidate order is not labelled fraudulent or cancelled
        require(!fraudChallenge.isFraudulentOrderHash(order.seals.operator.hash));
        require(!cancelOrdersChallenge.isOrderCancelled(order.wallet, order.seals.operator.hash));

        // Get the relevant currency
        MonetaryTypesLib.Currency memory currency = _orderCurrency(order);

        // Require that proposal has not expired
        require(!driipSettlementChallenge.hasProposalExpired(order.wallet, currency.ct, currency.id));

        // Require that order's block number is not earlier than proposal's block number
        require(order.blockNumber >= driipSettlementChallenge.proposalBlockNumber(
            order.wallet, currency.ct, currency.id
        ));

        // Require that transfer amount is strictly greater than the proposal's target balance amount
        // for this order to be a valid challenge candidate
        require(_orderTransferAmount(order) > driipSettlementChallenge.proposalTargetBalanceAmount(
            order.wallet, currency.ct, currency.id
        ));

        // Reward challenger
        // TODO Need balance as part of order to replace transfer amount (_orderTransferAmount(order)) in call below
        _settleRewards(order.wallet, _orderTransferAmount(order), currency, challenger, configuration.settlementChallengeTimeout());

        // Disqualify proposal, effectively overriding any previous disqualification
        driipSettlementChallenge.disqualifyProposal(
            order.wallet, currency.ct, currency.id, challenger, order.blockNumber,
            order.seals.operator.hash, SettlementTypesLib.CandidateType.Order
        );

        // Emit event
        emit ChallengeByOrderEvent(
            order.wallet,
            driipSettlementChallenge.proposalNonce(order.wallet, currency.ct, currency.id),
            driipSettlementChallenge.proposalDriipHash(order.wallet, currency.ct, currency.id),
            driipSettlementChallenge.proposalDriipType(order.wallet, currency.ct, currency.id),
            driipSettlementChallenge.proposalDisqualificationCandidateHash(order.wallet, currency.ct, currency.id),
            challenger
        );
    }

    /// @notice Unchallenge driip settlement by providing trade that shows that challenge order candidate has been filled
    /// @param order The order candidate that challenged driip
    /// @param trade The trade in which order has been filled
    /// @param unchallenger The address of the unchallenger
    function unchallengeOrderCandidateByTrade(NahmiiTypesLib.Order order, NahmiiTypesLib.Trade trade, address unchallenger)
    public
    onlyDriipSettlementChallenge
    onlySealedOrder(order)
    onlySealedTrade(trade)
    onlyTradeParty(trade, order.wallet)
    {
        // Get the relevant currency
        MonetaryTypesLib.Currency memory currency = _orderCurrency(order);

        // Require that proposal has not expired
        require(!driipSettlementChallenge.hasProposalExpired(order.wallet, currency.ct, currency.id));

        // Require that proposal has been disqualified
        require(SettlementTypesLib.Status.Disqualified == driipSettlementChallenge.proposalStatus(
            order.wallet, currency.ct, currency.id
        ));

        // Require that candidate type is order
        require(SettlementTypesLib.CandidateType.Order == driipSettlementChallenge.proposalDisqualificationCandidateType(
            order.wallet, currency.ct, currency.id
        ));

        // Require that trade and order are not labelled fraudulent
        require(!fraudChallenge.isFraudulentTradeHash(trade.seal.hash));
        require(!fraudChallenge.isFraudulentOrderHash(order.seals.operator.hash));

        bytes32 candidateHash = driipSettlementChallenge.proposalDisqualificationCandidateHash(
            order.wallet, currency.ct, currency.id
        );

        // Require that the order's and trade' order hashes equal the candidate (order's) hash,
        // and implicitly that order's and trade order's hashes equal
        // Order wallet is buyer -> require candidate hash to match buyer's order hash
        // Order wallet is seller -> require candidate hash to match seller's order hash
        require(candidateHash == order.seals.operator.hash);
        require(candidateHash == _tradeOrderHash(trade, order.wallet));

        // Store old challenger
        address challenger = driipSettlementChallenge.proposalDisqualificationChallenger(
            order.wallet, currency.ct, currency.id
        );

        // Unlock wallet's balances or deprive challenger
        if (driipSettlementChallenge.proposalBalanceReward(order.wallet, currency.ct, currency.id))
            walletLocker.unlockFungibleByProxy(order.wallet, challenger, currency.ct, currency.id);
        else
            securityBond.deprive(challenger);

        // Requalify proposal
        driipSettlementChallenge.qualifyProposal(
            order.wallet, currency.ct, currency.id
        );

        // Reward unchallenger
        securityBond.reward(unchallenger, configuration.walletSettlementStakeFraction(), 0);

        // Emit event
        emit UnchallengeOrderCandidateByTradeEvent(
            order.wallet,
            driipSettlementChallenge.proposalNonce(order.wallet, currency.ct, currency.id),
            driipSettlementChallenge.proposalDriipHash(order.wallet, currency.ct, currency.id),
            driipSettlementChallenge.proposalDriipType(order.wallet, currency.ct, currency.id),
            candidateHash, challenger,
            trade.seal.hash, unchallenger
        );
    }

    /// @notice Challenge the driip settlement by providing trade candidate
    /// @param wallet The wallet whose driip settlement is being challenged
    /// @param trade The trade candidate that challenges the challenged driip
    /// @param challenger The address of the challenger
    /// @dev If wallet is buyer in (candidate) trade consider single _conjugate_ transfer in (candidate) trade. Else
    /// if wallet is seller in (candidate) trade consider single _intended_ transfer in (candidate) trade
    function challengeByTrade(address wallet, NahmiiTypesLib.Trade trade, address challenger)
    public
    onlyDriipSettlementChallenge
    onlySealedTrade(trade)
    onlyTradeParty(trade, wallet)
    {
        // Require that trade candidate is not labelled fraudulent
        require(!fraudChallenge.isFraudulentTradeHash(trade.seal.hash));

        // Require that wallet's order in trade is not labelled fraudulent or cancelled
        require(!fraudChallenge.isFraudulentOrderHash(_tradeOrderHash(trade, wallet)));
        require(!cancelOrdersChallenge.isOrderCancelled(wallet, _tradeOrderHash(trade, wallet)));

        // Get the relevant currency
        MonetaryTypesLib.Currency memory currency = _tradeCurrency(trade, wallet);

        // Require that proposal has not expired
        require(!driipSettlementChallenge.hasProposalExpired(wallet, currency.ct, currency.id));

        // Require that trade's block number is not earlier than proposal's block number
        require(trade.blockNumber >= driipSettlementChallenge.proposalBlockNumber(
            wallet, currency.ct, currency.id
        ));

        // Require that transfer amount is strictly greater than the proposal's target balance amount
        // for this trade to be a valid challenge candidate
        require(_tradeTransferAmount(trade, wallet) > driipSettlementChallenge.proposalTargetBalanceAmount(
            wallet, currency.ct, currency.id
        ));

        // Reward challenger
        _settleRewards(wallet, _tradeBalanceAmount(trade, wallet), currency, challenger, 0);

        // Disqualify proposal, effectively overriding any previous disqualification
        driipSettlementChallenge.disqualifyProposal(
            wallet, currency.ct, currency.id, challenger, trade.blockNumber,
            trade.seal.hash, SettlementTypesLib.CandidateType.Trade
        );

        // Emit event
        emit ChallengeByTradeEvent(
            wallet,
            driipSettlementChallenge.proposalNonce(wallet, currency.ct, currency.id),
            driipSettlementChallenge.proposalDriipHash(wallet, currency.ct, currency.id),
            driipSettlementChallenge.proposalDriipType(wallet, currency.ct, currency.id),
            driipSettlementChallenge.proposalDisqualificationCandidateHash(wallet, currency.ct, currency.id),
            challenger
        );
    }

    /// @notice Challenge the driip settlement by providing payment candidate
    /// @dev This challenges the payment sender's side of things
    /// @param wallet The concerned party
    /// @param payment The payment candidate that challenges the challenged driip
    /// @param challenger The address of the challenger
    function challengeByPayment(address wallet, NahmiiTypesLib.Payment payment, address challenger)
    public
    onlyDriipSettlementChallenge
    onlySealedPayment(payment)
    onlyPaymentSender(payment, wallet)
    {
        // Require that payment candidate is not labelled fraudulent
        require(!fraudChallenge.isFraudulentPaymentHash(payment.seals.operator.hash));

        // Require that proposal has not expired
        require(!driipSettlementChallenge.hasProposalExpired(wallet, payment.currency.ct, payment.currency.id));

        // Require that payment candidate's block number is not earlier than proposal's block number
        // TODO Replace by wallet nonce?
        require(payment.blockNumber >= driipSettlementChallenge.proposalBlockNumber(
            wallet, payment.currency.ct, payment.currency.id
        ));

        // Require that transfer amount is strictly greater than the proposal's target balance amount
        // for the provided payment to be a valid challenge candidate.
        require(payment.transfers.single > driipSettlementChallenge.proposalTargetBalanceAmount(
            wallet, payment.currency.ct, payment.currency.id
        ));

        // Reward challenger
        _settleRewards(wallet, payment.sender.balances.current, payment.currency, challenger, 0);

        // Disqualify proposal, effectively overriding any previous disqualification
        driipSettlementChallenge.disqualifyProposal(
            wallet, payment.currency.ct, payment.currency.id, challenger, payment.blockNumber,
            payment.seals.operator.hash, SettlementTypesLib.CandidateType.Payment
        );

        // Emit event
        emit ChallengeByPaymentEvent(
            wallet,
            driipSettlementChallenge.proposalNonce(wallet, payment.currency.ct, payment.currency.id),
            driipSettlementChallenge.proposalDriipHash(wallet, payment.currency.ct, payment.currency.id),
            driipSettlementChallenge.proposalDriipType(wallet, payment.currency.ct, payment.currency.id),
            driipSettlementChallenge.proposalDisqualificationCandidateHash(wallet, payment.currency.ct, payment.currency.id),
            challenger
        );
    }

    //
    // Private functions
    // -----------------------------------------------------------------------------------------------------------------
    // Get the candidate order currency
    // Buy order -> Conjugate currency
    // Sell order -> Intended currency
    function _orderCurrency(NahmiiTypesLib.Order order)
    private
    pure
    returns (MonetaryTypesLib.Currency)
    {
        return NahmiiTypesLib.Intention.Sell == order.placement.intention ?
        order.placement.currencies.intended :
        order.placement.currencies.conjugate;
    }

    // Get the candidate order transfer
    // Buy order -> Conjugate transfer
    // Sell order -> Intended transfer
    function _orderTransferAmount(NahmiiTypesLib.Order order)
    private
    pure
    returns (int256)
    {
        return NahmiiTypesLib.Intention.Sell == order.placement.intention ?
        order.placement.amount :
        order.placement.amount.div(order.placement.rate);
    }

    function _tradeOrderHash(NahmiiTypesLib.Trade trade, address wallet)
    private
    view
    returns (bytes32)
    {
        return validator.isTradeBuyer(trade, wallet) ?
        trade.buyer.order.hashes.operator :
        trade.seller.order.hashes.operator;
    }

    // Get the candidate trade currency
    // Wallet is buyer in (candidate) trade -> Conjugate currency
    // Wallet is seller in (candidate) trade -> Intended currency
    function _tradeCurrency(NahmiiTypesLib.Trade trade, address wallet)
    private
    view
    returns (MonetaryTypesLib.Currency)
    {
        return validator.isTradeBuyer(trade, wallet) ?
        trade.currencies.conjugate :
        trade.currencies.intended;
    }

    // Get the candidate trade transfer amount
    // Wallet is buyer in (candidate) trade -> Conjugate transfer
    // Wallet is seller in (candidate) trade -> Intended transfer
    function _tradeTransferAmount(NahmiiTypesLib.Trade trade, address wallet)
    private
    view
    returns (int256)
    {
        return validator.isTradeBuyer(trade, wallet) ?
        trade.transfers.conjugate.single :
        trade.transfers.intended.single;
    }

    // Get the candidate trade balance amount
    // Wallet is buyer in (candidate) trade -> Buyer's conjugate balance
    // Wallet is seller in (candidate) trade -> Seller's intended balance
    function _tradeBalanceAmount(NahmiiTypesLib.Trade trade, address wallet)
    private
    view
    returns (int256)
    {
        return validator.isTradeBuyer(trade, wallet) ?
        trade.buyer.balances.conjugate.current :
        trade.seller.balances.intended.current;
    }

    // Lock wallet's balances or reward challenger by stake fraction
    function _settleRewards(address wallet, int256 lockAmount, MonetaryTypesLib.Currency currency,
        address challenger, uint256 unlockTimeoutInSeconds)
    private
    {
        if (driipSettlementChallenge.proposalBalanceReward(wallet, currency.ct, currency.id))
            _unlockAndLockWallets(wallet, lockAmount, currency, challenger);

        else
            _depriveAndReward(wallet, currency, challenger, unlockTimeoutInSeconds);
    }

    function _unlockAndLockWallets(address wallet, int256 lockAmount, MonetaryTypesLib.Currency currency,
        address challenger)
    private
    {
        // Unlock wallet/currency for existing challenger if previously locked
        if (SettlementTypesLib.Status.Disqualified == driipSettlementChallenge.proposalStatus(
            wallet, currency.ct, currency.id
        ))
            walletLocker.unlockFungibleByProxy(
                wallet,
                driipSettlementChallenge.proposalDisqualificationChallenger(
                    wallet, currency.ct, currency.id
                ),
                currency.ct, currency.id
            );

        // Lock wallet for new challenger
        walletLocker.lockFungibleByProxy(wallet, challenger, lockAmount, currency.ct, currency.id);
    }

    function _depriveAndReward(address wallet, MonetaryTypesLib.Currency currency, address challenger,
        uint256 unlockTimeoutInSeconds)
    private
    {
        // Deprive existing challenger of reward if previously locked
        if (SettlementTypesLib.Status.Disqualified == driipSettlementChallenge.proposalStatus(
            wallet, currency.ct, currency.id
        ))
            securityBond.deprive(driipSettlementChallenge.proposalDisqualificationChallenger(
                    wallet, currency.ct, currency.id
                ));

        // Reward new challenger
        securityBond.reward(challenger, configuration.operatorSettlementStakeFraction(),
            unlockTimeoutInSeconds);
    }

    //
    // Modifiers
    // -----------------------------------------------------------------------------------------------------------------
    modifier onlyDriipSettlementChallenge() {
        require(msg.sender == address(driipSettlementChallenge));
        _;
    }
}