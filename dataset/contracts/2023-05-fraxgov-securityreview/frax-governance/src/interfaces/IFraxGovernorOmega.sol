// SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { Enum } from "@gnosis.pm/contracts/common/Enum.sol";
import { SafeConfig } from "../FraxGovernorOmega.sol";

interface IFraxGovernorOmega {
    struct TxHashArgs {
        address to;
        uint256 value;
        bytes data;
        Enum.Operation operation;
        uint256 safeTxGas;
        uint256 baseGas;
        uint256 gasPrice;
        address gasToken;
        address refundReceiver;
        uint256 _nonce;
    }

    function $gnosisSafeToNonceToTxHash(address safe, uint256 safeNonce) external view returns (bytes32 txHash);

    function $optimisticProposalIdToTxHash(uint256 proposalId) external view returns (bytes32 txHash);

    function $safeRequiredSignatures(address safe) external view returns (uint256 requiredSignatures);

    function $snapshotTimestampToSnapshotBlockNumber(uint256 snapshot) external view returns (uint256 blockNumber);

    function $votingDelayBlocks() external view returns (uint256);

    function BALLOT_TYPEHASH() external view returns (bytes32);

    function CLOCK_MODE() external view returns (string memory);

    function COUNTING_MODE() external pure returns (string memory);

    function EXTENDED_BALLOT_TYPEHASH() external view returns (bytes32);

    function TIMELOCK_CONTROLLER() external view returns (address);

    function VE_FXS() external view returns (address);

    function abortTransaction(address teamSafe, bytes memory signatures) external;

    function addTransaction(
        address teamSafe,
        TxHashArgs memory args,
        bytes memory signatures
    ) external returns (uint256 optimisticProposalId);

    function batchAddTransaction(
        address[] memory teamSafes,
        TxHashArgs[] memory args,
        bytes[] memory signatures
    ) external returns (uint256[] memory optimisticProposalIds);

    function cancel(address[] memory, uint256[] memory, bytes[] memory, bytes32) external pure returns (uint256);

    function castVote(uint256 proposalId, uint8 support) external returns (uint256);

    function castVoteBySig(uint256 proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s) external returns (uint256);

    function castVoteWithReason(uint256 proposalId, uint8 support, string memory reason) external returns (uint256);

    function castVoteWithReasonAndParams(
        uint256 proposalId,
        uint8 support,
        string memory reason,
        bytes memory params
    ) external returns (uint256);

    function castVoteWithReasonAndParamsBySig(
        uint256 proposalId,
        uint8 support,
        string memory reason,
        bytes memory params,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);

    function clock() external view returns (uint48);

    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );

    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external payable returns (uint256);

    function getVotes(address account, uint256 timepoint) external view returns (uint256);

    function getVotesWithParams(
        address account,
        uint256 timepoint,
        bytes memory params
    ) external view returns (uint256);

    function hasVoted(uint256 proposalId, address account) external view returns (bool);

    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external pure returns (uint256);

    function name() external view returns (string memory);

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) external returns (bytes4);

    function onERC1155Received(address, address, uint256, uint256, bytes memory) external returns (bytes4);

    function onERC721Received(address, address, uint256, bytes memory) external returns (bytes4);

    function proposalDeadline(uint256 proposalId) external view returns (uint256);

    function proposalProposer(uint256 proposalId) external view returns (address);

    function proposalSnapshot(uint256 proposalId) external view returns (uint256);

    function proposalThreshold() external view returns (uint256);

    function proposalVotes(
        uint256 proposalId
    ) external view returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes);

    function proposals(
        uint256
    ) external view returns (address proposer, uint40 voteStart, uint40 voteEnd, bool executed, bool canceled);

    function propose(address[] memory, uint256[] memory, bytes[] memory, string memory) external pure returns (uint256);

    function quorum(uint256 timepoint) external view returns (uint256 quorumAtTimepoint);

    function quorumDenominator() external view returns (uint256);

    function quorumNumerator(uint256 timepoint) external view returns (uint256);

    function quorumNumerator() external view returns (uint256);

    function rejectTransaction(address teamSafe, uint256 nonce) external;

    function relay(address target, uint256 value, bytes memory data) external payable;

    function setProposalThreshold(uint256 newProposalThreshold) external;

    function setVeFxsVotingDelegation(address veFxsVotingDelegation) external;

    function setVotingDelay(uint256 newVotingDelay) external;

    function setVotingDelayBlocks(uint256 newVotingDelayBlocks) external;

    function setVotingPeriod(uint256 newVotingPeriod) external;

    function shortCircuitNumerator() external view returns (uint256 latestShortCircuitNumerator);

    function shortCircuitNumerator(uint256 timepoint) external view returns (uint256 shortCircuitNumeratorAtTimepoint);

    function shortCircuitThreshold(uint256 timepoint) external view returns (uint256 shortCircuitThresholdAtTimepoint);

    function state(uint256 proposalId) external view returns (uint8 proposalState);

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function token() external view returns (address);

    function updateQuorumNumerator(uint256 newQuorumNumerator) external;

    function updateSafes(SafeConfig[] memory safeConfigs) external;

    function updateShortCircuitNumerator(uint256 newShortCircuitNumerator) external;

    function version() external view returns (string memory);

    function voteWeightCast(uint256 proposalId, address account) external view returns (uint128);

    function votingDelay() external view returns (uint256);

    function votingPeriod() external view returns (uint256);

    error BadBatchArgs();
    error CannotPropose();
    error CannotCancelOptimisticTransaction();
    error DelegateWithAlpha();
    error DisallowedTarget(address target);
    error NonceReserved();
    error NotTimelockController();
    error ProposalAlreadyCanceled();
    error TransactionAlreadyApproved(bytes32 txHash);
    error WrongNonce();
    error WrongProposalState();
    error WrongSafeSignatureType();
}
