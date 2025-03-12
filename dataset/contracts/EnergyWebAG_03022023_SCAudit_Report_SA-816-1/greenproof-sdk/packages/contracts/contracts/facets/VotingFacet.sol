// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IVoting} from "../interfaces/IVoting.sol";
import {IReward} from "../interfaces/IReward.sol";
import {LibReward} from "../libraries/LibReward.sol";
import {LibVoting} from "../libraries/LibVoting.sol";
import {LibClaimManager} from "../libraries/LibClaimManager.sol";

/**
 * @title `VotingFacet` - The voting component of the GreenProof core module.
 * @author EnergyWeb Foundation
 * @notice this facet handles all voting functionalities of the greenProof-core module
 * @dev This contract is a facet of the EW-GreenProof-Core Diamond, a gas optimized implementation of EIP-2535 Diamond proxy standard : https://eips.ethereum.org/EIPS/eip-2535
 */
contract VotingFacet is IVoting, IReward {
    /**
     * @notice onlyEnrolledWorkers - A modifier that restricts the execution of functions only to users enrolled as workers
     * @dev This reverts the transaction if the operator does not have the worker role
     * @param operator - The address of the operator whose worker role credential is checked.
     */
    modifier onlyEnrolledWorkers(address operator) {
        LibClaimManager.checkEnrolledWorker(operator);
        _;
    }

    /**
     * @notice onlyOwner - A modifier that restricts function execution to the contract owner.
     * @dev his reverts the transaction if the caller is not the contract owner.
     */
    modifier onlyOwner() {
        LibClaimManager.checkOwnership();
        _;
    }

    /**
     * @notice onlyWhitelistedWorker - A modifier that restricts the execution of functions only to whitelisted users
     * @dev This reverts the transaction if the caller is not whiteListed into the worker list
     */
    modifier onlyWhitelistedWorker() {
        LibVoting.checkWhiteListedWorker(msg.sender);
        _;
    }

    /**
     * @notice onlyWhenEnabledRewards - A modifier that allows the execution of functions only when the reward feature is enabled
     * @dev This reverts the transaction if the the reward feature is NOT enabled
     */
    modifier onlyWhenEnabledRewards() {
        LibReward.checkRewardEnabled();
        _;
    }

    /**
     * @notice onlyRevokedWorkers - A modifier that restricts the execution of functions only to users who are NOT enrolled as workers
     * @dev This reverts the transaction if the `workerToRemove` still has the worker role credential
     * @param workerToRemove - The address of the operator whose worker role credential is checked.
     */
    modifier onlyRevokedWorkers(address workerToRemove) {
        LibClaimManager.checkRevokedWorker(workerToRemove);
        _;
    }

    /**
     * @notice Allows a worker to vote on a match result
     * @dev Increases the number of votes for this matchResult.
     * @dev Voting completes when that vote leads to consensus or when voting expires
     * @param votingID - The id of the voting
     * @param matchResult - The match result the worker is voting for
     */
    function vote(bytes32 votingID, bytes32 matchResult) external onlyWhitelistedWorker {
        bytes32 sessionID = LibVoting.checkNotClosedSession(votingID, matchResult);
        uint256 numberOfRewardedWorkers;

        if (LibVoting.isSessionExpired(votingID, sessionID)) {
            numberOfRewardedWorkers = LibVoting.completeSession(votingID, sessionID);
            _emitSessionEvents(votingID, sessionID, numberOfRewardedWorkers);
            emit VotingSessionExpired(votingID, matchResult);
            return;
        }

        LibVoting.VotingSession storage session = LibVoting.getSession(votingID, sessionID);

        if (session.status == LibVoting.Status.NotStarted) {
            LibVoting.startSession(votingID, matchResult);
        }

        LibVoting.checkNotVoted(msg.sender, session);

        numberOfRewardedWorkers = LibVoting.recordVote(votingID, sessionID);
        _emitSessionEvents(votingID, sessionID, numberOfRewardedWorkers);
    }

    /**
     * @notice addWorker - Adds a worker to the whiteList of authorized workers.
     * @dev To be added, a worker should have the `workerRole` credential inside the claimManager
     * @param workerAddress - The address of the worker we want to add
     */
    function addWorker(address payable workerAddress) external onlyEnrolledWorkers(workerAddress) {
        LibVoting.checkNotWhiteListedWorker(workerAddress);
        LibVoting.addWorker(workerAddress);

        /* solhint-disable-next-line not-rely-on-time */
        emit WorkerAdded(workerAddress, block.timestamp);
    }

    /**
     * @notice removeWorker - Removes a worker from the whiteList of authorized workers
     * @dev The `workerRole` credential of the worker should be revoked before the removal.
     * @param workerToRemove - The address of the worker we want to remove
     */
    function removeWorker(address workerToRemove) external onlyRevokedWorkers(workerToRemove) {
        LibVoting.VotingStorage storage votingStorage = LibVoting.getStorage();
        uint256 numberOfWorkers = LibVoting.getNumberOfWorkers();

        LibVoting.checkWhiteListedWorker(workerToRemove);

        if (numberOfWorkers > 1) {
            uint256 workerIndex = votingStorage.workerToIndex[workerToRemove];
            // Copy last element to fill the missing place in array
            address payable workerToMove = votingStorage.whitelistedWorkers[numberOfWorkers - 1];
            votingStorage.whitelistedWorkers[workerIndex] = workerToMove;
            votingStorage.workerToIndex[workerToMove] = workerIndex;
        }

        delete votingStorage.workerToIndex[workerToRemove];
        votingStorage.whitelistedWorkers.pop();

        /* solhint-disable-next-line not-rely-on-time */
        emit WorkerRemoved(workerToRemove, block.timestamp);
    }

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
    ) external override onlyOwner {
        LibVoting.VotingStorage storage votingStorage = LibVoting.getStorage();

        uint256 numberOfVotingsToCancel = LibVoting.getMinimum(numberOfVotingsLimit + startVotingIndex, votingStorage.votingIDs.length);

        for (uint256 i = startVotingIndex; i < numberOfVotingsToCancel; i++) {
            bytes32 votingID = votingStorage.votingIDs[i];
            LibVoting.Voting storage voting = votingStorage.votingIDToVoting[votingID];
            uint256 numberOfSessionsToCancel = LibVoting.getMinimum(numberOfSessionsLimit + startSessionIndex, voting.sessionIDs.length);
            for (uint256 j = startSessionIndex; j < numberOfSessionsToCancel; j++) {
                bytes32 sessionID = voting.sessionIDs[j];
                if (LibVoting.isSessionExpired(votingID, sessionID)) {
                    uint256 numberOfRewardedWorkers = LibVoting.completeSession(votingID, sessionID);
                    _emitSessionEvents(votingID, sessionID, numberOfRewardedWorkers);
                    emit VotingSessionExpired(votingID, voting.sessionIDToSession[sessionID].matchResult);
                }
            }
        }
    }

    /**
     * @notice setRewardsEnabled - Enables/disables the rewards feature.
     * @dev Only the contract owner can call this function. This restriction is set on the internal `setRewardsFeature` function.
     * @dev The transaction will revert if the function is called while the rewarding is already in the desired state intor the `rewardStorage`
     * @param rewardsEnabled - The status of rewarding feature
     */
    function setRewardsEnabled(bool rewardsEnabled) external {
        LibReward.setRewardsFeature(rewardsEnabled);

        /* solhint-disable not-rely-on-time */
        if (rewardsEnabled) {
            emit RewardsActivated(block.timestamp);
        } else {
            emit RewardsDeactivated(block.timestamp);
        }
        /* solhint-enable not-rely-on-time */
    }

    /**
     * @notice replenishRewardPool - Allows the refunding of the contract to reward workers
     * @dev This function will revert if reward feature is disabled.
     * @dev When rewards are enabled, the transaction will revert if sent withoud providig funds into `msg.value`
     */
    function replenishRewardPool() external payable onlyWhenEnabledRewards {
        LibReward.checkFunds();
        emit Replenished(msg.value);

        uint256 rewardedAmount = LibReward.payRewardsToAll();
        emit RewardsPaidOut(rewardedAmount);
    }

    /**
     * @notice payReward - Allows to manually send rewards to workers waiting in the reward queue
     * @dev This function will revert when the reward feature is disabled
     * @param numberOfPays - The number of workers who have been rewarded
     */
    function payReward(uint256 numberOfPays) external onlyWhenEnabledRewards {
        uint256 rewardedAmount = LibReward.payReward(numberOfPays);
        emit RewardsPaidOut(rewardedAmount);
    }

    /**
     * @notice getWorkers - Retrieves the list of whitelistedWorkers
     * @dev Returns an array of all workers
     * @return The list of all workers
     */
    function getWorkers() external view returns (address payable[] memory) {
        LibVoting.VotingStorage storage votingStorage = LibVoting.getStorage();

        return votingStorage.whitelistedWorkers;
    }

    /**
     * @notice Returns match results of the worker in the sessions, which has been reached consensus
     * @dev Returns an array of match results for a specific worker
     * @param votingID The input hash of the voting session
     * @param worker The address of the worker
     * @return votes - matchResults The
     */
    function getWorkerVotes(bytes32 votingID, address worker) external view returns (bytes32[] memory votes) {
        bytes32[] memory winningMatches = getWinningMatches(votingID);
        bytes32[] memory votesContainer = new bytes32[](winningMatches.length);
        uint256 numberOfVotes;
        uint256 numberOfWinningMatches = winningMatches.length;

        for (uint256 i; i < numberOfWinningMatches; i++) {
            LibVoting.VotingSession storage session = LibVoting.getSession(votingID, LibVoting.getSessionID(votingID, winningMatches[i]));

            if (LibVoting.hasAlreadyVoted(worker, session)) {
                votesContainer[numberOfVotes] = winningMatches[i];
                numberOfVotes++;
            }
        }

        votes = new bytes32[](numberOfVotes);
        for (uint256 i; i < numberOfVotes; i++) {
            votes[i] = votesContainer[i];
        }
    }

    /**
     * @notice Retreieves the list of workers who voted for the winning macth result
     * @param votingID The id of the voting session
     * @param matchResult The match result
     * @return The addresses of the workers who voted for the match result
     */
    function getWinners(bytes32 votingID, bytes32 matchResult) external view returns (address payable[] memory) {
        LibVoting.VotingStorage storage votingStorage = LibVoting.getStorage();
        bytes32 sessionID = LibVoting.getSessionID(votingID, matchResult);

        return votingStorage.winners[votingID][sessionID];
    }

    /**
     * @notice numberOfVotings - Returns the number of all votings
     * @return The number of voting
     */
    function numberOfVotings() external view returns (uint256) {
        LibVoting.VotingStorage storage votingStorage = LibVoting.getStorage();

        return votingStorage.votingIDs.length;
    }

    /**
     * @notice isWhitelistedWorker - Tells if a worker has been whitelisted
     * @dev WhiteListing a worker means adding his/her address into the whitelistedWorkers array
     * @param worker - The address of the worker we want to check
     * @return true if the worker as been added to the whiteList, false otherwise
     */
    function isWhitelistedWorker(address worker) public view returns (bool) {
        LibVoting.VotingStorage storage votingStorage = LibVoting.getStorage();
        uint256 workerIndex = votingStorage.workerToIndex[worker];
        return workerIndex < LibVoting.getNumberOfWorkers() && votingStorage.whitelistedWorkers[workerIndex] == worker;
    }

    /**
     * @notice getWinningMatches - Returns the list of match results that have reached consensus in a specific voting
     * @param votingID - The id of the voting for which we want to get the winning matches
     * @return winningMatches - An array of bytes32 representing the match results that have reached consensus
     * @dev This function returns the match results that have reached consensus in a specific voting.
     * @dev It first retrieves all the voting sessions associated with the given votingID and iterates over them to check if consensus is reached.
     * @dev The match results associated with these sessions are then returned as an array
     */
    function getWinningMatches(bytes32 votingID) public view returns (bytes32[] memory winningMatches) {
        LibVoting.Voting storage voting = LibVoting.getStorage().votingIDToVoting[votingID];
        uint256 numberOfWinningSessions;

        uint256 numberOfVotingSessionIds = voting.sessionIDs.length;

        bytes32[] memory winningSessionsIDs = new bytes32[](numberOfVotingSessionIds);

        for (uint256 i; i < numberOfVotingSessionIds; i++) {
            if (LibVoting.getSession(votingID, voting.sessionIDs[i]).isConsensusReached) {
                winningSessionsIDs[numberOfWinningSessions] = voting.sessionIDs[i];
                numberOfWinningSessions++;
            }
        }

        winningMatches = new bytes32[](numberOfWinningSessions);
        for (uint256 i; i < numberOfWinningSessions; i++) {
            winningMatches[i] = voting.sessionIDToSession[winningSessionsIDs[i]].matchResult;
        }
    }

    /**
     * @notice emitSessionEvents - Casts different events resulting of the voting session
     * @param votingID - The ID of the voting
     * @param sessionID - The ID of voting session
     * @param numberOfRewardedWorkers - The number of workers who have been rewarded when session was completed
     */
    function _emitSessionEvents(bytes32 votingID, bytes32 sessionID, uint256 numberOfRewardedWorkers) private {
        LibVoting.VotingSession storage session = LibVoting.getSession(votingID, sessionID);
        if (session.isConsensusReached) {
            emit WinningMatch(votingID, session.matchResult, session.votesCount);
            emit ConsensusReached(session.matchResult, votingID);
            if (numberOfRewardedWorkers > 0) {
                emit RewardsPaidOut(numberOfRewardedWorkers);
            }
        } else {
            emit NoConsensusReached(votingID, sessionID);
        }
    }
}
