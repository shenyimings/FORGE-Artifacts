// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IDAOStandart.sol";

abstract contract DAOStandart is IDAOStandart, AccessControl {
    using SafeERC20 for IERC20;

    // required for working with percentages.
    uint256 constant PRECISION_E6 = 1e6;

    // number of votes must be more than minimum quorum
    uint256 private _minimumQuorumPercent;
    // debating period duration
    uint256 private _debatingPeriodDuration;
    // number of proposals
    uint256 private _nextProposalID;
    // voting token
    address private _voteToken;
    // stores the user's voting status (id => account => status)
    mapping(uint256 => mapping(address => bool)) internal _voteStatus;
    // stores voting data (id => Proposal)
    mapping(uint256 => Proposal) internal _proposals;
    // stores user data
    mapping(address => User) internal _users;

    constructor(
        address voteToken,
        uint256 minimumQuorumPercent,
        uint256 debatingPeriodDuration
    ) {
        _voteToken = voteToken;
        _minimumQuorumPercent = minimumQuorumPercent;
        _debatingPeriodDuration = debatingPeriodDuration;
    }

    /**
     * @dev returns the main parameters
     */
    function getDAOParam()
        external
        view
        returns (
            uint256 minimumQuorumPercent,
            uint256 debatingPeriodDuration,
            uint256 nextProposalID,
            address voteToken
        )
    {
        return (
            _minimumQuorumPercent,
            _debatingPeriodDuration,
            _nextProposalID,
            _voteToken
        );
    }

    /**
     * @dev returns the user's status in a specific voting ID
     * @return true - user has already voted
     *         false - user has not voted yet
     */
    function getVoteStatus(
        uint256 proposalId,
        address account
    ) external view returns (bool) {
        return _voteStatus[proposalId][account];
    }

    /**
     * @dev returns inforamation about the proposal by ID
     * @return struct Proposal
     */
    function getProposal(
        uint256 proposalId
    ) external view returns (Proposal memory) {
        return _proposals[proposalId];
    }

    /**
     * @dev returns the user's balance
     * @param account user address
     * @return balance
     */
    function getBalance(address account) external view returns (uint256) {
        return _users[account].balance;
    }

    /**
     * @dev returns the timestamp when the balance will be unlocked
     * @param account user address
     * @return unlock timeStamp
     */
    function getUnlockBalance(address account) external view returns (uint256) {
        return _users[account].unlockBalance;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IDAOStandart).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev replenishment of the user's balance
     */
    function _deposit(uint256 amount) internal virtual {
        if (amount <= 0) {
            revert DAOAmountZero();
        }

        // checking for commission inside the token
        uint256 balanceBefore = IERC20(_voteToken).balanceOf(address(this));
        IERC20(_voteToken).safeTransferFrom(msg.sender, address(this), amount);
        uint256 balanceAfter = IERC20(_voteToken).balanceOf(address(this));
        uint256 newAmount = balanceAfter - balanceBefore;

        _users[msg.sender].balance += newAmount;

        emit Deposit(msg.sender, newAmount);
    }

    /**
     * @dev withdrawal of the user's balance
     */
    function _withdraw() internal virtual {
        User storage user = _users[msg.sender];

        if (user.unlockBalance > block.timestamp) {
            revert DAOFrozenBalance(user.unlockBalance);
        }
        uint256 amount = _users[msg.sender].balance;
        if (amount == 0) {
            revert ZeroAmount();
        }
        _users[msg.sender].balance = 0;
        IERC20(_voteToken).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount);
    }

    /**
     * @dev adding a new proposal
     * @param recipient the address of the contract on which the signature will be called
     * @param callData signature function
     * @param startTime voting start time
     */
    function _addProposal(
        address recipient,
        bytes calldata callData,
        uint256 startTime
    ) internal virtual {
        bytes4 selector = bytes4(callData);

        if (startTime < block.timestamp) {
            revert DAOInvalidStartTime();
        }
        Proposal storage proposal = _proposals[_nextProposalID];

        proposal.startTime = startTime;
        proposal.endTimeOfVoting = startTime + _debatingPeriodDuration;
        proposal.signature = callData;
        proposal.recipient = recipient;
        proposal.votingStatus = VotingStatus.CREATE;

        emit ProposalAdded(
            _nextProposalID,
            startTime,
            proposal.endTimeOfVoting,
            selector
        );

        _nextProposalID++;
    }

    /**
     * @dev adding a new poll
     * @param startTime voting start time
     */
    function _addPoll(uint256 startTime) internal virtual {
        if (startTime < block.timestamp) {
            revert DAOInvalidStartTime();
        }

        Proposal storage proposal = _proposals[_nextProposalID];
        proposal.startTime = startTime;
        proposal.endTimeOfVoting = startTime + _debatingPeriodDuration;
        proposal.votingStatus = VotingStatus.CREATE;

        emit AddPoll(_nextProposalID, startTime, proposal.endTimeOfVoting);

        _nextProposalID++;
    }

    /**
     * @dev voting for the proposal
     * @param proposalId id of voting
     * @param supportAgainst vote for (true) or against (false)
     */
    function _vote(uint256 proposalId, bool supportAgainst) internal virtual {
        require(
            _voteStatus[proposalId][msg.sender] != true,
            "DAO: you have already voted"
        );

        Proposal storage proposal = _proposals[proposalId];
        User storage user = _users[msg.sender];

        if (
            block.timestamp >= proposal.endTimeOfVoting ||
            block.timestamp < proposal.startTime ||
            proposal.votingStatus != VotingStatus.CREATE
        ) {
            revert DAOImpossibleVote();
        }

        uint256 powerOfVoting = user.balance;

        if (supportAgainst) {
            proposal.votedFor += powerOfVoting;
        } else {
            proposal.votedAgainst += powerOfVoting;
        }

        _voteStatus[proposalId][msg.sender] = true;

        if (user.unlockBalance < proposal.endTimeOfVoting) {
            user.unlockBalance = proposal.endTimeOfVoting;
        }

        emit Vote(msg.sender, proposalId, supportAgainst, powerOfVoting);
    }

    /**
     * @dev end the vote
     * @param proposalId id of voting
     */
    function _finishVote(uint256 proposalId) internal virtual {
        Proposal storage proposal = _proposals[proposalId];
        _finishValidation(proposal);
        require(
            proposal.signature.length != 0,
            "It is necessary to call the <finishPoll>"
        );

        if (
            proposal.votedFor + proposal.votedAgainst >=
            (_minimumQuorumPercent * IERC20(_voteToken).totalSupply()) /
                (100 * PRECISION_E6)
        ) {
            if (proposal.votedFor > proposal.votedAgainst) {
                (bool success, ) = proposal.recipient.call{value: 0}(
                    proposal.signature
                );
                proposal.votingStatus = !success
                    ? proposal.votingStatus = VotingStatus.MISTAKE
                    : VotingStatus.SUCCESSFULLY;
            } else {
                proposal.votingStatus = VotingStatus.FAILURE;
            }
        } else {
            proposal.votingStatus = VotingStatus.FAILURE;
        }
        emit Finish(proposalId, proposal.votingStatus);
    }

    /**
     * @dev end the vote
     * @param proposalId id of voting
     */
    function _finishPoll(uint256 proposalId) internal virtual {
        Proposal storage proposal = _proposals[proposalId];

        _finishValidation(proposal);
        require(
            proposal.signature.length == 0,
            "It is necessary to call the <finishVote>"
        );

        if (
            proposal.votedFor + proposal.votedAgainst >=
            (_minimumQuorumPercent * IERC20(_voteToken).totalSupply()) /
                (100 * PRECISION_E6)
        ) {
            if (proposal.votedFor > proposal.votedAgainst) {
                proposal.votingStatus = VotingStatus.SUCCESSFULLY;
            } else {
                proposal.votingStatus = VotingStatus.FAILURE;
            }
        } else {
            proposal.votingStatus = VotingStatus.FAILURE;
        }
        emit Finish(proposalId, proposal.votingStatus);
    }

    function _finishValidation(Proposal memory proposal) internal view {
        require(
            proposal.endTimeOfVoting <= block.timestamp,
            "DAO: It is impossible to complete now"
        );

        if (proposal.votingStatus != VotingStatus.CREATE) {
            revert DAOVotingEnded();
        }
    }

    /// @dev change the duration of new votes
    function _setPeriodDuration(uint256 debatingPeriodDuration) internal {
        _debatingPeriodDuration = debatingPeriodDuration;
        emit ChangePeriodDuration(debatingPeriodDuration);
    }

    /// @dev change the minimum allowable percentage
    /// @param minimumQuorum specify taking into account precision
    function _setMinimumQuorumPercent(uint256 minimumQuorum) internal {
        _minimumQuorumPercent = minimumQuorum;
        emit ChangeMinimumQuorumPercent(minimumQuorum);
    }
}
