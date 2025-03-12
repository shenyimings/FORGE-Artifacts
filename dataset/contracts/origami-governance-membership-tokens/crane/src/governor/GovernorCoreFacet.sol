// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {GovernorCommon} from "src/governor/lib/GovernorCommon.sol";
import {GovernorQuorum} from "src/governor/lib/GovernorQuorum.sol";
import {TokenWeightStrategy} from "src/governor/lib/TokenWeightStrategy.sol";
import {IGovernor} from "src/interfaces/IGovernor.sol";
import {IVotes} from "src/interfaces/IVotes.sol";
import {IEIP712} from "src/interfaces/utils/IEIP712.sol";
import {AccessControl} from "src/utils/AccessControl.sol";
import {GovernorStorage} from "src/utils/GovernorStorage.sol";
import {SimpleCounting} from "src/governor/lib/SimpleCounting.sol";

import {IERC165} from "@diamond/interfaces/IERC165.sol";
import {ECDSA} from "@oz/utils/cryptography/ECDSA.sol";

/**
 * @dev a really simple interface for a token that has a balanceOf function.
 */
interface BalanceToken {
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title Origami Governor Core Facet
 * @author Origami
 * @notice Core facet of the Origami Governor. All logic that is not specific to Counting or Voting strategies is here.
 * @dev This facet is not intended to be used directly, but rather through the OrigamiGovernorDiamond interface.
 * @custom:security-contact contract-security@joinorigami.com
 */
contract GovernorCoreFacet is AccessControl, IEIP712, IGovernor {
    /// @notice the role hash for granting the ability to cancel a timelocked proposal. This role is not granted as part of deployment. It should be granted only in the event of an emergency.
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 public constant EIP712_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public constant IDEMPOTENT_BALLOT_TYPEHASH =
        keccak256("IdempotentBallot(uint256 proposalId,uint8 support,string reason,uint256 nonce)");
    bytes32 public constant IDEMPOTENT_PROPOSAL_TYPEHASH = keccak256(
        "IdempotentProposal(address[] targets,uint256[] values,bytes[] calldatas,string description,uint256 nonce)"
    );

    /// @inheritdoc IEIP712
    function name() public view returns (string memory) {
        return GovernorStorage.configStorage().name;
    }

    /**
     * @inheritdoc IEIP712
     * @dev Indicate v1.1.0 so it's understood we have diverged from Governor Bravo.
     */
    function version() public pure returns (string memory) {
        return "1.1.0";
    }

    /// @inheritdoc IEIP712
    function domainSeparatorV4() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_TYPEHASH, keccak256(bytes(name())), keccak256(bytes(version())), block.chainid, address(this)
            )
        );
    }

    /// @inheritdoc IGovernor
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external pure returns (uint256) {
        return GovernorCommon.hashProposal(targets, values, calldatas, descriptionHash);
    }

    /// @inheritdoc IGovernor
    function state(uint256 proposalId) public view returns (IGovernor.ProposalState) {
        IGovernor.ProposalState status = GovernorCommon.state(proposalId);
        return GovernorCommon.succededState(proposalId, status);
    }

    /// @inheritdoc IGovernor
    function proposalSnapshot(uint256 proposalId) external view returns (uint256) {
        return GovernorStorage.proposalStorage().proposals[proposalId].snapshot;
    }

    /// @inheritdoc IGovernor
    function proposalDeadline(uint256 proposalId) external view returns (uint256) {
        return GovernorStorage.proposalStorage().proposals[proposalId].deadline;
    }

    /**
     * @notice determine if a token is valid to configure a proposal for voting with.
     * @param proposalToken the address of the token to check
     * @return true if the token is a proposal token, false otherwise
     */
    function isProposalTokenEnabled(address proposalToken) public view returns (bool) {
        return GovernorStorage.isProposalTokenEnabled(proposalToken);
    }

    /**
     * @notice determine if a counting strategy is valid to configure a proposal for voting with.
     * @param countingStrategy the selector of the counting strategy to check
     * @return true if the counting strategy is a proposal token, false otherwise
     */
    function isCountingStrategyEnabled(bytes4 countingStrategy) public view returns (bool) {
        return GovernorStorage.isCountingStrategyEnabled(countingStrategy);
    }

    /**
     * @notice Strategy for deriving the proposal-specific voting weight. Returns the weight unchanged.
     * @dev this is a shim for configuring the default counting strategy with a
     * concrete selector. We can't use the lib directly or else its functions
     * won't all be internal and would cause a separate contract deploy, as
     * opposed to inlining the code.
     */
    function simpleWeight(uint256 weight) public pure returns (uint256) {
        return TokenWeightStrategy.simpleWeight(weight);
    }

    // TODO: this return type is specific to SimpleCounting, which probably
    // means it's not generic enough to be in the public interface
    /**
     * @notice returns the current votes for, against, or abstaining for a given proposal. Once the voting period has lapsed, this is used to determine the outcome.
     * @dev this delegates weight calculation to the strategy specified in the params
     * @param proposalId the id of the proposal to get the votes for.
     * @return againstVotes - the number of votes against the proposal.
     * @return forVotes - the number of votes for the proposal.
     * @return abstainVotes - the number of votes abstaining from the vote.
     */
    function proposalVotes(uint256 proposalId) external view virtual returns (uint256, uint256, uint256) {
        return SimpleCounting.simpleProposalVotes(proposalId);
    }

    /// @inheritdoc IGovernor
    function getVotes(address account, uint256 timestamp, address proposalToken) public view returns (uint256) {
        uint256 pastVotes = IVotes(proposalToken).getPastVotes(account, timestamp);
        return pastVotes;
    }

    /// @inheritdoc IGovernor
    function hasVoted(uint256 proposalId, address account) external view returns (bool) {
        return GovernorStorage.proposalHasVoted(proposalId, account);
    }

    /// @inheritdoc IGovernor
    function getAccountNonce(address account) public view returns (uint256) {
        return GovernorStorage.getAccountNonce(account);
    }

    /// @inheritdoc IGovernor
    function proposeWithTokenAndCountingStrategyBySig(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposalToken,
        bytes4 countingStrategy,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public returns (uint256 proposalId) {
        address proposer = recoverProposer(targets, values, calldatas, description, nonce, v, r, s);

        require(getAccountNonce(proposer) == nonce, "OrigamiGovernor: invalid nonce");

        proposalId = createProposal(proposer, targets, values, calldatas, description, proposalToken, countingStrategy);

        GovernorStorage.incrementAccountNonce(proposer);
    }

    /// @inheritdoc IGovernor
    function proposeWithTokenAndCountingStrategy(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposalToken,
        bytes4 countingStrategy
    ) public returns (uint256) {
        return createProposal(msg.sender, targets, values, calldatas, description, proposalToken, countingStrategy);
    }

    /// @inheritdoc IGovernor
    function proposeWithParamsBySig(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        bytes memory params,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256) {
        (address proposalToken, bytes4 countingStrategy) = decodeParams(params);
        return proposeWithTokenAndCountingStrategyBySig(
            targets, values, calldatas, description, proposalToken, countingStrategy, nonce, v, r, s
        );
    }

    /// @inheritdoc IGovernor
    function proposeWithParams(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        bytes memory params
    ) external returns (uint256) {
        (address proposalToken, bytes4 countingStrategy) = decodeParams(params);
        return proposeWithTokenAndCountingStrategy(
            targets, values, calldatas, description, proposalToken, countingStrategy
        );
    }

    /// @inheritdoc IGovernor
    function proposeBySig(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256) {
        return proposeWithTokenAndCountingStrategyBySig(
            targets,
            values,
            calldatas,
            description,
            GovernorStorage.configStorage().defaultProposalToken,
            GovernorStorage.configStorage().defaultCountingStrategy,
            nonce,
            v,
            r,
            s
        );
    }

    /// @inheritdoc IGovernor
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256 proposalId) {
        return proposeWithTokenAndCountingStrategy(
            targets,
            values,
            calldatas,
            description,
            GovernorStorage.configStorage().defaultProposalToken,
            GovernorStorage.configStorage().defaultCountingStrategy
        );
    }

    /// @inheritdoc IGovernor
    function quorum(uint256 proposalId) external view returns (uint256) {
        return GovernorQuorum.quorum(proposalId);
    }

    /// @inheritdoc IGovernor
    function castVote(uint256 proposalId, uint8 support) external returns (uint256) {
        return _castVote(proposalId, msg.sender, support, "");
    }

    /// @inheritdoc IGovernor
    function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason) external returns (uint256) {
        return _castVote(proposalId, msg.sender, support, reason);
    }

    /// @inheritdoc IGovernor
    function castVoteWithReasonBySig(
        uint256 proposalId,
        uint8 support,
        string memory reason,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public returns (uint256 weight) {
        address voter = ECDSA.recover(
            ECDSA.toTypedDataHash(
                domainSeparatorV4(),
                keccak256(abi.encode(IDEMPOTENT_BALLOT_TYPEHASH, proposalId, support, keccak256(bytes(reason)), nonce))
            ),
            v,
            r,
            s
        );

        require(getAccountNonce(voter) == nonce, "OrigamiGovernor: invalid nonce");

        weight = _castVote(proposalId, voter, support, reason);

        GovernorStorage.incrementAccountNonce(voter);
    }

    /// @inheritdoc IGovernor
    function castVoteBySig(uint256 proposalId, uint8 support, uint256 nonce, uint8 v, bytes32 r, bytes32 s)
        external
        returns (uint256 weight)
    {
        return castVoteWithReasonBySig(proposalId, support, "", nonce, v, r, s);
    }

    /// @dev internal function to create a proposal.
    function createProposal(
        address proposer,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposalToken,
        bytes4 countingStrategy
    ) internal onlyThresholdTokenHolder(proposer) returns (uint256 proposalId) {
        require(
            IERC165(proposalToken).supportsInterface(type(IVotes).interfaceId),
            "Governor: proposal token must support IVotes"
        );
        require(isProposalTokenEnabled(proposalToken), "Governor: proposal token not allowed");
        require(isCountingStrategyEnabled(countingStrategy), "Governor: counting strategy not allowed");

        require(targets.length == values.length, "Governor: invalid proposal length");
        require(targets.length == calldatas.length, "Governor: invalid proposal length");
        require(targets.length > 0, "Governor: empty proposal");

        proposalId = GovernorCommon.hashProposal(targets, values, calldatas, keccak256(bytes(description)));
        GovernorStorage.ProposalCore storage ps =
            GovernorStorage.createProposal(proposalId, proposalToken, countingStrategy);

        emit ProposalCreated(
            proposalId,
            proposer,
            targets,
            values,
            new string[](targets.length),
            calldatas,
            ps.snapshot,
            ps.deadline,
            description
        );
    }

    /*
    * @dev internal function to cast a vote on a proposal; restricts voting to members
    * TODO: the cast vote functions really should be part of the counting strategy, since 
    * they couple to the support type
    */
    //slither-disable-start timestamp (false positive)
    function _castVote(uint256 proposalId, address account, uint8 support, string memory reason)
        internal
        onlyMember(account)
        returns (uint256 weight)
    {
        GovernorStorage.ProposalCore storage ps = GovernorStorage.proposal(proposalId);
        require(state(proposalId) == IGovernor.ProposalState.Active, "Governor: proposal not active");

        weight = getVotes(account, ps.snapshot, ps.proposalToken);
        require(weight > 0, "Governor: only accounts with delegated voting power can vote");

        SimpleCounting.setVote(proposalId, account, support, weight);

        emit VoteCast(account, proposalId, support, weight, reason);
    }
    //slither-disable-end timestamp

    /// @dev recover the proposer address from signed proposal data
    function recoverProposer(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (address) {
        bytes32[] memory encodedCallData = new bytes32[](calldatas.length);
        for (uint256 i = 0; i < calldatas.length; i++) {
            encodedCallData[i] = keccak256(calldatas[i]);
        }
        bytes32 structHash = keccak256(
            abi.encode(
                IDEMPOTENT_PROPOSAL_TYPEHASH,
                keccak256(abi.encodePacked(targets)),
                keccak256(abi.encodePacked(values)),
                keccak256(abi.encodePacked(encodedCallData)),
                keccak256(bytes(description)),
                nonce
            )
        );
        return ECDSA.recover(ECDSA.toTypedDataHash(domainSeparatorV4(), structHash), v, r, s);
    }

    /// @dev decode the bytes param format into the proposal token and counting strategy.
    function decodeParams(bytes memory params) internal view returns (address proposalToken, bytes4 countingStrategy) {
        if (keccak256(params) == keccak256("")) {
            proposalToken = GovernorStorage.configStorage().defaultProposalToken;
            countingStrategy = GovernorStorage.configStorage().defaultCountingStrategy;
        } else {
            (proposalToken, countingStrategy) = abi.decode(params, (address, bytes4));
        }
    }

    /// @dev restricts calling functions with this modifier to holders of the membership token.
    modifier onlyMember(address account) {
        require(
            BalanceToken(GovernorStorage.configStorage().membershipToken).balanceOf(account) > 0,
            "OrigamiGovernor: only members may vote"
        );
        _;
    }

    /// @dev restricts calling functions with this modifier to those who hold at least the threshold amount of the threshold token.
    modifier onlyThresholdTokenHolder(address account) {
        GovernorStorage.GovernorConfig storage cs = GovernorStorage.configStorage();
        require(
            getVotes(account, block.timestamp, cs.proposalThresholdToken) >= cs.proposalThreshold,
            "Governor: proposer votes below proposal threshold"
        );
        _;
    }
}
