// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {LibReward} from "./LibReward.sol";
import {IVoting} from "../interfaces/IVoting.sol";
import {LibProofManager} from "./LibProofManager.sol";

library LibVoting {
    struct Voting {
        bytes32[] sessionIDs;
        mapping(bytes32 => VotingSession) sessionIDToSession;
    }

    /**
     * @title VotingSession
     * @dev Struct for managing a voting session for given pair of (matchInput, matchResult)
     * @custom:field votesCount - Number of votes in this voting
     * @custom:field startTimestamp - Timestamp of first voting
     * @custom:field matchResult -  Winning match result
     * @custom:field workerToVoted -  Worker address to voted flag
     * @custom:field voters - Records each worker voting in this voting session
     * @custom:field status - Tracks voting lifecycle state.
     * @custom:field isConsensusReached - tracks wether count of votes for this session is has reached the majority to make a consensus
     */

    struct VotingSession {
        uint256 votesCount;
        uint256 startTimestamp;
        bytes32 matchResult;
        mapping(address => bool) workerToVoted;
        address payable[] voters;
        Status status;
        bool isConsensusReached;
    }

    /**
     * @dev Structure storing the configuration of the greenproof's voting system
     * @custom:field votingTimeLimit - duration of a voting session
     * @custom:field rewardAmount - value of the reward sent to each winning voter
     * @custom:field majorityPercentage - Percentage of the number of workers vote required to reach a consensus
     * @custom:field revocablePeriod - Duration under which a certificate can be revoked
     * @custom:field rewardsEnabled - Flag defining wether or not workers should be rewarded on winning vote
     */
    struct VotingConfig {
        uint256 votingTimeLimit;
        uint256 rewardAmount;
        uint256 majorityPercentage;
        uint256 revocablePeriod;
        bool rewardsEnabled;
    }

    /**
     * @title `VotingStorage` is the structured storage workspace of all storage variables related to voting component
     * @notice Whenever you wish to update your app and add more variable to the storage, make sure to add them at the end of te struct
     */
    struct VotingStorage {
        uint256 timeLimit /* limit of duration of a voting session. The vote is considered expired after `startTimestamp` + `timeLimit` */;
        uint256 majorityPercentage /* Percentage of workers that have to vote on the same result to reach the majority  */;
        address payable[] whitelistedWorkers /* List of all whitelisted workers */;
        bytes32[] votingIDs /* List of all voting identifiers */;
        mapping(bytes32 => Voting) votingIDToVoting /* Quick access to a specific voting */;
        mapping(address => uint256) workerToIndex /* Quick access to a specific worker's index inside the `workers` whitelist */;
        // Next two fields are used to expose result of completed voting session
        mapping(bytes32 => mapping(bytes32 => bytes32)) matches /* Records the consensus of a specific votingID/sessionID */;
        mapping(bytes32 => mapping(bytes32 => address payable[])) winners /* Records the addresses of the workers who voted the winning consensus. This is needed to reward the right workers */;
    }

    /**
     * @title Status
     * @dev enumeration keeping track of the state of a voting session
     * @custom:state NotStarted - Default state when a voting is  created
     * @custom:state Started - The voting has been started by the first voter who
     * @custom:state Completed - achieved eitheir when a consensus or the session tiemeLimit has been reached on the voting session
     */
    enum Status {
        NotStarted,
        /// Worker can vote
        Started,
        /// Consensus has been reached
        Completed
    }

    bytes32 private constant _VOTING_STORAGE_POSITION = keccak256("ewc.greenproof.voting.diamond.storage");

    /**
     * @notice AlreadyVoted - Error raised when some worker tries to recast a vote on the same voting session
     * @param worker - address of the voter
     */
    error AlreadyVoted(address worker);

    /**
     * @notice NotInConsensus - Error raised when trying to certify a vote which has not reached consensus
     * @dev A vote is part of a consensus only if it is correctly verified within the merkle proof of the consensus
     * @param voteID - The identifier of the voting
     */
    error NotInConsensus(bytes32 voteID); // Vote is not part of consensus

    /**
     * @notice NotWhitelisted - Error raised when a non authorized operater attempts to vote
     * @dev to be withelisted, an address should be added in the withelist by calling the function `addWorker`
     * @dev Only addresses enrolled as a worker inside EW claimManager can be added to the worker whitelist
     * @param operator - the address being rejected in voting attempt
     */
    error NotWhitelisted(address operator);

    /**
     * @notice AlreadyWhitelistedWorker - Error raised when one tries to whiteList an already authorized operater
     * @param worker - The address of the already added worker
     */
    error AlreadyWhitelistedWorker(address worker);

    /**
     * @notice SessionCannotBeRestarted - Error raised when a worker votes on an already ended voting session
     * @param votingID - The identifier of the voting
     * @param matchResult - The result of the voting
     * @dev a session is uniquely identified with the pair (votingID, matchResult)
     */
    error SessionCannotBeRestarted(bytes32 votingID, bytes32 matchResult); // Vote session is closed

    /**
     * @notice init - Initializes voting parameters
     * @dev This function will be called once during the deployment of the greenproof proxy contract.
     * @param timeLimit The time limit of a voting session. The vote is considered expired after `startTimestamp` + `timeLimit`.
     * @param majorityPercentage The percentage of workers that have to vote on the same result to reach the majority.
     */
    function init(uint256 timeLimit, uint256 majorityPercentage) internal {
        VotingStorage storage votingStorage = getStorage();

        votingStorage.timeLimit = timeLimit;
        votingStorage.majorityPercentage = majorityPercentage;
    }

    /**

     * @notice recordVote - Stores worker's vote
     * @dev This function stores a vote from a worker, and checks if the vote reached the consensus.
     * If the consensus is reached, the function completes the voting session and rewards the workers.
     * @param votingID - The identifier of the voting session.
     * @param sessionID - The identifier of the specific voting session.
     * @return numberOfRewardedWorkers -  The number of workers who were rewarded for their vote
     */
    function recordVote(bytes32 votingID, bytes32 sessionID) internal returns (uint256 numberOfRewardedWorkers) {
        VotingSession storage session = getSession(votingID, sessionID);

        session.voters.push(payable(msg.sender));
        session.votesCount++;
        session.workerToVoted[msg.sender] = true;

        if (hasReachedConsensus(session)) {
            session.isConsensusReached = true;
            numberOfRewardedWorkers = completeSession(votingID, sessionID);
        }
    }

    /**
     * @notice startSession - Starts a new voting session
     * @dev This function starts a voting session for a given pair of matchInput and matchResult.
     * @param votingID - The voting identifier
     * @param matchResult The match result for which the voting session is started.
     */
    function startSession(bytes32 votingID, bytes32 matchResult) internal {
        /// There can not be voting without some session
        if (getStorage().votingIDToVoting[votingID].sessionIDs.length == 0) {
            getStorage().votingIDs.push(votingID);
        }

        Voting storage voting = getStorage().votingIDToVoting[votingID];
        bytes32 sessionID = getSessionID(votingID, matchResult);
        VotingSession storage session = voting.sessionIDToSession[sessionID];

        session.matchResult = matchResult;
        session.startTimestamp = block.timestamp; // solhint-disable-line not-rely-on-time
        session.status = Status.Started;
        voting.sessionIDs.push(sessionID);
    }

    /**
     * @notice _completeSession - Marks a session as completed and if rewards are enabled, rewards the workers who voted for the winning match result
     * @dev After a session is completed, no further votes are accounted for this session.
     * @dev If consensus has been reached, the voting results are exposed. If rewards are enabled, then reward are paid to  the workers who voted for the winning match result
     * @param votingID Voting identifier
     * @param sessionID session identifier
     * @return numberOfRewardedWorkers Count of rewarded workers
     */
    function completeSession(bytes32 votingID, bytes32 sessionID) internal returns (uint256 numberOfRewardedWorkers) {
        VotingSession storage session = getSession(votingID, sessionID);
        session.status = Status.Completed;

        if (!session.isConsensusReached) {
            return 0;
        }

        // Exposes result of the session
        getStorage().matches[votingID][sessionID] = session.matchResult;

        // Exposes workers, which voted in session
        getStorage().winners[votingID][sessionID] = session.voters;

        if (LibReward.isRewardEnabled()) {
            numberOfRewardedWorkers = rewardWinners(votingID, sessionID);
        }
    }

    /**
     * @notice addWorker - Adds a worker to the whiteList of authorized workers.
     * @dev this is the internal function called by the `addWorker` function externally exposed in `VotingFacet.sol`
     * @param workerAddress - The address of the worker we want to add
     */
    function addWorker(address payable workerAddress) internal {
        VotingStorage storage votingStorage = getStorage();

        votingStorage.workerToIndex[workerAddress] = getNumberOfWorkers();
        votingStorage.whitelistedWorkers.push(workerAddress);
    }

    /**
    /**
     * @notice `rewardWinners` - Rewards the winning workers
     * @dev If funds are not sufficient to reward workers, will add in the rewardQueue only the voters who could not be rewarded
     * @param votingID - The voting ID
     * @param sessionID - ID of the session
     * @return numberOfPayments - The number of workers who have been rewarded
     */
    function rewardWinners(bytes32 votingID, bytes32 sessionID) internal returns (uint256 numberOfPayments) {
        LibReward.RewardStorage storage rs = LibReward.getStorage();
        address payable[] memory votingWinners = getStorage().winners[votingID][sessionID];

        uint256 rewardAmount = rs.rewardAmount;
        uint256 numberOfVotingWinners = votingWinners.length;

        for (uint256 i; i < numberOfVotingWinners; i++) {
            if (address(this).balance >= rewardAmount) {
                /// @dev `transfer` is safe, because worker is EOA
                votingWinners[i].transfer(rewardAmount);
                numberOfPayments++;
            } else {
                rs.rewardQueue.push(votingWinners[i]);
            }
        }
    }

    /**
     * @notice isSessionExpired: Checks if a voting session has exceeded the `timeLimit`
     * @param sessionID - The voting session ID which validity we want to check
     * @param votingID - The voting ID
     * @return isSessionExpired : boolean
     * @dev the timeLimit duration is set once during contract construction
     */
    function isSessionExpired(bytes32 votingID, bytes32 sessionID) internal view returns (bool) {
        VotingSession storage session = getSession(votingID, sessionID);

        /* solhint-disable-next-line not-rely-on-time */
        if (session.status == Status.Started && (session.startTimestamp + getStorage().timeLimit < block.timestamp)) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @notice `_hasReachedConsensus` - Check if a session has reached the consensus
     * @dev This function checks if the session has reached the consensus by comparing the number of votes and the majority percentage.
     * @param session - The ID of the voting session
     * @return A boolean value indicating whether the session has reached the consensus or not.
     */
    function hasReachedConsensus(VotingSession storage session) internal view returns (bool) {
        return hasMajority(session.votesCount);
    }

    /**
     * @notice `getNumberOfWorkers` - Gets the total number of whitelisted workers
     * @return number of whitelisted workers
     */
    function getNumberOfWorkers() internal view returns (uint256) {
        VotingStorage storage votingStorage = getStorage();

        return votingStorage.whitelistedWorkers.length;
    }

    /**
     * @notice `getSession` - Gets the Voting session details
     * @dev a session is uniquely represented by the pair values of (votingID, sessionID)
     * @param votingID The identifier of the voting
     * @param sessionID The identifier of the voting session
     * @return  The storage pointer to the actual voting session
     */
    function getSession(bytes32 votingID, bytes32 sessionID) internal view returns (VotingSession storage) {
        return getStorage().votingIDToVoting[votingID].sessionIDToSession[sessionID];
    }

    /** Data verification */

    /** @notice checkVoteInConsensus - Checks that some data is part of a voting consensus
        @param voteID : the inputHash identifying the vote
        @param dataHash: the hash of the data we want to verify
        @param dataProof: the merkle proof of the data
     */
    function checkVoteInConsensus(bytes32 voteID, bytes32 dataHash, bytes32[] memory dataProof) internal view {
        bytes32[] memory matchResults = IVoting(address(this)).getWinningMatches(voteID);
        uint256 numberOfMatchResults = matchResults.length;
        bool isVoteInConsensus;

        if (dataHash == voteID) {
            return;
        }

        for (uint256 i; i < numberOfMatchResults; i++) {
            isVoteInConsensus = LibProofManager.verifyProof(matchResults[i], dataHash, dataProof);

            if (isVoteInConsensus) {
                return;
            }
        }
        revert NotInConsensus(voteID);
    }

    /**
     * @dev Check that the session is not closed and return the session ID
     * @param votingID ID of the voting
     * @param matchResult Result of the match
     * @return sessionID ID of the session
     */
    function checkNotClosedSession(bytes32 votingID, bytes32 matchResult) internal view returns (bytes32) {
        bytes32 sessionID = getSessionID(votingID, matchResult);

        LibVoting.VotingSession storage session = getSession(votingID, sessionID);

        if (isClosed(session)) {
            revert SessionCannotBeRestarted(votingID, matchResult);
        }
        return sessionID;
    }

    /**
     * @notice checkNotVoted - Prevents a worker from voting several time for the same session
     * @dev The function checks that a worker has not voted yet
     * @dev It reverts if the operator/worker has already voted
     * @param operator The address of the worker
     * @param session The voting session
     */
    function checkNotVoted(address operator, VotingSession storage session) internal view {
        if (hasAlreadyVoted(operator, session)) {
            revert AlreadyVoted(operator);
        }
    }

    /**
     * @notice checkWhiteListedWorker - Checks if the worker is whitelisted
     * @param operator The address of the worker
     */
    function checkWhiteListedWorker(address operator) internal view {
        if (!isWhitelistedWorker(operator)) {
            revert NotWhitelisted(operator);
        }
    }

    /**
     * @notice checkNotWhiteListedWorker - Checks that a worker is not already whitelisted
     * @param operator The address of the worker
     * @dev The function reverts with the `AlreadyWhitelistedWorker` error if the operator is withelisted
     */
    function checkNotWhiteListedWorker(address operator) internal view {
        if (isWhitelistedWorker(operator)) {
            revert AlreadyWhitelistedWorker(operator);
        }
    }

    /**
     * @dev Checks if the operator has already voted
     * @param operator The address of the worker
     * @param session The voting session
     * @return true if the operator has already voted, false otherwise
     */
    function hasAlreadyVoted(address operator, VotingSession storage session) internal view returns (bool) {
        return session.workerToVoted[operator];
    }

    /**
     * @notice `hasMajority` - Checks if a session has reached the majority
     * @dev the majority is defined as the number of votes sufficient to determine match winner
     * @param numberOfWinningVotes - The number of worker's votes for this session
     * @return A boolean value indicating whether the session has reached the majority or not.
     */
    function hasMajority(uint256 numberOfWinningVotes) internal view returns (bool) {
        VotingStorage storage votingStorage = getStorage();

        return ((100 * numberOfWinningVotes) / getNumberOfWorkers()) >= votingStorage.majorityPercentage;
    }

    /**
     * @notice `_isClosed` - Checks if a voting session is closed
     * @dev A voting session is considered closed when its status is completed
     * @param vote -  The voting session to check
     * @return true if voting session is closed, false otherwise
     */
    function isClosed(VotingSession storage vote) internal view returns (bool) {
        return vote.status == Status.Completed;
    }

    /**
     * @notice `isWhitelistedWorker` - checks if an address is a whitelisted worker
     * @param worker The address to check
     * @return true if the address is a whitelisted worker, false otherwise
     */
    function isWhitelistedWorker(address worker) internal view returns (bool) {
        VotingStorage storage votingStorage = getStorage();
        uint256 workerIndex = votingStorage.workerToIndex[worker];
        return workerIndex < getNumberOfWorkers() && votingStorage.whitelistedWorkers[workerIndex] == worker;
    }

    /**
     * @dev Get the voting storage
     * @return votingStorage The voting storage
     */
    function getStorage() internal pure returns (VotingStorage storage votingStorage) {
        bytes32 position = _VOTING_STORAGE_POSITION;

        /* solhint-disable-next-line no-inline-assembly */
        assembly {
            votingStorage.slot := position
        }
    }

    /** Data verification */
    function getMinimum(uint256 maxTxAllowed, uint256 objectSize) internal pure returns (uint256 nbOfTxAllowed) {
        if (maxTxAllowed > objectSize) {
            nbOfTxAllowed = objectSize;
        } else {
            nbOfTxAllowed = maxTxAllowed;
        }
    }

    /**
     * @notice getSessionID -  Calculates the session ID given a voteID and a matchResult
     * @dev The sessionID is the resulting keccack256 of VotingID + matchResult
     * @param votingID - ID of the voting
     * @param matchResult - matchResult data
     * @return sessionID - ID of the voting session
     */
    function getSessionID(bytes32 votingID, bytes32 matchResult) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(votingID, matchResult));
    }
}
