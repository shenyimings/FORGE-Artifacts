// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IDAOStandart {
    event ProposalAdded(
        uint256 proposalId,
        uint256 startTime,
        uint256 endTimeOfVoting,
        bytes4 selector
    );
    event Finish(uint256 proposalId, VotingStatus votingStatus);
    event Deposit(address account, uint256 amount);
    event Withdraw(address account, uint256 amount);
    event Vote(
        address account,
        uint256 proposalId,
        bool supportAgainst,
        uint256 powerOfVoting
    );
    event AddPoll(
        uint256 proposalId,
        uint256 startTime,
        uint256 endTimeOfVoting
    );
    event ChangePeriodDuration(uint256 debatingPeriodDuration);
    event ChangeMinimumQuorumPercent(uint256 minimumQuorum);
    enum VotingStatus {
        NOT_CREATE,
        CREATE,
        SUCCESSFULLY,
        FAILURE,
        MISTAKE
    }

    struct Proposal {
        // proposal may execute only after voting ended
        uint256 endTimeOfVoting;
        // voting status
        VotingStatus votingStatus;
        // number of votes "For"
        uint256 votedFor;
        // number of votes "Against"
        uint256 votedAgainst;
        // a plain text description of the proposal
        bytes signature;
        // the address of the contract on which the byte code will be executed
        address recipient;
        // voting start time
        uint256 startTime;
    }

    struct User {
        // Deposit balance
        uint256 balance;
        //Time to unlock the balance
        uint256 unlockBalance;
    }

    error DAOAmountZero();
    error DAOInsufficientFunds(uint256 balance);
    error DAOFrozenBalance(uint256 unlockTime);
    error DAOVotingEnded();
    error DAOImpossibleVote();
    error DAOArrayLen();
    error DAOInvalidStartTime();
    error ZeroAmount();

    function getDAOParam()
        external
        view
        returns (
            uint256 minimumQuorumPercent,
            uint256 debatingPeriodDuration,
            uint256 nextProposalID,
            address voteToken
        );

    function getVoteStatus(uint256 proposalId, address account)
        external
        view
        returns (bool);

    function getProposal(uint256 proposalId)
        external
        view
        returns (Proposal memory);

    function getBalance(address account) external view returns (uint256);

    function getUnlockBalance(address account) external view returns (uint256);
}
