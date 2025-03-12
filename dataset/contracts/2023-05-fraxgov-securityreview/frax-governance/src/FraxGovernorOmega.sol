// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// ========================= FraxGovernorOmega ========================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance

// Primary Author(s)
// Jon Walch: https://github.com/jonwalch

// Contributors
// Jamie Turley: https://github.com/jyturley

// Reviewers
// Drake Evans: https://github.com/DrakeEvans
// Dennis: https://github.com/denett
// Sam Kazemian: https://github.com/samkazemian

// ====================================================================

import { FraxGovernorBase, ConstructorParams as FraxGovernorBaseParams } from "./FraxGovernorBase.sol";
import { IFraxGovernorOmega } from "./interfaces/IFraxGovernorOmega.sol";
import { Enum, ISafe } from "./interfaces/ISafe.sol";

struct SafeConfig {
    address safe;
    uint256 requiredSignatures;
}

struct ConstructorParams {
    address veFxs;
    address veFxsVotingDelegation;
    SafeConfig[] safeConfigs;
    address payable timelockController;
    uint256 initialVotingDelay;
    uint256 initialVotingPeriod;
    uint256 initialProposalThreshold;
    uint256 quorumNumeratorValue;
    uint256 initialVotingDelayBlocks;
    uint256 initialShortCircuitNumerator;
}

/// @title FraxGovernorOmega
/// @author Jon Walch (Frax Finance) https://github.com/jonwalch
/// @notice A Governance contract with intended use as a Gnosis Safe signer. The only Safe interaction this contract does is calling GnosisSafe::approveHash().
/// @notice Supports optimistic proposals for Gnosis Safe transactions, that default to ```ProposalState.Succeeded```, through ```addTransaction()```.
contract FraxGovernorOmega is FraxGovernorBase {
    /// @notice The address of the FraxGovernorAlpha contract
    address public immutable TIMELOCK_CONTROLLER;

    /// @notice Configuration and allowlist for Gnosis Safes approved for use with FraxGovernorOmega
    mapping(address safe => uint256 requiredSignatures) public $safeRequiredSignatures;

    /// @notice Lookup from optimistic proposal proposal id to Gnosis Safe Transaction hash
    mapping(uint256 proposalId => bytes32 txHash) public $optimisticProposalIdToTxHash;

    /// @notice Lookup from Gnosis Safe to nonce to corresponding transaction hash
    mapping(address safe => mapping(uint256 safeNonce => bytes32 txHash)) public $gnosisSafeToNonceToTxHash;

    /// @notice The ```SafeConfigUpdate``` event is emitted when governance changes Gnosis Safe configuration
    /// @param safe The address of the Gnosis Safe
    /// @param oldRequiredSignatures The old amount of required Gnosis Safe signatures to put up for voting
    /// @param newRequiredSignatures The new amount of required Gnosis Safe signatures to put up for voting
    event SafeConfigUpdate(address indexed safe, uint256 oldRequiredSignatures, uint256 newRequiredSignatures);

    /// @notice The ```TransactionProposed``` event is emitted when a Frax Team optimistic proposal is put up for voting
    /// @param safe The address of the Gnosis Safe
    /// @param nonce The nonce corresponding to the safe for this proposal
    /// @param txHash The hash of the Gnosis Safe transaction
    /// @param proposalId The proposal id in FraxGovernorOmega
    /// @param proposer The address that proposed the Transaction
    event TransactionProposed(
        address indexed safe,
        uint256 nonce,
        bytes32 txHash,
        uint256 proposalId,
        address indexed proposer
    );

    /// @notice The ```constructor``` function is called on deployment
    /// @param params ConstructorParams struct
    constructor(
        ConstructorParams memory params
    )
        FraxGovernorBase(
            FraxGovernorBaseParams({
                veFxs: params.veFxs,
                veFxsVotingDelegation: params.veFxsVotingDelegation,
                _name: "FraxGovernorOmega",
                initialVotingDelay: params.initialVotingDelay,
                initialVotingPeriod: params.initialVotingPeriod,
                initialProposalThreshold: params.initialProposalThreshold,
                quorumNumeratorValue: params.quorumNumeratorValue,
                initialVotingDelayBlocks: params.initialVotingDelayBlocks,
                initialShortCircuitNumerator: params.initialShortCircuitNumerator
            })
        )
    {
        TIMELOCK_CONTROLLER = params.timelockController;

        for (uint256 i = 0; i < params.safeConfigs.length; ++i) {
            SafeConfig memory config = params.safeConfigs[i];
            $safeRequiredSignatures[config.safe] = config.requiredSignatures;
            emit SafeConfigUpdate({
                safe: config.safe,
                oldRequiredSignatures: 0,
                newRequiredSignatures: config.requiredSignatures
            });
        }
    }

    /// @notice The ```_requireOnlyGovernorAlpha``` function checks if the caller is FraxGovernorAlpha
    function _requireOnlyTimelockController() internal view {
        if (msg.sender != TIMELOCK_CONTROLLER) revert IFraxGovernorOmega.NotTimelockController();
    }

    /// @notice The ```_requireAllowlist``` function checks if the safe has more than 0 requiredSignatures, which means it is allowlisted.
    /// @param safe The address of the Gnosis Safe
    function _requireAllowlist(address safe) internal view {
        if ($safeRequiredSignatures[safe] == 0) revert Unauthorized();
    }

    /// @notice The ```_requireEoaSignatures``` function checks if the provided signatures are EOA signatures
    /// @dev Disallow the ```v == 0```` and ```v == 1``` cases of ```safe.checkNSignatures()```. This ensures that the signatures passed
    /// @dev in are from EOAs and disallows the implicit signing from Omega with the ```msg.sender == currentOwner``` case.
    /// @param safe The address of the Gnosis Safe
    /// @param signatures 1 or more packed signature data ({bytes32 r}{bytes32 s}{uint8 v})
    function _requireEoaSignatures(address safe, bytes memory signatures) internal view {
        uint8 v;
        uint256 i;

        for (i = 0; i < $safeRequiredSignatures[safe]; ++i) {
            // Taken from Gnosis Safe SignatureDecoder
            /// @solidity memory-safe-assembly
            assembly {
                let signaturePos := mul(0x41, i)
                v := and(mload(add(signatures, add(signaturePos, 0x41))), 0xff)
            }
            if (v < 2) {
                revert IFraxGovernorOmega.WrongSafeSignatureType();
            }
        }
    }

    /// @dev Internal helper function for optimistic proposals
    function _optimisticProposalArgs(
        address safe,
        bytes32 txHash
    ) internal pure returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);

        targets[0] = safe;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(ISafe.approveHash.selector, txHash);
    }

    /// @dev Exists solely to avoid stack too deep errors in ```addTransaction()```
    /// @return txHash Gnosis Safe transaction hash
    function _safeGetTransactionHash(
        ISafe safe,
        IFraxGovernorOmega.TxHashArgs memory args
    ) internal view returns (bytes32 txHash) {
        txHash = safe.getTransactionHash({
            to: args.to,
            value: args.value,
            data: args.data,
            operation: args.operation,
            safeTxGas: args.safeTxGas,
            baseGas: args.baseGas,
            gasPrice: args.gasPrice,
            gasToken: args.gasToken,
            refundReceiver: args.refundReceiver,
            _nonce: args._nonce
        });
    }

    /// @notice The ```propose``` function reverts when called
    /// @dev Gnosis Safe owners should sign a Gnosis Transaction and then it can be proposed using ```addTransaction()```
    /// @dev Cannot recover assets accidentally sent to this contract
    function propose(
        address[] memory, // targets
        uint256[] memory, // values
        bytes[] memory, // calldatas
        string memory // description
    ) public pure override returns (uint256) {
        revert IFraxGovernorOmega.CannotPropose();
    }

    /// @notice The ```cancel``` function reverts when called
    /// @dev Optimistic proposals can be cancelled by Frax Team using ```abortTransaction()```
    function cancel(
        address[] memory, // targets
        uint256[] memory, // values
        bytes[] memory, // calldatas
        bytes32 // descriptionHash
    ) public pure override returns (uint256) {
        revert IFraxGovernorOmega.CannotCancelOptimisticTransaction();
    }

    /// @notice The ```addTransaction``` function creates optimistic proposals that correspond to a Gnosis Safe Transaction that was initiated by the Frax Team
    /// @param teamSafe Address of allowlisted Gnosis Safe
    /// @param args TxHashArgs of the Gnosis Safe transaction
    /// @param signatures EOA signatures for the Gnosis Safe transaction
    /// @return optimisticProposalId Proposal ID of optimistic proposal created
    function addTransaction(
        address teamSafe,
        IFraxGovernorOmega.TxHashArgs calldata args,
        bytes calldata signatures
    ) public returns (uint256 optimisticProposalId) {
        _requireEoaSignatures({ safe: teamSafe, signatures: signatures });
        // This check stops EOA Safe owners from pushing txs through that skip the more stringent FraxGovernorAlpha
        // procedures. It disallows Omega from calling safe.approveHash() outside of the
        // addTransaction() / execute() / rejectTransaction() flow
        if (args.to == teamSafe) {
            revert IFraxGovernorOmega.DisallowedTarget(args.to);
        }
        _requireAllowlist(teamSafe);
        if ($gnosisSafeToNonceToTxHash[teamSafe][args._nonce] != 0) revert IFraxGovernorOmega.NonceReserved();
        ISafe safe = ISafe(teamSafe);
        if (args._nonce < safe.nonce()) revert IFraxGovernorOmega.WrongNonce();

        bytes32 txHash = _safeGetTransactionHash({ safe: safe, args: args });

        safe.checkNSignatures({
            dataHash: txHash,
            data: args.data,
            signatures: signatures,
            requiredSignatures: $safeRequiredSignatures[teamSafe]
        });

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _optimisticProposalArgs({
            safe: teamSafe,
            txHash: txHash
        });

        optimisticProposalId = _propose({ targets: targets, values: values, calldatas: calldatas, description: "" });

        $optimisticProposalIdToTxHash[optimisticProposalId] = txHash;
        $gnosisSafeToNonceToTxHash[teamSafe][args._nonce] = txHash;

        emit TransactionProposed({
            safe: teamSafe,
            nonce: args._nonce,
            txHash: txHash,
            proposalId: optimisticProposalId,
            proposer: msg.sender
        });
    }

    /// @notice The ```batchAddTransaction``` function is a batch version of ```addTransaction()```
    /// @param teamSafes Address of each allowlisted Gnosis Safe
    /// @param args TxHashArgs of each Gnosis Safe transaction
    /// @param signatures EOA signatures for each Gnosis Safe transaction
    /// @return optimisticProposalIds Array of optimistic Proposal IDs
    function batchAddTransaction(
        address[] calldata teamSafes,
        IFraxGovernorOmega.TxHashArgs[] calldata args,
        bytes[] calldata signatures
    ) external returns (uint256[] memory optimisticProposalIds) {
        if (teamSafes.length != args.length || teamSafes.length != signatures.length) {
            revert IFraxGovernorOmega.BadBatchArgs();
        }

        optimisticProposalIds = new uint256[](teamSafes.length);

        for (uint256 i = 0; i < teamSafes.length; ++i) {
            optimisticProposalIds[i] = addTransaction({
                teamSafe: teamSafes[i],
                args: args[i],
                signatures: signatures[i]
            });
        }
    }

    /// @notice The ```rejectTransaction``` function is called when an optimistic proposal is Defeated. It calls ```safe.approveHash()``` for a 0 eth transfer with the provided ```nonce```
    /// @param teamSafe Address of allowlisted Gnosis Safe
    /// @param nonce Gnosis Safe nonce corresponding to an optimistic proposal
    function rejectTransaction(address teamSafe, uint256 nonce) external {
        bytes32 originalTxHash = $gnosisSafeToNonceToTxHash[teamSafe][nonce];

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _optimisticProposalArgs({
            safe: teamSafe,
            txHash: originalTxHash
        });
        if (
            state(
                hashProposal({
                    targets: targets,
                    values: values,
                    calldatas: calldatas,
                    descriptionHash: keccak256(bytes(""))
                })
            ) != ProposalState.Defeated
        ) {
            revert IFraxGovernorOmega.WrongProposalState();
        }

        ISafe safe = ISafe(teamSafe);
        bytes32 rejectTxHash = _safeGetTransactionHash({
            safe: safe,
            args: IFraxGovernorOmega.TxHashArgs({
                to: teamSafe,
                value: 0,
                data: "",
                operation: Enum.Operation.Call,
                safeTxGas: 0,
                baseGas: 0,
                gasPrice: 0,
                gasToken: address(0),
                refundReceiver: payable(address(0)),
                _nonce: nonce
            })
        });

        if (safe.approvedHashes({ signer: address(this), txHash: rejectTxHash }) == 1) {
            revert IFraxGovernorOmega.TransactionAlreadyApproved(rejectTxHash);
        }

        // Omega approves 0 eth transfer
        safe.approveHash(rejectTxHash);
    }

    /// @notice The ```abortTransaction``` function is called when the Frax Team no longer wants to execute a transaction they created in the Gnosis Safe UI
    /// @notice This can be before or after the transaction is added using ```addTransaction()```. It signs a 0 eth transfer for the current nonce
    /// @notice as long as the 0 eth transfer has the configured required amount of EOA signatures.
    /// @dev Only works when the transaction to abort is the first in the Gnosis Safe queue (current nonce)
    /// @dev Only way to cancel an optimistic proposal
    /// @param teamSafe Address of allowlisted Gnosis Safe
    /// @param signatures EOA signatures for a 0 ether transfer Gnosis Safe transaction with the current nonce
    function abortTransaction(address teamSafe, bytes calldata signatures) external {
        _requireEoaSignatures({ safe: teamSafe, signatures: signatures });
        _requireAllowlist(teamSafe);

        ISafe safe = ISafe(teamSafe);
        uint256 nonce = safe.nonce();

        bytes32 rejectTxHash = safe.getTransactionHash({
            to: teamSafe,
            value: 0,
            data: "",
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: payable(address(0)),
            _nonce: nonce
        });

        // Check validity of provided 3 signatures for generated txHash
        safe.checkNSignatures({
            dataHash: rejectTxHash,
            data: "",
            signatures: signatures,
            requiredSignatures: $safeRequiredSignatures[teamSafe]
        });

        bytes32 originalTxHash = $gnosisSafeToNonceToTxHash[teamSafe][nonce];
        uint256 abortedProposalId;

        // If safe/nonce tuple already had addTransaction() called for it
        if (originalTxHash != 0) {
            (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _optimisticProposalArgs({
                safe: teamSafe,
                txHash: originalTxHash
            });

            abortedProposalId = hashProposal({
                targets: targets,
                values: values,
                calldatas: calldatas,
                descriptionHash: keccak256(bytes(""))
            });
            ProposalState proposalState = state(abortedProposalId);

            if (proposalState == ProposalState.Canceled) {
                revert IFraxGovernorOmega.ProposalAlreadyCanceled();
            }

            proposals[abortedProposalId].canceled = true;
            emit ProposalCanceled(abortedProposalId);
        }

        // Omega approves 0 eth transfer
        safe.approveHash(rejectTxHash);
    }

    /// @notice The ```setVotingDelay``` function is called by governance to change the amount of time before the voting snapshot
    /// @dev Only callable by FraxGovernorAlpha governance
    /// @param newVotingDelay New voting delay in seconds
    function setVotingDelay(uint256 newVotingDelay) public override {
        _requireOnlyTimelockController();
        _setVotingDelay(newVotingDelay);
    }

    /// @notice The ```setVotingDelayBlocks``` function is called by governance to change the amount of blocks before the voting snapshot
    /// @dev Only callable by FraxGovernorAlpha governance
    /// @param newVotingDelayBlocks New voting delay in blocks
    function setVotingDelayBlocks(uint256 newVotingDelayBlocks) external {
        _requireOnlyTimelockController();
        _setVotingDelayBlocks(newVotingDelayBlocks);
    }

    /// @notice The ```setVotingPeriod``` function is called by governance to change the amount of time a proposal can be voted on
    /// @dev Only callable by FraxGovernorAlpha governance
    /// @param newVotingPeriod New voting period in seconds
    function setVotingPeriod(uint256 newVotingPeriod) public override {
        _requireOnlyTimelockController();
        _setVotingPeriod(newVotingPeriod);
    }

    /// @notice The ```setProposalThreshold``` function is called by governance to change the amount of veFXS a proposer needs to call propose()
    /// @notice proposalThreshold calculation includes all weight delegated to the proposer
    /// @dev Only callable by FraxGovernorAlpha governance
    /// @param newProposalThreshold New voting period in amount of veFXS
    function setProposalThreshold(uint256 newProposalThreshold) public override {
        _requireOnlyTimelockController();
        _setProposalThreshold(newProposalThreshold);
    }

    /// @notice The ```updateQuorumNumerator``` function is called by governance to change the numerator / 100 needed for quorum
    /// @dev Only callable by FraxGovernorAlpha governance
    /// @param newQuorumNumerator Number expressed as x/100 (percentage)
    function updateQuorumNumerator(uint256 newQuorumNumerator) external override {
        _requireOnlyTimelockController();
        _updateQuorumNumerator(newQuorumNumerator);
    }

    /// @notice The ```setVeFxsVotingDelegation``` function is called by governance to change the voting weight ```IERC5805``` contract
    /// @dev Only callable by FraxGovernorAlpha governance
    /// @param veFxsVotingDelegation New ```IERC5805``` veFxsVotingDelegation contract address
    function setVeFxsVotingDelegation(address veFxsVotingDelegation) external {
        _requireOnlyTimelockController();
        _setVeFxsVotingDelegation(veFxsVotingDelegation);
    }

    /// @notice The ```updateShortCircuitNumerator``` function is called by governance to change the short circuit numerator
    /// @dev Only callable by FraxGovernorAlpha governance
    /// @param newShortCircuitNumerator Number expressed as x/100 (percentage)
    function updateShortCircuitNumerator(uint256 newShortCircuitNumerator) external {
        _requireOnlyTimelockController();
        _updateShortCircuitNumerator(newShortCircuitNumerator);
    }

    /// @notice The ```updateSafes``` function is called by governance to allowlist safes and set the amount of required signatures needed to add the transaction with addTransaction()
    /// @notice Safes are expected to be properly configured before calling this function
    /// @notice Proper configuration entails having: the FraxGuard set, FraxGovernorOmega set as a signer and FraxGovernorAlpha's TimelockController as a Module
    /// @dev Can use to add or remove safes. See TestFraxGovernorUpgrade.t.sol for upgrade path
    /// @dev Set config.requiredSignatures to 0 to remove the Safe from the allowlist
    /// @param safeConfigs Array of SafeConfig
    function updateSafes(SafeConfig[] calldata safeConfigs) external {
        _requireOnlyTimelockController();

        for (uint256 i = 0; i < safeConfigs.length; ++i) {
            SafeConfig calldata config = safeConfigs[i];
            uint256 oldRequiredSignatures = $safeRequiredSignatures[config.safe];
            $safeRequiredSignatures[config.safe] = config.requiredSignatures;
            emit SafeConfigUpdate({
                safe: config.safe,
                oldRequiredSignatures: oldRequiredSignatures,
                newRequiredSignatures: config.requiredSignatures
            });
        }
    }

    /// @notice The ```_optimisticVoteDefeated``` function is called by state() to check if an optimistic proposal was defeated
    /// @param proposalId Proposal ID
    /// @return Whether the optimistic proposal was defeated or not
    function _optimisticVoteDefeated(uint256 proposalId) internal view returns (bool) {
        (uint256 againstVoteWeight, uint256 forVoteWeight, ) = proposalVotes(proposalId);
        if (againstVoteWeight == 0 && forVoteWeight == 0) {
            return false;
        } else {
            return forVoteWeight <= againstVoteWeight;
        }
    }

    /// @notice The ```state``` function is similar to OpenZeppelin's propose() with minor changes
    /// @dev Changes include: support for early success or failure using short circuit and optimistic proposals
    /// @param proposalId Proposal ID
    /// @return proposalState ProposalState enum
    function state(uint256 proposalId) public view override returns (ProposalState proposalState) {
        ProposalCore storage $proposal = proposals[proposalId];

        if ($proposal.executed) {
            return ProposalState.Executed;
        }

        if ($proposal.canceled) {
            return ProposalState.Canceled;
        }

        uint256 snapshot = proposalSnapshot(proposalId);

        if (snapshot == 0) {
            revert("Governor: unknown proposal id");
        }

        uint256 currentTimepoint = clock();

        if (snapshot >= currentTimepoint || $snapshotTimestampToSnapshotBlockNumber[snapshot] >= block.number) {
            return ProposalState.Pending;
        }

        // Allow early execution when overwhelming majority
        if (_shortCircuitFor(proposalId)) {
            return ProposalState.Succeeded;
        } else if (_shortCircuitAgainst(proposalId)) {
            return ProposalState.Defeated;
        }

        uint256 deadline = proposalDeadline(proposalId);

        if (deadline >= currentTimepoint) {
            return ProposalState.Active;
        }

        // Optimistic proposal with addTransaction()
        if (_quorumReached(proposalId) && _optimisticVoteDefeated(proposalId)) {
            return ProposalState.Defeated;
        } else {
            return ProposalState.Succeeded;
        }
    }
}
