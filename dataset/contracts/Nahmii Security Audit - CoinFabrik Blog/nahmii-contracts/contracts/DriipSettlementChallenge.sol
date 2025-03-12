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
import {Challenge} from "./Challenge.sol";
import {Validatable} from "./Validatable.sol";
import {WalletLockable} from "./WalletLockable.sol";
import {SafeMathIntLib} from "./SafeMathIntLib.sol";
import {SafeMathUintLib} from "./SafeMathUintLib.sol";
import {DriipSettlementDispute} from "./DriipSettlementDispute.sol";
import {MonetaryTypesLib} from "./MonetaryTypesLib.sol";
import {NahmiiTypesLib} from "./NahmiiTypesLib.sol";
import {SettlementTypesLib} from "./SettlementTypesLib.sol";

/**
 * @title DriipSettlementChallenge
 * @notice Where driip settlements are started and challenged
 */
contract DriipSettlementChallenge is Ownable, Challenge, Validatable, WalletLockable {
    using SafeMathIntLib for int256;
    using SafeMathUintLib for uint256;

    //
    // Variables
    // -----------------------------------------------------------------------------------------------------------------
    DriipSettlementDispute public driipSettlementDispute;

    address[] public challengeWallets;
    mapping(address => bool) challengeByWallets;

    SettlementTypesLib.ProposalThick[] public proposals;
    mapping(address => mapping(address => mapping(uint256 => uint256))) public proposalIndexByWalletCurrency;
    mapping(address => uint256[]) public proposalIndicesByWallet;

    bytes32[] public challengeTradeHashes;
    mapping(address => uint256[]) public challengeTradeHashIndicesByWallet;

    bytes32[] public challengePaymentHashes;
    mapping(address => uint256[]) public challengePaymentHashIndicesByWallet;

    //
    // Events
    // -----------------------------------------------------------------------------------------------------------------
    event SetDriipSettlementDisputeEvent(DriipSettlementDispute oldDriipSettlementDispute,
        DriipSettlementDispute newDriipSettlementDispute);
    event StartChallengeFromTradeEvent(address wallet, bytes32 tradeHash,
        int256 intendedStageAmount, int256 conjugateStageAmount);
    event StartChallengeFromTradeByProxyEvent(address proxy, address wallet, bytes32 tradeHash,
        int256 intendedStageAmount, int256 conjugateStageAmount);
    event StartChallengeFromPaymentEvent(address wallet, bytes32 paymentHash, int256 stageAmount);
    event StartChallengeFromPaymentByProxyEvent(address proxy, address wallet, bytes32 paymentHash,
        int256 stageAmount);
    event DisqualifyProposalEvent(address challengedWallet, address currencyCt, uint256 currencyId,
        address challengerWallet, bytes32 candidateHash, SettlementTypesLib.CandidateType candidateType);
    event QualifyProposalEvent(address challengedWallet, address currencyCt, uint256 currencyId,
        address challengerWallet, bytes32 candidateHash, SettlementTypesLib.CandidateType candidateType);

    //
    // Constructor
    // -----------------------------------------------------------------------------------------------------------------
    constructor(address deployer) Ownable(deployer) public {
    }

    //
    // Functions
    // -----------------------------------------------------------------------------------------------------------------
    /// @notice Set the settlement dispute contract
    /// @param newDriipSettlementDispute The (address of) DriipSettlementDispute contract instance
    function setDriipSettlementDispute(DriipSettlementDispute newDriipSettlementDispute)
    public
    onlyDeployer
    notNullAddress(newDriipSettlementDispute)
    {
        DriipSettlementDispute oldDriipSettlementDispute = driipSettlementDispute;
        driipSettlementDispute = newDriipSettlementDispute;
        emit SetDriipSettlementDisputeEvent(oldDriipSettlementDispute, driipSettlementDispute);
    }

    /// @notice Get the number of challenge wallets, i.e. wallets that have started driip settlement challenge
    /// @return The number of challenge wallets
    function challengeWalletsCount()
    public
    view
    returns (uint256)
    {
        return challengeWallets.length;
    }

    /// @notice Get the number of proposals
    /// @return The number of proposals
    function proposalsCount()
    public
    view
    returns (uint256)
    {
        return proposals.length;
    }

    /// @notice Get the number of challenged trade hashes
    /// @return The count of challenged trade hashes
    function challengeTradeHashesCount()
    public
    view
    returns (uint256)
    {
        return challengeTradeHashes.length;
    }

    /// @notice Get the number of challenged payment hashes
    /// @return The count of challenged payment hashes
    function challengePaymentHashesCount()
    public
    view
    returns (uint256)
    {
        return challengePaymentHashes.length;
    }

    /// @notice Get the number of current and past settlement challenges from trade for given wallet
    /// @param wallet The wallet for which to return count
    /// @return The count of settlement challenges from trade
    function walletChallengeTradeHashIndicesCount(address wallet)
    public
    view
    returns (uint256)
    {
        return challengeTradeHashIndicesByWallet[wallet].length;
    }

    /// @notice Get the number of current and past settlement challenges from payment for given wallet
    /// @param wallet The wallet for which to return count
    /// @return The count of settlement challenges from payment
    function walletChallengePaymentHashIndicesCount(address wallet)
    public
    view
    returns (uint256)
    {
        return challengePaymentHashIndicesByWallet[wallet].length;
    }

    /// @notice Start settlement challenge on trade
    /// @param trade The challenged trade
    /// @param intendedStageAmount Amount of intended currency to be staged
    /// @param conjugateStageAmount Amount of conjugate currency to be staged
    function startChallengeFromTrade(NahmiiTypesLib.Trade trade, int256 intendedStageAmount,
        int256 conjugateStageAmount)
    public
    {
        // Require that wallet is not temporarily disqualified
        require(!walletLocker.isLocked(msg.sender));

        // Start challenge
        _startChallengeFromTrade(msg.sender, trade, intendedStageAmount, conjugateStageAmount, true);

        // Emit event
        emit StartChallengeFromTradeEvent(msg.sender, trade.seal.hash, intendedStageAmount, conjugateStageAmount);
    }

    /// @notice Start settlement challenge on trade by proxy
    /// @param wallet The concerned party
    /// @param trade The challenged trade
    /// @param intendedStageAmount Amount of intended currency to be staged
    /// @param conjugateStageAmount Amount of conjugate currency to be staged
    function startChallengeFromTradeByProxy(address wallet, NahmiiTypesLib.Trade trade, int256 intendedStageAmount,
        int256 conjugateStageAmount)
    public
    onlyOperator
    {
        // Start challenge for wallet
        _startChallengeFromTrade(wallet, trade, intendedStageAmount, conjugateStageAmount, false);

        // Emit event
        emit StartChallengeFromTradeByProxyEvent(msg.sender, wallet, trade.seal.hash, intendedStageAmount, conjugateStageAmount);
    }

    /// @notice Start settlement challenge on payment
    /// @param payment The challenged payment
    /// @param stageAmount Amount of payment currency to be staged
    function startChallengeFromPayment(NahmiiTypesLib.Payment payment, int256 stageAmount)
    public
    {
        // Require that wallet is not temporarily disqualified
        require(!walletLocker.isLocked(msg.sender));

        // Start challenge for wallet
        _startChallengeFromPayment(msg.sender, payment, stageAmount, true);

        // Emit event
        emit StartChallengeFromPaymentEvent(msg.sender, payment.seals.operator.hash, stageAmount);
    }

    /// @notice Start settlement challenge on payment
    /// @param wallet The concerned party
    /// @param payment The challenged payment
    /// @param stageAmount Amount of payment currency to be staged
    function startChallengeFromPaymentByProxy(address wallet, NahmiiTypesLib.Payment payment, int256 stageAmount)
    public
    onlyOperator
    {
        // Start challenge for wallet
        _startChallengeFromPayment(wallet, payment, stageAmount, false);

        // Emit event
        emit StartChallengeFromPaymentByProxyEvent(msg.sender, wallet, payment.seals.operator.hash, stageAmount);
    }

    /// @notice Gauge whether the proposal for the given wallet and currency has expired
    /// @param wallet The address of the concerned wallet
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    /// @return true if proposal has expired, else false
    function hasProposalExpired(address wallet, address currencyCt, uint256 currencyId)
    public
    view
    returns (bool)
    {
        // 1-based index
        uint256 index = proposalIndexByWalletCurrency[wallet][currencyCt][currencyId];
        return (
        0 == index ||
        0 == proposals[index - 1].nonce ||
        block.timestamp >= proposals[index - 1].expirationTime
        );
    }

    /// @notice Get the challenge nonce of the given wallet
    /// @param wallet The address of the concerned wallet
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    /// @return The challenge nonce
    function proposalNonce(address wallet, address currencyCt, uint256 currencyId)
    public
    view
    returns (uint256)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currencyCt][currencyId];
        require(0 != index);
        return proposals[index - 1].nonce;
    }

    /// @notice Get the settlement proposal block number of the given wallet
    /// @param wallet The address of the concerned wallet
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    /// @return The settlement proposal block number
    function proposalBlockNumber(address wallet, address currencyCt, uint256 currencyId)
    public
    view
    returns (uint256)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currencyCt][currencyId];
        require(0 != index);
        return proposals[index - 1].blockNumber;
    }

    /// @notice Get the settlement proposal end time of the given wallet
    /// @param wallet The address of the concerned wallet
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    /// @return The settlement proposal end time
    function proposalExpirationTime(address wallet, address currencyCt, uint256 currencyId)
    public
    view
    returns (uint256)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currencyCt][currencyId];
        require(0 != index);
        return proposals[index - 1].expirationTime;
    }

    /// @notice Get the challenge status of the given wallet
    /// @param wallet The address of the concerned wallet
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    /// @return The challenge status
    function proposalStatus(address wallet, address currencyCt, uint256 currencyId)
    public
    view
    returns (SettlementTypesLib.Status)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currencyCt][currencyId];
        require(0 != index);
        return proposals[index - 1].status;
    }

    /// @notice Get the settlement proposal stage amount of the given wallet and currency
    /// @param wallet The address of the concerned wallet
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    /// @return The settlement proposal stage amount
    function proposalStageAmount(address wallet, address currencyCt, uint256 currencyId)
    public
    view
    returns (int256)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currencyCt][currencyId];
        require(0 != index);
        return proposals[index - 1].stageAmount;
    }

    /// @notice Get the settlement proposal target balance amount of the given wallet and currency
    /// @param wallet The address of the concerned wallet
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    /// @return The settlement proposal target balance amount
    function proposalTargetBalanceAmount(address wallet, address currencyCt, uint256 currencyId)
    public
    view
    returns (int256)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currencyCt][currencyId];
        require(0 != index);
        return proposals[index - 1].targetBalanceAmount;
    }

    /// @notice Get the settlement proposal driip hash of the given wallet and currency
    /// @param wallet The address of the concerned wallet
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    /// @return The settlement proposal driip hash
    function proposalDriipHash(address wallet, address currencyCt, uint256 currencyId)
    public
    view
    returns (bytes32)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currencyCt][currencyId];
        require(0 != index);
        return proposals[index - 1].driipHash;
    }

    /// @notice Get the settlement proposal driip type of the given wallet and currency
    /// @param wallet The address of the concerned wallet
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    /// @return The settlement proposal driip type
    function proposalDriipType(address wallet, address currencyCt, uint256 currencyId)
    public
    view
    returns (NahmiiTypesLib.DriipType)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currencyCt][currencyId];
        require(0 != index);
        return proposals[index - 1].driipType;
    }

    /// @notice Get the balance reward of the given wallet's settlement proposal
    /// @param wallet The address of the concerned wallet
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    /// @return The balance reward of the settlement proposal
    function proposalBalanceReward(address wallet, address currencyCt, uint256 currencyId)
    public
    view
    returns (bool)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currencyCt][currencyId];
        require(0 != index);
        return proposals[index - 1].balanceReward;
    }

    /// @notice Get the disqualification challenger of the given wallet and currency
    /// @param wallet The address of the concerned wallet
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    /// @return The challenger of the settlement disqualification
    function proposalDisqualificationChallenger(address wallet, address currencyCt, uint256 currencyId)
    public
    view
    returns (address)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currencyCt][currencyId];
        require(0 != index);
        return proposals[index - 1].disqualification.challenger;
    }

    /// @notice Get the disqualification block number of the given wallet and currency
    /// @param wallet The address of the concerned wallet
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    /// @return The block number of the settlement disqualification
    function proposalDisqualificationBlockNumber(address wallet, address currencyCt, uint256 currencyId)
    public
    view
    returns (uint256)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currencyCt][currencyId];
        require(0 != index);
        return proposals[index - 1].disqualification.blockNumber;
    }

    /// @notice Get the disqualification candidate type of the given wallet and currency
    /// @param wallet The address of the concerned wallet
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    /// @return The candidate type of the settlement disqualification
    function proposalDisqualificationCandidateType(address wallet, address currencyCt, uint256 currencyId)
    public
    view
    returns (SettlementTypesLib.CandidateType)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currencyCt][currencyId];
        require(0 != index);
        return proposals[index - 1].disqualification.candidateType;
    }

    /// @notice Get the disqualification candidate hash of the given wallet and currency
    /// @param wallet The address of the concerned wallet
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    /// @return The candidate hash of the settlement disqualification
    function proposalDisqualificationCandidateHash(address wallet, address currencyCt, uint256 currencyId)
    public
    view
    returns (bytes32)
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currencyCt][currencyId];
        require(0 != index);
        return proposals[index - 1].disqualification.candidateHash;
    }

    /// @notice Set settlement proposal end time property of the given wallet
    /// @dev This function can only be called by this contract's dispute instance
    /// @param wallet The address of the concerned wallet
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    /// @param expirationTime The end time value
    function setProposalExpirationTime(address wallet, address currencyCt, uint256 currencyId,
        uint256 expirationTime)
    public
    onlyDriipSettlementDispute
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currencyCt][currencyId];
        require(0 != index);
        proposals[index - 1].expirationTime = expirationTime;
    }

    /// @notice Set settlement proposal status property of the given wallet
    /// @dev This function can only be called by this contract's dispute instance
    /// @param wallet The address of the concerned wallet
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    /// @param status The status value
    function setProposalStatus(address wallet, address currencyCt, uint256 currencyId,
        SettlementTypesLib.Status status)
    public
    onlyDriipSettlementDispute
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currencyCt][currencyId];
        require(0 != index);
        proposals[index - 1].status = status;
    }

    /// @notice Set settlement proposal block number property of the given wallet
    /// @dev This function can only be called by this contract's dispute instance
    /// @param wallet The address of the concerned wallet
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    /// @param blockNumber The block number value
    function setProposalBlockNumber(address wallet, address currencyCt, uint256 currencyId,
        uint256 blockNumber)
    public
    onlyDriipSettlementDispute
    {
        uint256 index = proposalIndexByWalletCurrency[wallet][currencyCt][currencyId];
        require(0 != index);
        proposals[index - 1].blockNumber = blockNumber;
    }

    /// @notice Disqualify a proposal
    /// @dev A call to this function will intentionally override previous disqualifications if existent
    /// @param challengedWallet The address of the concerned challenged wallet
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    /// @param challengerWallet The address of the concerned challenger wallet
    /// @param blockNumber The disqualification block number
    /// @param candidateHash The candidate hash
    /// @param candidateType The candidate type
    function disqualifyProposal(address challengedWallet, address currencyCt, uint256 currencyId, address challengerWallet,
        uint256 blockNumber, bytes32 candidateHash, SettlementTypesLib.CandidateType candidateType)
    public
    onlyDriipSettlementDispute
    {
        // Get the proposal index
        uint256 index = proposalIndexByWalletCurrency[challengedWallet][currencyCt][currencyId];
        require(0 != index);

        // Require that candidate it at greater block height than any existent disqualification
        require(blockNumber > proposals[index - 1].disqualification.blockNumber);

        // Update proposal
        proposals[index - 1].status = SettlementTypesLib.Status.Disqualified;
        proposals[index - 1].expirationTime = block.timestamp.add(configuration.settlementChallengeTimeout());
        proposals[index - 1].disqualification.challenger = challengerWallet;
        proposals[index - 1].disqualification.blockNumber = blockNumber;
        proposals[index - 1].disqualification.candidateHash = candidateHash;
        proposals[index - 1].disqualification.candidateType = candidateType;

        // Emit event
        emit DisqualifyProposalEvent(
            challengedWallet, currencyCt, currencyId, challengerWallet, candidateHash, candidateType
        );
    }

    /// @notice (Re)Qualify a proposal
    /// @param wallet The address of the concerned challenged wallet
    /// @param currencyCt The address of the concerned currency contract (address(0) == ETH)
    /// @param currencyId The ID of the concerned currency (0 for ETH and ERC20)
    function qualifyProposal(address wallet, address currencyCt, uint256 currencyId)
    public
    onlyDriipSettlementDispute
    {
        // Get the proposal index
        uint256 index = proposalIndexByWalletCurrency[wallet][currencyCt][currencyId];
        require(0 != index);

        // Require that proposal has been previously disqualified
        require(SettlementTypesLib.Status.Disqualified == proposals[index - 1].status);

        // Emit event
        emit QualifyProposalEvent(
            wallet, currencyCt, currencyId,
            proposals[index - 1].disqualification.challenger,
            proposals[index - 1].disqualification.candidateHash,
            proposals[index - 1].disqualification.candidateType
        );

        // Update proposal
        proposals[index - 1].status = SettlementTypesLib.Status.Qualified;
        proposals[index - 1].expirationTime = block.timestamp.add(configuration.settlementChallengeTimeout());
        delete proposals[index - 1].disqualification;
    }

    /// @notice Challenge the settlement by providing order candidate
    /// @param order The order candidate that challenges the challenged driip
    function challengeByOrder(NahmiiTypesLib.Order order)
    public
    onlyOperationalModeNormal
    {
        driipSettlementDispute.challengeByOrder(order, msg.sender);
    }

    /// @notice Unchallenge settlement by providing trade that shows that challenge order candidate has been filled
    /// @param order The order candidate that challenged driip
    /// @param trade The trade in which order has been filled
    function unchallengeOrderCandidateByTrade(NahmiiTypesLib.Order order, NahmiiTypesLib.Trade trade)
    public
    onlyOperationalModeNormal
    {
        driipSettlementDispute.unchallengeOrderCandidateByTrade(order, trade, msg.sender);
    }

    /// @notice Challenge the settlement by providing trade candidate
    /// @param wallet The wallet whose settlement is being challenged
    /// @param trade The trade candidate that challenges the challenged driip
    function challengeByTrade(address wallet, NahmiiTypesLib.Trade trade)
    public
    onlyOperationalModeNormal
    {
        driipSettlementDispute.challengeByTrade(wallet, trade, msg.sender);
    }

    /// @notice Challenge the settlement by providing payment candidate
    /// @param wallet The wallet whose settlement is being challenged
    /// @param payment The payment candidate that challenges the challenged driip
    function challengeByPayment(address wallet, NahmiiTypesLib.Payment payment)
    public
    onlyOperationalModeNormal
    {
        driipSettlementDispute.challengeByPayment(wallet, payment, msg.sender);
    }

    //
    // Private functions
    // -----------------------------------------------------------------------------------------------------------------
    function _startChallengeFromTrade(address wallet, NahmiiTypesLib.Trade trade,
        int256 intendedStageAmount, int256 conjugateStageAmount, bool balanceReward)
    private
    onlySealedTrade(trade)
    {
        // Require that current block number is beyond the earliest settlement challenge block number
        require(block.number >= configuration.earliestSettlementBlockNumber());

        // Require that given wallet is a trade party
        require(validator.isTradeParty(trade, wallet));

        // Require that wallet has no overlap with active proposals
        require(hasProposalExpired(
                wallet, trade.currencies.intended.ct, trade.currencies.intended.id
            ));
        require(hasProposalExpired(
                wallet, trade.currencies.conjugate.ct, trade.currencies.conjugate.id
            ));

        // Create proposals
        _addIntendedProposalFromTrade(wallet, trade, intendedStageAmount, balanceReward);
        _addConjugateProposalFromTrade(wallet, trade, conjugateStageAmount, balanceReward);

        // Add wallet to store of challenge wallets
        _addToChallengeWallets(wallet);

        // Store driip hashes
        challengeTradeHashes.push(trade.seal.hash);
        challengeTradeHashIndicesByWallet[wallet].push(challengeTradeHashes.length);
    }

    function _startChallengeFromPayment(address wallet, NahmiiTypesLib.Payment payment,
        int256 stageAmount, bool balanceReward)
    private
    onlySealedPayment(payment)
    {
        // Require that current block number is beyond the earliest settlement challenge block number
        require(block.number >= configuration.earliestSettlementBlockNumber());

        // Require that given wallet is a payment party
        require(validator.isPaymentParty(payment, wallet));

        // Require that wallet has no overlap with active proposal
        require(hasProposalExpired(
                wallet, payment.currency.ct, payment.currency.id
            ));

        // Create proposal
        _addProposalFromPayment(wallet, payment, stageAmount, balanceReward);

        // Add wallet to store of challenge wallets
        _addToChallengeWallets(wallet);

        // Store driip hashes
        challengePaymentHashes.push(payment.seals.operator.hash);
        challengePaymentHashIndicesByWallet[wallet].push(challengePaymentHashes.length);
    }

    function _addIntendedProposalFromTrade(address wallet, NahmiiTypesLib.Trade trade, int256 stageAmount, bool balanceReward)
    private
    {
        _addProposalFromTrade(
            wallet, trade, stageAmount,
            validator.isTradeBuyer(trade, wallet) ? trade.buyer.balances.intended.current : trade.seller.balances.intended.current,
            trade.currencies.intended, balanceReward
        );
    }

    function _addConjugateProposalFromTrade(address wallet, NahmiiTypesLib.Trade trade, int256 stageAmount, bool balanceReward)
    private
    {
        _addProposalFromTrade(
            wallet, trade, stageAmount,
            validator.isTradeBuyer(trade, wallet) ? trade.buyer.balances.conjugate.current : trade.seller.balances.conjugate.current,
            trade.currencies.conjugate, balanceReward
        );
    }

    function _addProposalFromTrade(address wallet, NahmiiTypesLib.Trade trade, int256 stageAmount,
        int256 balanceAmount, MonetaryTypesLib.Currency currency, bool balanceReward)
    private
    {
        // Require that stage amount is positive
        require(stageAmount.isPositiveInt256());

        // Require that balance amount is not less than stage amount
        require(balanceAmount >= stageAmount);

        // Create proposal
        proposals.length++;

        // Populate proposal
        proposals[proposals.length - 1].wallet = wallet;
        proposals[proposals.length - 1].nonce = trade.nonce;
        proposals[proposals.length - 1].blockNumber = trade.blockNumber;
        proposals[proposals.length - 1].expirationTime = block.timestamp.add(configuration.settlementChallengeTimeout());
        proposals[proposals.length - 1].status = SettlementTypesLib.Status.Qualified;
        proposals[proposals.length - 1].currency = currency;
        proposals[proposals.length - 1].stageAmount = stageAmount;
        proposals[proposals.length - 1].targetBalanceAmount = balanceAmount.sub(stageAmount);
        proposals[proposals.length - 1].driipHash = trade.seal.hash;
        proposals[proposals.length - 1].driipType = NahmiiTypesLib.DriipType.Trade;
        proposals[proposals.length - 1].balanceReward = balanceReward;

        // Store proposal index
        proposalIndexByWalletCurrency[wallet][currency.ct][currency.id] = proposals.length;
        proposalIndicesByWallet[wallet].push(proposals.length);
    }

    function _addProposalFromPayment(address wallet, NahmiiTypesLib.Payment payment, int256 stageAmount,
        bool balanceReward)
    private
    {
        // Require that stage amount is positive
        require(stageAmount.isPositiveInt256());

        // Deduce the concerned balance amount
        int256 balanceAmount = (
        validator.isPaymentSender(payment, wallet) ?
        payment.sender.balances.current :
        payment.recipient.balances.current
        );

        // Require that balance amount is not less than stage amount
        require(balanceAmount >= stageAmount);

        // Create proposal
        proposals.length++;

        // Populate proposal
        proposals[proposals.length - 1].wallet = wallet;
        proposals[proposals.length - 1].nonce = payment.nonce;
        proposals[proposals.length - 1].blockNumber = payment.blockNumber;
        proposals[proposals.length - 1].expirationTime = block.timestamp.add(configuration.settlementChallengeTimeout());
        proposals[proposals.length - 1].status = SettlementTypesLib.Status.Qualified;
        proposals[proposals.length - 1].currency = payment.currency;
        proposals[proposals.length - 1].stageAmount = stageAmount;
        proposals[proposals.length - 1].targetBalanceAmount = balanceAmount.sub(stageAmount);
        proposals[proposals.length - 1].driipHash = payment.seals.operator.hash;
        proposals[proposals.length - 1].driipType = NahmiiTypesLib.DriipType.Payment;
        proposals[proposals.length - 1].balanceReward = balanceReward;

        // Store proposal index
        proposalIndexByWalletCurrency[wallet][payment.currency.ct][payment.currency.id] = proposals.length;
        proposalIndicesByWallet[wallet].push(proposals.length);
    }

    function _addToChallengeWallets(address wallet)
    private
    {
        if (!challengeByWallets[wallet]) {
            challengeByWallets[wallet] = true;
            challengeWallets.push(wallet);
        }
    }

    //
    // Modifiers
    // -----------------------------------------------------------------------------------------------------------------
    modifier onlyDriipSettlementDispute() {
        require(msg.sender == address(driipSettlementDispute));
        _;
    }
}
