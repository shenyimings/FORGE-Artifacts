//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @title IVoting
 * @dev Voting Interface for greenproof contracts
 * @author EnergyWeb Foundation
 */
interface IVoting {
    /**
     * @notice WinningMatch - Emitted when consensus in voting session has been reached
     * @param votingID - The id of the voting
     * @param matchResult - The winning match result
     * @param voteCount - The number of votes for the winning match result
     */
    event WinningMatch(bytes32 indexed votingID, bytes32 indexed matchResult, uint256 indexed voteCount);

    /**
     * @dev Emitted when winning match result can not be determined
     * @param votingID - The id of the voting
     * @param sessionID - The id of the session where no consensus was reached
     */
    event NoConsensusReached(bytes32 indexed votingID, bytes32 indexed sessionID);

    /**
     * @dev Emitted when voting lasts more than time limit
     * @param votingID The id of the voting
     * @param sessionID The id of the session that expired
     */
    event VotingSessionExpired(bytes32 indexed votingID, bytes32 indexed sessionID);

    /**
     * @dev Emitted after match is recorded
     * @param votingID - The id of the voting
     * @param matchResult - The match that was registered
     */
    event MatchRegistered(bytes32 indexed votingID, bytes32 indexed matchResult);

    /**
     * @dev Emitted after match is recorded
     * @param winningMatch - The match that reached consensus
     * @param votingID - The id of the voting
     */
    event ConsensusReached(bytes32 indexed winningMatch, bytes32 indexed votingID);

    /**
     * @dev Emitted after worker is removed
     * @param worker - The address of the worker that was removed
     * @param removalDate - The date when the worker was removed
     */
    event WorkerRemoved(address indexed worker, uint256 indexed removalDate);

    /**
     * @dev Emitted after worker is added
     * @param worker - The address of the worker that was added
     * @param addingDate - The date when the worker was added
     */
    event WorkerAdded(address indexed worker, uint256 indexed addingDate);

    /**
     * @notice Allows a worker to vote on a match result
     * @dev Increases the number of votes for this matchResult.
     * @dev Voting completes when that vote leads to consensus or when voting expires
     * @param votingID - The id of the voting
     * @param matchResult - The match result the worker is voting for
     */
    function vote(bytes32 votingID, bytes32 matchResult) external;

    /**
     * @notice addWorker - Adds a worker to the whiteList of authorized workers.
     * @dev To be added, a worker should have the `workerRole` credential inside the claimManager
     * @param workerAddress - The address of the worker we want to add
     */
    function addWorker(address payable workerAddress) external;

    /**
     * @notice removeWorker - Removes a worker from the whiteList of authorized workers
     * @dev The `workerRole` credential of the worker should be revoked before the removal.
     * @param workerToRemove - The address of the worker we want to remove
     */
    function removeWorker(address workerToRemove) external;

    /**
     * @notice Returns match results of the worker in the sessions, which has been reached consensus
     * @dev Returns an array of match results for a specific worker
     * @param inputHash The input hash of the voting session
     * @param worker The address of the worker
     * @return matchResults The
     */
    function getWorkerVotes(bytes32 inputHash, address worker) external returns (bytes32[] memory matchResults);

    /**
     * @notice cancelExpiredVotings - Cancels votings that takes longer than time limit
     * @param startVotingIndex - index of the position to start lopping from inside the array of votes
     * @param numberOfVotingsLimit - The number of maximum voting we want to verify
     * @param startSessionIndex - index of the position to start lopping from inside the array of sessions
     * @param numberOfSessionsLimit - The number of maximum sessions we want to verify for each votes
     * @dev only the address referenced as the contract owner is allowed to perform this.
     */
    function cancelExpiredVotings(
        uint256 startVotingIndex,
        uint256 numberOfVotingsLimit,
        uint256 startSessionIndex,
        uint256 numberOfSessionsLimit
    ) external;

    /**
     * @dev Returns an array of all workers
     * @return The list of all workers
     */
    function getWorkers() external view returns (address payable[] memory);

    /**
     * @notice Retreieves the list of workers who voted for the winning macth result
     * @param votingID The id of the voting session
     * @param matchResult The match result
     * @return The addresses of the workers who voted for the match result
     */
    function getWinners(bytes32 votingID, bytes32 matchResult) external view returns (address payable[] memory);

    /**
     * @notice getWinningMatches - Returns the list of match results that have reached consensus in a specific voting
     * @param votingID - The id of the voting for which we want to get the winning matches
     * @return winningMatches - An array of bytes32 representing the match results that have reached consensus
     * @dev This function returns the match results that have reached consensus in a specific voting.
     * @dev It first retrieves all the voting sessions associated with the given votingID and iterates over them to check if consensus is reached.
     * @dev The match results associated with these sessions are then returned as an array
     */
    function getWinningMatches(bytes32 votingID) external view returns (bytes32[] memory);

    /**
     * @notice numberOfVotings - Returns the number of all votings
     * @return The number of voting
     */
    function numberOfVotings() external view returns (uint256);
}
