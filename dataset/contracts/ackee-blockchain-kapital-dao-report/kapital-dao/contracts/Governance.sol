// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./interfaces/IGovernance.sol";
import "./interfaces/IVotingWeightSource.sol";
import "./Transactor.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

/**
 * @title Kapital DAO Governance
 * @author Playground Labs
 * @custom:security-contact security@playgroundlabs.io
 * @notice Some sensitive functions throughout the Kapital DAO contracts have
 * access control which can be passed if `msg.sender` is the latest governance
 * contract. This contract is the initial governance, see {GovernanceRegistry}.
 * This contract is a proposal, voting, and execution mechanism intended to
 * make sure that `msg.sender == governance` can only be satisfied via a DAO
 * voting process in which voting weight is based on vested KAP token balances.
 */
contract Governance is IGovernance, AccessControlEnumerable, Transactor {
    uint256 public constant START_VOTE = 3 days; // voting starts 3 days after proposal time
    uint256 public constant END_VOTE = 6 days; // voting ends 6 days after proposal time
    uint256 public constant EXECUTE = 9 days; // proposal can be executed 9 days after proposal time
    uint256 public constant EXPIRE = 12 days; // proposal can no longer be executed 12 days after proposal time
    uint256 public constant PROPOSE_COOLDOWN = 3 days; // limit repeated proposals from same address
    uint256 public constant QUORUM = (1e27 * 4) / 100; // 4% of KAP total supply
    uint256 public constant THRESHOLD = (1e27 * 65) / 10000; // 0.65% of KAP total supply
    bytes32 public constant VETOER = keccak256("VETOER"); // role to veto proposals

    IVotingWeightSource public immutable vesting; // team and investor vesting contract

    Proposal[] public proposals;
    mapping(address => uint256) public lastProposal; // timestamp of last proposal from `address`, used with {PROPOSE_COOLDOWN}
    mapping(uint256 => mapping(address => bool)) public hasVoted; // prevents `address` from double-voting on a proposal

    constructor(
        address _vesting,
        address _teamMultisig
    ) {
        require(_vesting != address(0), "Governance: Zero address");
        require(_teamMultisig != address(0), "Governance: Zero address");

        vesting = IVotingWeightSource(_vesting);
        _grantRole(VETOER, _teamMultisig);
    }

    /**
     * @dev Used to create a governance proposal
     * @param targets Addresses to call
     * @param values Values of associated function calls
     * @param data Data to pass into function calls
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory data
    ) external {
        uint256 votingWeight = vesting.votingWeight(msg.sender);
        uint256 timeElapsed = block.timestamp - lastProposal[msg.sender];
        uint256 targetsLength = targets.length;

        require(votingWeight >= THRESHOLD, "Governance: Threshold");
        require(timeElapsed > PROPOSE_COOLDOWN, "Governance: Propose cooldown");
        require(targetsLength > 0, "Governance: Invalid targets");
        require(targetsLength == values.length, "Governance: Invalid values");
        require(targetsLength == data.length, "Governance: Invalid data");
        require(block.timestamp <= type(uint56).max, "Governance: Overflow");

        proposals.push(
            Proposal({
                paramsHash: keccak256(abi.encode(targets, values, data)),
                time: uint56(block.timestamp),
                yays: 0,
                nays: 0,
                executed: false,
                vetoed: false
            })
        );
        lastProposal[msg.sender] = block.timestamp;
        emit Propose(msg.sender,  proposals.length - 1, targets, values, data);
    }

    /**
     * @dev Used to cast a vote on specified proposal
     * @param proposalId Index in {proposals}
     * @param yay True if voting yay, false if voting nay
     */
    function vote(
        uint256 proposalId,
        bool yay
    ) external {
        require(proposalId < proposals.length, "Governance: Invalid id");
        Proposal storage proposal = proposals[proposalId];
        uint256 votingWeight = vesting.votingWeight(msg.sender);
        uint256 timeElapsed = block.timestamp - proposal.time;

        require(!hasVoted[proposalId][msg.sender], "Governance: Already voted");
        require(START_VOTE < timeElapsed && timeElapsed < END_VOTE, "Governance: Voting window");
        require(!proposal.vetoed, "Governance: Vetoed");
        require(votingWeight > 0, "Governance: Zero weight");
        require(votingWeight <= type(uint96).max, "Governance: Overflow");

        if (yay) { // voting for proposal
            proposal.yays += uint96(votingWeight);
        } else { // voting against proposal
            proposal.nays += uint96(votingWeight);
        }
        hasVoted[proposalId][msg.sender] = true;
        emit Vote(msg.sender, proposalId, yay, votingWeight);
    }

    /**
     * @dev Executes a successful proposal
     * @param proposalId Index in {proposals}
     * @dev See {propose} for `targets`, `values`,
     * and `data`
     */
    function execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory data
    ) external payable {
        require(proposalId < proposals.length, "Governance: Invalid id");
        Proposal storage proposal = proposals[proposalId];
        uint256 timeElapsed = block.timestamp - proposal.time;

        require(!proposal.vetoed, "Governance: Vetoed");
        require(!proposal.executed, "Governance: Already executed");
        require(
            keccak256(abi.encode(targets, values, data)) == proposal.paramsHash,
            "Governance: Transact params"
        );
        require(proposal.yays > proposal.nays, "Governance: Unsuccessful");
        require(EXECUTE < timeElapsed && timeElapsed < EXPIRE, "Governance: Execution window");
        require(proposal.yays + proposal.nays >= QUORUM, "Governance: Quorum");

        proposal.executed = true;
        emit Execute(msg.sender, proposalId);
        _transact(targets, values, data); // this contract is a {Transactor}
    }

    /**
     * @dev Used by team multisig to veto malicious proposals
     * @param proposalId Index in {proposals}
     */
    function veto(uint256 proposalId) external onlyRole(VETOER) {
        require(proposalId < proposals.length, "Governance: Invalid id");
        Proposal storage proposal = proposals[proposalId];
        
        require(!proposal.vetoed, "Governance: Already vetoed");
        require(!proposal.executed, "Governance: Already executed");
        
        proposal.vetoed = true;        
        emit Veto(proposalId);
    }

    /**
     * @dev Used in {Staking} and {Vesting} to securely report voting weight
     * @return _votingPeriod Duration of proposal voting window
     */
    function votingPeriod() external pure returns (uint256 _votingPeriod) {
        _votingPeriod = END_VOTE - START_VOTE;
    }

    /**
     * @notice Used on the front-end
     */
    function getProposals() external view returns (Proposal[] memory) {
        return proposals;
    }
}
