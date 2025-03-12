// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./interfaces/IGovernanceV2.sol";
import "./interfaces/IVotingWeightSource.sol";
import "./Transactor.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

/**
 * @title Kapital DAO Governance V2
 * @author Playground Labs
 * @custom:security-contact security@playgroundlabs.io
 * @notice Some sensitive functions throughout the Kapital DAO contracts have
 * access control which can be passed if `msg.sender` is the latest governance
 * contract. This contract is an update to the initial governance allowing
 * voting weight from {TimeLock} and {Staking}.
 * This contract is a proposal, voting, and execution mechanism intended to
 * make sure that `msg.sender == governance` can only be satisfied via a DAO
 * voting process in which voting weight is based on locked KAP token balances.
 */
contract GovernanceV2 is IGovernanceV2, AccessControlEnumerable, Transactor {
    uint256 public constant START_VOTE = 3 days; // voting starts 3 days after proposal time
    uint256 public constant END_VOTE = 6 days; // voting ends 6 days after proposal time
    uint256 public constant EXECUTE = 9 days; // proposal can be executed 9 days after proposal time
    uint256 public constant EXPIRE = 12 days; // proposal can no longer be executed 12 days after proposal time
    uint256 public constant PROPOSE_COOLDOWN = 3 days; // limit repeated proposals from same address
    uint256 public constant QUORUM = (1e27 * 4) / 100; // 4% of KAP total supply
    uint256 public constant THRESHOLD = (1e27 * 65) / 10000; // 0.65% of KAP total supply
    bytes32 public constant UPGRADER = keccak256("UPGRADER"); // role to veto proposals
    bytes32 public constant VETOER = keccak256("VETOER"); // role to veto proposals
    bytes32 public constant VOTING_MANAGER = keccak256("VOTING_MANAGER"); // role to veto proposals
    IUniswapV2Pair public constant PAIR =
        IUniswapV2Pair(0x48200057593487b93311B03C845AFdA306a90e2a); // Uniswap KAP/ETH lp token
    bool public constant KAP_IS_TOKEN0 = true; // For interacting with Uniswap

    Proposal[] public proposals;
    mapping(address => uint256) public lastProposal; // timestamp of last proposal from `address`, used with {PROPOSE_COOLDOWN}
    mapping(uint256 => mapping(address => bool)) public hasVoted; // prevents `address` from double-voting on a proposal

    bool public vestingOn = true;
    IVotingWeightSource public immutable vesting; // team and investor vesting contract
    bool public stakingOn = false;
    IVotingWeightSource public immutable staking; // lp staking contract
    bool public timeLockOn = false;
    IVotingWeightSource public immutable timeLock; // short-term lock contract

    constructor(
        address _vesting,
        address _staking,
        address _timeLock,
        address _teamMultisig
    ) {
        require(_vesting != address(0), "Governance: Zero address");
        require(_staking != address(0), "Governance: Zero address");
        require(_timeLock != address(0), "Governance: Zero address");
        require(_teamMultisig != address(0), "Governance: Zero address");

        vesting = IVotingWeightSource(_vesting);
        staking = IVotingWeightSource(_staking);
        timeLock = IVotingWeightSource(_timeLock);
        _grantRole(UPGRADER, _teamMultisig);
        _grantRole(VETOER, _teamMultisig);
        _grantRole(VOTING_MANAGER, _teamMultisig);
    }

    /**
     * @dev Calls {GovernanceRegistry} to confirm the upgrade
     * @param governanceRegistry Address of {GovernanceRegistry}
     */
    function confirmChanged(address governanceRegistry)
        external
        onlyRole(UPGRADER)
    {
        (bool success, ) = governanceRegistry.call(
            abi.encodeWithSignature("confirmChanged()")
        );
        require(success, "Governance: Upgrade failed");
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
        uint256 votingWeight = getSnapVotingWeight(msg.sender);
        uint256 timeElapsed = block.timestamp - lastProposal[msg.sender];
        uint256 targetsLength = targets.length;

        require(votingWeight >= THRESHOLD, "Governance: Threshold");
        require(timeElapsed > PROPOSE_COOLDOWN, "Governance: Propose cooldown");
        require(targetsLength > 0, "Governance: Invalid targets");
        require(targetsLength == values.length, "Governance: Invalid values");
        require(targetsLength == data.length, "Governance: Invalid data");
        require(block.timestamp <= type(uint56).max, "Governance: Overflow");

        Proposal memory newProposal;
        newProposal.paramsHash = keccak256(abi.encode(targets, values, data));
        newProposal.time = uint56(block.timestamp);
        newProposal.priceCumulativeLast = _cumulative();
        proposals.push(newProposal);
        lastProposal[msg.sender] = block.timestamp;
        emit Propose(msg.sender, proposals.length - 1, targets, values, data);
    }

    /**
     * @dev Used to cast a vote on specified proposal
     * @param proposalId Index in {proposals}
     * @param yay True if voting yay, false if voting nay
     */
    function vote(uint256 proposalId, bool yay) external {
        require(proposalId < proposals.length, "Governance: Invalid id");
        Proposal storage proposal = proposals[proposalId];
        (uint256 votingWeightKAP, uint256 votingWeightLP) = getVotingWeights(
            msg.sender
        );
        uint256 timeElapsed = block.timestamp - proposal.time;

        require(!hasVoted[proposalId][msg.sender], "Governance: Already voted");
        require(
            START_VOTE < timeElapsed && timeElapsed < END_VOTE,
            "Governance: Voting window"
        );
        require(!proposal.vetoed, "Governance: Vetoed");
        require(
            votingWeightKAP + votingWeightLP > 0,
            "Governance: Zero weight"
        );
        require(votingWeightKAP <= type(uint96).max, "Governance: Overflow");
        require(votingWeightLP <= type(uint112).max, "Governance: Overflow");

        if (yay) {
            // voting for proposal
            proposal.yaysKAP += uint96(votingWeightKAP);
            proposal.yaysLP += uint112(votingWeightLP);
        } else {
            // voting against proposal
            proposal.naysKAP += uint96(votingWeightKAP);
            proposal.naysLP += uint112(votingWeightLP);
        }
        hasVoted[proposalId][msg.sender] = true;
        emit Vote(msg.sender, proposalId, yay, votingWeightKAP, votingWeightLP);
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
        (
            uint256 yaysLPConverted,
            uint256 naysLPConverted
        ) = _convertLPCumulative(proposal);
        uint256 yaysTotal = proposal.yaysKAP + yaysLPConverted;
        uint256 naysTotal = proposal.naysKAP + naysLPConverted;

        require(!proposal.vetoed, "Governance: Vetoed");
        require(!proposal.executed, "Governance: Already executed");
        require(
            keccak256(abi.encode(targets, values, data)) == proposal.paramsHash,
            "Governance: Transact params"
        );
        require(yaysTotal > naysTotal, "Governance: Unsuccessful");
        require(
            EXECUTE < timeElapsed && timeElapsed < EXPIRE,
            "Governance: Execution window"
        );
        require(yaysTotal + naysTotal >= QUORUM, "Governance: Quorum");

        proposal.executed = true;
        emit Execute(msg.sender, proposalId);
        _transact(targets, values, data); // this contract is a {Transactor}
    }

    /**
     * @dev Helper function for {propose}
     * @param proposer Address of governance proposer
     * @return votingWeight measured in KAP tokens
     */
    function getSnapVotingWeight(address proposer)
        public
        view
        returns (uint256 votingWeight)
    {
        // KAP voting weight sources
        if (vestingOn) {
            votingWeight += vesting.votingWeight(proposer);
        }
        if (timeLockOn) {
            votingWeight += timeLock.votingWeight(proposer);
        }

        // LP voting weight sources
        if (stakingOn) {
            votingWeight += convertLP(staking.votingWeight(proposer));
        }
    }

    /**
     * @dev Helper function for {vote}
     * @param voter Address of governance proposal voter
     * @return votingWeightKAP measured in KAP tokens
     * @return votingWeightLP measured in LP tokens
     */
    function getVotingWeights(address voter)
        public
        view
        returns (uint256 votingWeightKAP, uint256 votingWeightLP)
    {
        // KAP voting weight sources
        if (vestingOn) {
            votingWeightKAP += vesting.votingWeight(voter);
        }
        if (timeLockOn) {
            votingWeightKAP += timeLock.votingWeight(voter);
        }

        // LP voting weight sources
        if (stakingOn) {
            votingWeightLP = staking.votingWeight(voter);
        }
    }

    /**
     * @dev Coverts LP token count into KAP by referencing Uniswap state
     * @param weightLP LP token count to convert to KAP
     * @return weightKAP the converted KAP token amount
     */
    function convertLP(uint256 weightLP) public view returns (uint256) {
        (uint112 reserve0, uint112 reserve1, ) = PAIR.getReserves();
        uint112 reserveKAP = KAP_IS_TOKEN0 ? reserve0 : reserve1;
        return (weightLP * reserveKAP) / PAIR.totalSupply();
    }

    /**
     * @dev Coverts LP token count into KAP by referencing Uniswap state and TWAP
     * @param proposal proposal to reference for TWAP
     * @return yaysConverted and naysConverted the converted KAP token amounts
     */
    function _convertLPCumulative(Proposal storage proposal)
        internal
        returns (uint256 yaysConverted, uint256 naysConverted)
    {
        PAIR.sync();
        return convertLPCumulativeLast(proposal);
    }

    /**
     * @dev Converts LP token count into KAP by referencing last synced
     * Uniswap state and TWAP
     * @param proposal Proposal to convert LP counts for
     * @return yaysConverted The converted LP votes in KAP
     * @return naysConverted The converted LP votes in KAP
     * @dev Should call PAIR.sync() immediately prior
     * @dev See {governance.md} in readmes for mathematical reasoning
     */
    function convertLPCumulativeLast(Proposal memory proposal)
        public
        view
        returns (uint256 yaysConverted, uint256 naysConverted)
    {
        uint256 totalLP = PAIR.totalSupply();
        // Calculate latest k value
        (uint256 reserve0, uint256 reserve1, ) = PAIR.getReserves();
        uint256 k = reserve0 * reserve1;
        uint256 priceETHCumulative = (priceEthCumulativeLast() -
            proposal.priceCumulativeLast) / 2**112;
        uint256 reserveKAP = _sqrt(
            (k * priceETHCumulative) / (block.timestamp - proposal.time)
        );

        return (
            (proposal.yaysLP * reserveKAP) / totalLP,
            (proposal.naysLP * reserveKAP) / totalLP
        );
    }

    /**
     * @dev Fetches the ETH price cumulative from Uniswap state
     * @return priceCumulative The ETH price cumulative
     */
    function _cumulative() internal returns (uint256 priceCumulative) {
        PAIR.sync();
        return priceEthCumulativeLast();
    }

    /**
     * @dev Fetches the latest ETH price cumulative from Uniswap
     * @return priceCumulative Latest ETH price cumulative
     * @dev Should call PAIR.sync() immediately prior
     */
    function priceEthCumulativeLast()
        public
        view
        returns (uint256 priceCumulative)
    {
        priceCumulative = KAP_IS_TOKEN0
            ? PAIR.price1CumulativeLast()
            : PAIR.price0CumulativeLast();
    }

    /**
     * @dev Used by team multisig to toggle voting weight sources
     * @param _vestingOn turn Vesting voting on
     * @param _stakingOn turn Staking voting on
     * @param _timeLockOn turn TimeLock voting on
     */
    function setVotingWeightSources(
        bool _vestingOn,
        bool _stakingOn,
        bool _timeLockOn
    ) external onlyRole(VOTING_MANAGER) {
        vestingOn = _vestingOn;
        stakingOn = _stakingOn;
        timeLockOn = _timeLockOn;
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
     * @dev Used in {Vesting}, {Staking}, and {TimeLock} to securely report voting weight
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

    /**
     * @dev from @uniswap/v2-core/contracts/libraries/Math.sol.
     * Copied here to avoid solidity-compiler version errors.
     * babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
     */
    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
