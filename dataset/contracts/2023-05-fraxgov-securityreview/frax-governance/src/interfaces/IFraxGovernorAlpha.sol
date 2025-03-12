// SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

interface IFraxGovernorAlpha {
    function $snapshotTimestampToSnapshotBlockNumber(uint256 snapshot) external view returns (uint256 blockNumber);

    function $timelock() external view returns (address);

    function $timelockIds(uint256) external view returns (bytes32);

    function $votingDelayBlocks() external view returns (uint256);

    function BALLOT_TYPEHASH() external view returns (bytes32);

    function CLOCK_MODE() external view returns (string memory);

    function COUNTING_MODE() external pure returns (string memory);

    function EXTENDED_BALLOT_TYPEHASH() external view returns (bytes32);

    function VE_FXS() external view returns (address);

    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external returns (uint256);

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

    function proposalEta(uint256 proposalId) external view returns (uint256);

    function proposalProposer(uint256 proposalId) external view returns (address);

    function proposalSnapshot(uint256 proposalId) external view returns (uint256);

    function proposalThreshold() external view returns (uint256);

    function proposalVotes(
        uint256 proposalId
    ) external view returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes);

    function proposals(
        uint256
    ) external view returns (address proposer, uint40 voteStart, uint40 voteEnd, bool executed, bool canceled);

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256 proposalId);

    function queue(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external returns (uint256);

    function quorum(uint256 timepoint) external view returns (uint256 quorumAtTimepoint);

    function quorumDenominator() external view returns (uint256);

    function quorumNumerator(uint256 timepoint) external view returns (uint256);

    function quorumNumerator() external view returns (uint256);

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

    function timelock() external view returns (address);

    function token() external view returns (address);

    function updateQuorumNumerator(uint256 newQuorumNumerator) external;

    function updateShortCircuitNumerator(uint256 newShortCircuitNumerator) external;

    function updateTimelock(address newTimelock) external;

    function version() external view returns (string memory);

    function voteWeightCast(uint256 proposalId, address account) external view returns (uint128);

    function votingDelay() external view returns (uint256);

    function votingPeriod() external view returns (uint256);
}
