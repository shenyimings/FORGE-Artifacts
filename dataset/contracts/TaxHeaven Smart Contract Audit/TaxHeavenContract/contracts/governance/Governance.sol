// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./GovernanceInterface.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../../node_modules/@openzeppelin/contracts/utils/SafeCast.sol";
import "../token/TaxTokenInterface.sol";
import "../staking/StakingVote.sol";
import "../lending/LendingInterface.sol";
import "../oracle/OracleInterface.sol";

contract Governance is GovernanceInterface {
    using SafeMath for uint256;
    using SafeMath for uint128;
    using SafeCast for uint256;

    /* ========== CONSTANT VARIABLES ========== */

    uint32 internal constant MAX_TIME_LENGTH = 4 weeks;
    uint32 internal constant MIN_TIME_LENGTH = 24 hours;
    uint16 internal constant MAX_MIN_VOTE = 0.2 * 10**4;
    uint16 internal constant MIN_MIN_VOTE = 0.0001 * 10**4;
    uint16 internal constant MAX_MIN_COMMIT = 0.01 * 10**4;
    uint16 internal constant MIN_MIN_COMMIT = 0.0001 * 10**4;
    TaxTokenInterface internal _taxTokenContract;

    /* ========== STATE VARIABLES ========== */

    uint32 internal _preVoteLength;
    uint32 internal _totalVoteLength;
    uint32 internal _expirationLength;
    uint16 internal _minimumVoteE4;
    uint16 internal _minimumVoteCoreE4;
    uint16 internal _minimumCommitE4;

    /**
     * @dev List of proposal IDs (index starts from 1).
     */
    bytes32[] _proposalList;

    struct CoreParameters {
        uint32 preVoteLength;
        uint32 totalVoteLength;
        uint32 expirationLength;
        uint16 minVoteE4;
        uint16 minVoteCoreE4;
        uint16 minCommitE4;
    }
    mapping(bytes32 => CoreParameters) internal _proposeUpdateCore;

    struct ProposeStatus {
        uint128 appliedMinimumVote;
        uint128 currentApprovalVoteSum;
        uint128 currentDenialVoteSum;
        uint32 preVoteDeadline;
        uint32 mainVoteDeadline;
        uint32 expiration;
        bool lockin;
        bool applied;
    }
    mapping(bytes32 => ProposeStatus) internal _proposeStatus;

    struct ProposeStatusWithProposeId {
        bytes32 proposeId;
        uint128 appliedMinimumVote;
        uint128 currentApprovalVoteSum;
        uint128 currentDenialVoteSum;
        uint32 preVoteDeadline;
        uint32 mainVoteDeadline;
        uint32 expiration;
        bool lockin;
        bool applied;
    }

    struct WhitelistParameters {
        address tokenAddress;
        address oracleAddress;
    }
    mapping(bytes32 => WhitelistParameters) internal _proposeList;

    struct DelistParameters {
        address tokenAddress;
    }
    mapping(bytes32 => DelistParameters) internal _proposeDelist;

    struct IncentiveParameters {
        address[] incentiveAddresses;
        uint256[] incentiveAllocation;
    }
    mapping(bytes32 => IncentiveParameters) internal _proposeUpdateIncentive;

    struct VoteAmount {
        uint128 approval;
        uint128 denial;
    }
    mapping(bytes32 => VoteAmount) internal _amountOfVotes;

    /* ========== EVENTS ========== */

    event LogUpdateCoreParameters(
        uint64 preVoteLength,
        uint64 totalVoteLength,
        uint64 expirationLength,
        uint16 minVoteE4,
        uint16 minVoteCoreE4,
        uint16 minCommitE4
    );

    event LogProposeUpdateCoreParameters(
        bytes32 indexed proposeId,
        uint64 preVoteLength,
        uint64 totalVoteLength,
        uint64 expirationLength,
        uint16 minVoteE4,
        uint16 minVoteCoreE4,
        uint16 minCommitE4,
        uint32 preVoteDeadline,
        uint32 mainVoteDeadline,
        uint32 expiration
    );
    event LogProposeUpdateWhiteList(
        bytes32 indexed proposeId,
        address tokenAddress,
        address oracleAddress,
        uint32 preVoteDeadline,
        uint32 mainVoteDeadline,
        uint32 expiration
    );
    event LogProposeDelistWhiteList(
        bytes32 indexed proposeId,
        address tokenAddress,
        uint32 preVoteDeadline,
        uint32 mainVoteDeadline,
        uint32 expiration
    );
    event LogProposeUpdateIncentive(
        bytes32 indexed proposeId,
        address[] incentiveAddresses,
        uint256[] incentiveAllocation,
        uint32 preVoteDeadline,
        uint32 mainVoteDeadline,
        uint32 expiration
    );

    event LogDeposit(
        bytes32 indexed proposeId,
        address indexed userAddress,
        bool approval,
        uint128 amount
    );

    event LogWithdraw(bytes32 indexed proposeId, address indexed userAddress, uint128 amount);

    event LogApprovedProposal(bytes32 indexed proposeId);

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address taxTokenAddress,
        uint32 preVoteLength,
        uint32 totalVoteLength,
        uint32 expirationLength,
        uint16 minVoteE4,
        uint16 minVoteCoreE4,
        uint16 minCommitE4
    ) {
        _taxTokenContract = TaxTokenInterface(taxTokenAddress);

        _assertValidCoreParameters(
            CoreParameters({
                preVoteLength: preVoteLength,
                totalVoteLength: totalVoteLength,
                expirationLength: expirationLength,
                minVoteE4: minVoteE4,
                minVoteCoreE4: minVoteCoreE4,
                minCommitE4: minCommitE4
            })
        );

        _preVoteLength = preVoteLength; // 1 weeks; // When sufficient amount of vote has not been collected until this deadline, the voting event is canceled.
        _totalVoteLength = totalVoteLength; // 2 weeks; // Only when sufficient amount of vote has been collected, the main voting period starts and the voting result is to be applied.
        _expirationLength = expirationLength; // 1 days; // Expiration of the proposal to be applied if the proposal is confirmed.
        _minimumVoteE4 = minVoteE4; // 0.05 * 10**4 is 5%
        _minimumVoteCoreE4 = minVoteCoreE4; // 0.1 * 10**4 is 10%
        _minimumCommitE4 = minCommitE4; // 0.0001 * 10**4 is 0.01%

        _proposalList.push(bytes32(0)); // The index of _proposalList starts from 1.
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice Propose delisting the tokenAddress from the whitelist.
     * The proposer needs to commit minimum deposit amount.
     */
    function proposeUpdateCoreParameters(
        uint32 preVoteLength,
        uint32 totalVoteLength,
        uint32 expirationLength,
        uint16 minVoteE4,
        uint16 minVoteCoreE4,
        uint16 minCommitE4
    ) external override {
        bytes32 proposeId = _generateUpdateCoreProposeId(
            CoreParameters({
                preVoteLength: preVoteLength,
                totalVoteLength: totalVoteLength,
                expirationLength: expirationLength,
                minVoteE4: minVoteE4,
                minVoteCoreE4: minVoteCoreE4,
                minCommitE4: minCommitE4
            })
        );
        uint32 blockTime = block.timestamp.toUint32();
        uint32 preVoteDeadline = blockTime + _preVoteLength;
        uint32 mainVoteDeadline = blockTime + _totalVoteLength;
        uint128 appliedMinimumVote = (_taxTokenContract.totalSupply().mul(_minimumVoteCoreE4) /
            10**4)
            .toUint128();
        uint128 appliedMinCommit = (_taxTokenContract.totalSupply().mul(_minimumCommitE4) / 10**4)
            .toUint128();
        uint32 expiration = _expirationLength;
        require(
            _proposeStatus[proposeId].mainVoteDeadline == 0 ||
                (_proposeStatus[proposeId].lockin == false &&
                    _proposeStatus[proposeId].preVoteDeadline +
                        _proposeStatus[proposeId].expiration <
                    block.timestamp) ||
                (_proposeStatus[proposeId].lockin == true &&
                    _proposeStatus[proposeId].mainVoteDeadline +
                        _proposeStatus[proposeId].expiration <
                    block.timestamp),
            "the proposal should not conflict with the ongoing proposal"
        );

        _assertValidCoreParameters(
            CoreParameters({
                preVoteLength: preVoteLength == 0 ? _preVoteLength : preVoteLength,
                totalVoteLength: totalVoteLength == 0 ? _totalVoteLength : totalVoteLength,
                expirationLength: expirationLength == 0 ? _expirationLength : expirationLength,
                minVoteE4: minVoteE4 == 0 ? _minimumVoteE4 : minVoteE4,
                minVoteCoreE4: minVoteCoreE4 == 0 ? _minimumVoteCoreE4 : minVoteCoreE4,
                minCommitE4: minCommitE4 == 0 ? _minimumCommitE4 : minCommitE4
            })
        );

        _proposalList.push(proposeId);
        _proposeStatus[proposeId] = ProposeStatus({
            preVoteDeadline: preVoteDeadline,
            mainVoteDeadline: mainVoteDeadline,
            expiration: expiration,
            appliedMinimumVote: appliedMinimumVote,
            currentApprovalVoteSum: appliedMinCommit,
            currentDenialVoteSum: 0,
            lockin: false,
            applied: false
        });
        _proposeUpdateCore[proposeId] = CoreParameters({
            preVoteLength: preVoteLength,
            totalVoteLength: totalVoteLength,
            expirationLength: expirationLength,
            minVoteE4: minVoteE4,
            minVoteCoreE4: minVoteCoreE4,
            minCommitE4: minCommitE4
        });
        bytes32 account = keccak256(abi.encode(proposeId, msg.sender));
        _amountOfVotes[account].approval = _amountOfVotes[account]
            .approval
            .add(appliedMinCommit)
            .toUint128();
        _lockStakingToken(msg.sender, appliedMinCommit);

        emit LogProposeUpdateCoreParameters(
            proposeId,
            preVoteLength,
            totalVoteLength,
            expirationLength,
            minVoteE4,
            minVoteCoreE4,
            minCommitE4,
            preVoteDeadline,
            mainVoteDeadline,
            expiration
        );
        emit LogDeposit(proposeId, msg.sender, true, appliedMinCommit);
    }

    /**
     * @notice Propose updating the whitelist.
     * The proposer needs to commit minimum deposit amount.
     */
    function proposeUpdateWhitelist(address tokenAddress, address oracleAddress) external override {
        // Ensure the code of oracleAddress has OracleInterface interface.
        {
            OracleInterface oracleContract = OracleInterface(oracleAddress);
            oracleContract.decimals();
            oracleContract.latestAnswer();
        }

        bytes32 proposeId = _generateRegisterWhitelistProposeId(
            WhitelistParameters({tokenAddress: tokenAddress, oracleAddress: oracleAddress})
        );
        uint32 blockTime = block.timestamp.toUint32();
        uint32 preVoteDeadline = blockTime + _preVoteLength;
        uint32 mainVoteDeadline = blockTime + _totalVoteLength;
        uint128 appliedMinimumVote = (_taxTokenContract.totalSupply().mul(_minimumVoteE4) / 10**4)
            .toUint128();
        uint128 appliedMinCommit = (_taxTokenContract.totalSupply().mul(_minimumCommitE4) / 10**4)
            .toUint128();
        uint32 expiration = _expirationLength;
        require(
            _proposeStatus[proposeId].mainVoteDeadline == 0 ||
                (_proposeStatus[proposeId].lockin == false &&
                    _proposeStatus[proposeId].preVoteDeadline +
                        _proposeStatus[proposeId].expiration <
                    block.timestamp) ||
                (_proposeStatus[proposeId].lockin == true &&
                    _proposeStatus[proposeId].mainVoteDeadline +
                        _proposeStatus[proposeId].expiration <
                    block.timestamp),
            "the proposal should not conflict with the ongoing proposal"
        );

        _proposalList.push(proposeId);
        _proposeStatus[proposeId] = ProposeStatus({
            preVoteDeadline: preVoteDeadline,
            mainVoteDeadline: mainVoteDeadline,
            expiration: expiration,
            appliedMinimumVote: appliedMinimumVote,
            currentApprovalVoteSum: appliedMinCommit,
            currentDenialVoteSum: 0,
            lockin: false,
            applied: false
        });
        _proposeList[proposeId] = WhitelistParameters({
            tokenAddress: tokenAddress,
            oracleAddress: oracleAddress
        });
        bytes32 account = keccak256(abi.encode(proposeId, msg.sender));
        _amountOfVotes[account].approval = _amountOfVotes[account]
            .approval
            .add(appliedMinCommit)
            .toUint128();
        _lockStakingToken(msg.sender, appliedMinCommit);

        emit LogProposeUpdateWhiteList(
            proposeId,
            tokenAddress,
            oracleAddress,
            preVoteDeadline,
            mainVoteDeadline,
            expiration
        );
        emit LogDeposit(proposeId, msg.sender, true, appliedMinCommit);
    }

    /**
     * @notice Propose delisting the tokenAddress from the whitelist.
     * The proposer needs to commit minimum deposit amount.
     */
    function proposeDelistWhitelist(address tokenAddress) external override {
        bytes32 proposeId = _generateUnregisterWhitelistProposeId(
            DelistParameters({tokenAddress: tokenAddress})
        );
        uint32 blockTime = block.timestamp.toUint32();
        uint32 preVoteDeadline = blockTime + _preVoteLength;
        uint32 mainVoteDeadline = blockTime + _totalVoteLength;
        uint128 appliedMinimumVote = (_taxTokenContract.totalSupply().mul(_minimumVoteE4) / 10**4)
            .toUint128();
        uint128 appliedMinCommit = (_taxTokenContract.totalSupply().mul(_minimumCommitE4) / 10**4)
            .toUint128();
        uint32 expiration = _expirationLength;
        require(
            _proposeStatus[proposeId].mainVoteDeadline == 0 ||
                (_proposeStatus[proposeId].lockin == false &&
                    _proposeStatus[proposeId].preVoteDeadline +
                        _proposeStatus[proposeId].expiration <
                    block.timestamp) ||
                (_proposeStatus[proposeId].lockin == true &&
                    _proposeStatus[proposeId].mainVoteDeadline +
                        _proposeStatus[proposeId].expiration <
                    block.timestamp),
            "the proposal should not conflict with the ongoing proposal"
        );

        require(
            _taxTokenContract.getOracleAddress(tokenAddress) != address(0),
            "the tokenAddress is not whitelisted"
        );

        _proposalList.push(proposeId);
        _proposeStatus[proposeId] = ProposeStatus({
            preVoteDeadline: preVoteDeadline,
            mainVoteDeadline: mainVoteDeadline,
            expiration: expiration,
            appliedMinimumVote: appliedMinimumVote,
            currentApprovalVoteSum: appliedMinCommit,
            currentDenialVoteSum: 0,
            lockin: false,
            applied: false
        });
        _proposeDelist[proposeId] = DelistParameters({tokenAddress: tokenAddress});
        bytes32 account = keccak256(abi.encode(proposeId, msg.sender));
        _amountOfVotes[account].approval = _amountOfVotes[account]
            .approval
            .add(appliedMinCommit)
            .toUint128();
        _lockStakingToken(msg.sender, appliedMinCommit);

        emit LogProposeDelistWhiteList(
            proposeId,
            tokenAddress,
            preVoteDeadline,
            mainVoteDeadline,
            expiration
        );
        emit LogDeposit(proposeId, msg.sender, true, appliedMinCommit);
    }

    /**
     * @notice Propose updating the incentive addresses and their allocation.
     * The proposer needs to commit minimum deposit amount.
     */
    function proposeUpdateIncentiveFund(
        address[] memory incentiveAddresses,
        uint256[] memory incentiveAllocation
    ) external override {
        bytes32 proposeId = _generateUpdateIncentiveProposeId(
            IncentiveParameters({
                incentiveAddresses: incentiveAddresses,
                incentiveAllocation: incentiveAllocation
            })
        );
        uint32 blockTime = block.timestamp.toUint32();
        uint32 preVoteDeadline = blockTime + _preVoteLength;
        uint32 mainVoteDeadline = blockTime + _totalVoteLength;
        uint128 appliedMinimumVote = (_taxTokenContract.totalSupply().mul(_minimumVoteE4) / 10**4)
            .toUint128();
        uint128 appliedMinCommit = (_taxTokenContract.totalSupply().mul(_minimumCommitE4) / 10**4)
            .toUint128();
        uint32 expiration = _expirationLength;
        require(
            _proposeStatus[proposeId].mainVoteDeadline == 0 ||
                (_proposeStatus[proposeId].lockin == false &&
                    _proposeStatus[proposeId].preVoteDeadline +
                        _proposeStatus[proposeId].expiration <
                    block.timestamp) ||
                (_proposeStatus[proposeId].lockin == true &&
                    _proposeStatus[proposeId].mainVoteDeadline +
                        _proposeStatus[proposeId].expiration <
                    block.timestamp),
            "the proposal should not conflict with the ongoing proposal"
        );

        require(
            incentiveAddresses.length == incentiveAllocation.length,
            "the length of the addresses and the allocation should be the same"
        );
        uint256 sumcheck = 0;
        for (uint256 i = 0; i < incentiveAllocation.length; i++) {
            sumcheck = sumcheck.add(incentiveAllocation[i]);
        }
        require(sumcheck == 10**8, "the sum of the allocation should be 10**8");

        _proposalList.push(proposeId);
        _proposeStatus[proposeId] = ProposeStatus({
            preVoteDeadline: preVoteDeadline,
            mainVoteDeadline: mainVoteDeadline,
            expiration: expiration,
            appliedMinimumVote: appliedMinimumVote,
            currentApprovalVoteSum: appliedMinCommit,
            currentDenialVoteSum: 0,
            lockin: false,
            applied: false
        });
        _proposeUpdateIncentive[proposeId] = IncentiveParameters({
            incentiveAddresses: incentiveAddresses,
            incentiveAllocation: incentiveAllocation
        });
        bytes32 account = keccak256(abi.encode(proposeId, msg.sender));
        _amountOfVotes[account].approval = _amountOfVotes[account]
            .approval
            .add(appliedMinCommit)
            .toUint128();
        _lockStakingToken(msg.sender, appliedMinCommit);

        emit LogProposeUpdateIncentive(
            proposeId,
            incentiveAddresses,
            incentiveAllocation,
            preVoteDeadline,
            mainVoteDeadline,
            expiration
        );
        emit LogDeposit(proposeId, msg.sender, true, appliedMinCommit);
    }

    /**
     * @notice Approve or deny the proposal by commit.
     * The voter should hold the amount in the staking contract.
     */
    function vote(
        bytes32 proposeId,
        bool approval,
        uint128 amount
    ) external override {
        bytes32 account = keccak256(abi.encode(proposeId, msg.sender));
        require(
            (_proposeStatus[proposeId].lockin &&
                _proposeStatus[proposeId].mainVoteDeadline >= block.timestamp) ||
                _proposeStatus[proposeId].preVoteDeadline >= block.timestamp,
            "voting period has expired"
        );
        if (approval) {
            _proposeStatus[proposeId].currentApprovalVoteSum = _proposeStatus[proposeId]
                .currentApprovalVoteSum
                .add(amount)
                .toUint128();
            _amountOfVotes[account].approval = _amountOfVotes[account]
                .approval
                .add(amount)
                .toUint128();
        } else {
            _proposeStatus[proposeId].currentDenialVoteSum = _proposeStatus[proposeId]
                .currentDenialVoteSum
                .add(amount)
                .toUint128();
            _amountOfVotes[account].denial = _amountOfVotes[account].denial.add(amount).toUint128();
        }
        _lockStakingToken(msg.sender, amount);

        emit LogDeposit(proposeId, msg.sender, approval, amount);
    }

    /**
     * @notice Check and mark flag if the proposal collects minimum vote amount within the pre vote period
     * and the proposal will be accepted if the approval vote is larger than denial vote
     * after the end of the main vote period.
     */
    function lockinProposal(bytes32 proposeId) external override {
        require(
            _proposeStatus[proposeId].currentApprovalVoteSum +
                _proposeStatus[proposeId].currentDenialVoteSum >=
                _proposeStatus[proposeId].appliedMinimumVote,
            "insufficient amount for lockin"
        );
        require(
            _proposeStatus[proposeId].preVoteDeadline >= block.timestamp,
            "lockin period has expired"
        );
        _proposeStatus[proposeId].lockin = true;
    }

    /**
     * @notice Apply the updating core parameters proposal if admitted.
     */
    function applyGovernanceForUpdateCore(bytes32 proposeId) external override {
        require(_proposeStatus[proposeId].lockin = true, "the proposal is not locked in");
        require(
            _proposeStatus[proposeId].applied == false,
            "the proposal has been already applied"
        );
        require(
            _proposeStatus[proposeId].mainVoteDeadline <= block.timestamp,
            "the proposal is still under voting period"
        );
        require(
            _proposeStatus[proposeId].mainVoteDeadline + _proposeStatus[proposeId].expiration >
                block.timestamp,
            "the applicable period of the proposal has expired"
        );
        require(
            _proposeStatus[proposeId].currentApprovalVoteSum >
                _proposeStatus[proposeId].currentDenialVoteSum,
            "the proposal is denied by majority of vote"
        );
        _proposeStatus[proposeId].applied = true;

        require(
            proposeId == _generateUpdateCoreProposeId(_proposeUpdateCore[proposeId]),
            "the propose ID is invalid"
        );

        _preVoteLength = _proposeUpdateCore[proposeId].preVoteLength == 0
            ? _preVoteLength
            : _proposeUpdateCore[proposeId].preVoteLength;
        _totalVoteLength = _proposeUpdateCore[proposeId].totalVoteLength == 0
            ? _totalVoteLength
            : _proposeUpdateCore[proposeId].totalVoteLength;
        _expirationLength = _proposeUpdateCore[proposeId].expirationLength == 0
            ? _expirationLength
            : _proposeUpdateCore[proposeId].expirationLength;
        _minimumVoteE4 = _proposeUpdateCore[proposeId].minVoteE4 == 0
            ? _minimumVoteE4
            : _proposeUpdateCore[proposeId].minVoteE4;
        _minimumVoteCoreE4 = _proposeUpdateCore[proposeId].minVoteCoreE4 == 0
            ? _minimumVoteCoreE4
            : _proposeUpdateCore[proposeId].minVoteCoreE4;
        _minimumCommitE4 = _proposeUpdateCore[proposeId].minCommitE4 == 0
            ? _minimumCommitE4
            : _proposeUpdateCore[proposeId].minCommitE4;

        emit LogApprovedProposal(proposeId);
        emit LogUpdateCoreParameters(
            _preVoteLength,
            _totalVoteLength,
            _expirationLength,
            _minimumVoteE4,
            _minimumVoteCoreE4,
            _minimumCommitE4
        );
    }

    /**
     * @notice Apply the listing proposal if admitted.
     */
    function applyGovernanceForUpdateWhitelist(bytes32 proposeId) external override {
        require(_proposeStatus[proposeId].lockin = true, "the proposal is not locked in");
        require(
            _proposeStatus[proposeId].applied == false,
            "the proposal has been already applied"
        );
        require(
            _proposeStatus[proposeId].mainVoteDeadline <= block.timestamp,
            "the proposal is still under voting period"
        );
        require(
            _proposeStatus[proposeId].mainVoteDeadline + _proposeStatus[proposeId].expiration >
                block.timestamp,
            "the applicable period of the proposal has expired"
        );
        require(
            _proposeStatus[proposeId].currentApprovalVoteSum >
                _proposeStatus[proposeId].currentDenialVoteSum,
            "the proposal is denied by majority of vote"
        );
        _proposeStatus[proposeId].applied = true;

        address tokenAddress = _proposeList[proposeId].tokenAddress;
        address oracleAddress = _proposeList[proposeId].oracleAddress;

        require(
            proposeId ==
                _generateRegisterWhitelistProposeId(
                    WhitelistParameters({tokenAddress: tokenAddress, oracleAddress: oracleAddress})
                ),
            "the propose ID is invalid"
        );
        _taxTokenContract.registerWhitelist(tokenAddress, oracleAddress);

        emit LogApprovedProposal(proposeId);
    }

    /**
     * @notice Apply the delisting proposal if admitted.
     */
    function applyGovernanceForDelistWhitelist(bytes32 proposeId) external override {
        require(_proposeStatus[proposeId].lockin = true, "the proposal is not locked in");
        require(
            _proposeStatus[proposeId].applied == false,
            "the proposal has been already applied"
        );
        require(
            _proposeStatus[proposeId].mainVoteDeadline <= block.timestamp,
            "the proposal is still under voting period"
        );
        require(
            _proposeStatus[proposeId].mainVoteDeadline + _proposeStatus[proposeId].expiration >
                block.timestamp,
            "the applicable period of the proposal has expired"
        );
        require(
            _proposeStatus[proposeId].currentApprovalVoteSum >
                _proposeStatus[proposeId].currentDenialVoteSum,
            "the proposal is denied by majority of vote"
        );
        _proposeStatus[proposeId].applied = true;

        address tokenAddress = _proposeDelist[proposeId].tokenAddress;

        require(
            proposeId ==
                _generateUnregisterWhitelistProposeId(
                    DelistParameters({tokenAddress: tokenAddress})
                ),
            "the propose ID is invalid"
        );
        _taxTokenContract.unregisterWhitelist(tokenAddress);

        emit LogApprovedProposal(proposeId);
    }

    /**
     * @notice Apply the updating incentive proposal if admitted.
     */
    function applyGovernanceForUpdateIncentive(bytes32 proposeId) external override {
        require(_proposeStatus[proposeId].lockin = true, "the proposal is not locked in");
        require(
            _proposeStatus[proposeId].applied == false,
            "the proposal has been already applied"
        );
        require(
            _proposeStatus[proposeId].mainVoteDeadline <= block.timestamp,
            "the proposal is still under voting period"
        );
        require(
            _proposeStatus[proposeId].mainVoteDeadline + _proposeStatus[proposeId].expiration >
                block.timestamp,
            "the applicable period of the proposal has expired"
        );
        require(
            _proposeStatus[proposeId].currentApprovalVoteSum >
                _proposeStatus[proposeId].currentDenialVoteSum,
            "the proposal is denied by majority of vote"
        );
        _proposeStatus[proposeId].applied = true;

        address[] memory incentiveAddresses = _proposeUpdateIncentive[proposeId].incentiveAddresses;
        uint256[] memory incentiveAllocation = _proposeUpdateIncentive[proposeId]
            .incentiveAllocation;

        require(
            proposeId ==
                _generateUpdateIncentiveProposeId(
                    IncentiveParameters({
                        incentiveAddresses: incentiveAddresses,
                        incentiveAllocation: incentiveAllocation
                    })
                ),
            "the propose ID is invalid"
        );
        _taxTokenContract.updateIncentiveAddresses(incentiveAddresses, incentiveAllocation);

        emit LogApprovedProposal(proposeId);
    }

    /**
     * @notice Withdraw deposit after the end of the proposal.
     */
    function withdraw(bytes32 proposeId) external override {
        bytes32 account = keccak256(abi.encode(proposeId, msg.sender));
        VoteAmount memory amountOfVotes = _amountOfVotes[account];
        require(
            amountOfVotes.approval != 0 || amountOfVotes.denial != 0,
            "no deposit on the proposeId"
        );
        require(
            (_proposeStatus[proposeId].lockin == false &&
                _proposeStatus[proposeId].preVoteDeadline < block.timestamp) ||
                (_proposeStatus[proposeId].applied == true &&
                    _proposeStatus[proposeId].mainVoteDeadline <= block.timestamp) ||
                (_proposeStatus[proposeId].mainVoteDeadline +
                    _proposeStatus[proposeId].expiration <=
                    block.timestamp),
            "cannot withdraw while the voting is in progress"
        );
        uint128 withdrawAmount = amountOfVotes.approval + amountOfVotes.denial; // <= _taxTokenContract.totalSupply()
        delete _amountOfVotes[account];
        _unlockStakingToken(msg.sender, withdrawAmount);

        emit LogWithdraw(proposeId, msg.sender, withdrawAmount);
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _lockStakingToken(address voter, uint128 amount) internal {
        address lendingAddress = _taxTokenContract.getLendingAddress();
        address stakingAddress = LendingInterface(lendingAddress).getStakingAddress();
        StakingVote(stakingAddress).voteDeposit(voter, amount);
    }

    function _unlockStakingToken(address voter, uint128 amount) internal {
        address lendingAddress = _taxTokenContract.getLendingAddress();
        address stakingAddress = LendingInterface(lendingAddress).getStakingAddress();
        StakingVote(stakingAddress).voteWithdraw(voter, amount);
    }

    function _assertValidCoreParameters(CoreParameters memory params) internal pure returns (bool) {
        require(
            params.preVoteLength + MIN_TIME_LENGTH <= params.totalVoteLength,
            "total voting period should be longer than or equal to pre-voting period"
        );

        uint256 mainVoteLength = params.totalVoteLength - params.preVoteLength;
        require(
            params.preVoteLength <= MAX_TIME_LENGTH && params.preVoteLength >= MIN_TIME_LENGTH,
            "preVoteLength should be in between the acceptable range"
        );

        require(
            mainVoteLength <= MAX_TIME_LENGTH,
            "totalVoteLength should be in between the acceptable range"
        );
        require(
            params.expirationLength <= MAX_TIME_LENGTH &&
                params.expirationLength >= MIN_TIME_LENGTH,
            "expirationLength should be in between the acceptable range"
        );

        require(
            params.minCommitE4 <= params.minVoteE4 && params.minCommitE4 <= params.minVoteCoreE4,
            "quorum to apply proposal is more than or equal to minimum commitment"
        );
        require(
            params.minCommitE4 <= MAX_MIN_COMMIT && params.minCommitE4 >= MIN_MIN_COMMIT,
            "minCommit should be in between the acceptable range"
        );
        require(
            params.minVoteE4 <= MAX_MIN_VOTE && params.minVoteE4 >= MIN_MIN_VOTE,
            "minVote should be in between the acceptable range"
        );
        require(
            params.minVoteCoreE4 <= MAX_MIN_VOTE && params.minVoteCoreE4 >= MIN_MIN_VOTE,
            "minVoteCore should be in between the acceptable range"
        );
    }

    function _generateUpdateCoreProposeId(CoreParameters memory proposal)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    "Update Core",
                    proposal.preVoteLength,
                    proposal.totalVoteLength,
                    proposal.expirationLength,
                    proposal.minVoteE4,
                    proposal.minVoteCoreE4,
                    proposal.minCommitE4
                )
            );
    }

    function _generateRegisterWhitelistProposeId(WhitelistParameters memory proposal)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode("Register Whitelist", proposal.tokenAddress, proposal.oracleAddress)
            );
    }

    function _generateUnregisterWhitelistProposeId(DelistParameters memory proposal)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode("Unregister Whitelist", proposal.tokenAddress));
    }

    function _generateUpdateIncentiveProposeId(IncentiveParameters memory proposal)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    "Update Incentive",
                    proposal.incentiveAddresses,
                    proposal.incentiveAllocation
                )
            );
    }

    /* ========== CALL FUNCTIONS ========== */

    /**
     * @return tax token address.
     */
    function getTaxTokenAddress() external view override returns (address) {
        return address(_taxTokenContract);
    }

    /**
     * @notice Get the current core parameters.
     */
    function getCoreParameters()
        external
        view
        override
        returns (
            uint32 preVoteLength,
            uint32 totalVoteLength,
            uint32 expirationLength,
            uint16 minimumVoteE4,
            uint16 minimumVoteCoreE4,
            uint16 minimumCommitE4
        )
    {
        preVoteLength = _preVoteLength;
        totalVoteLength = _totalVoteLength;
        expirationLength = _expirationLength;
        minimumVoteE4 = _minimumVoteE4;
        minimumVoteCoreE4 = _minimumVoteCoreE4;
        minimumCommitE4 = _minimumCommitE4;
    }

    /**
     * @notice Get the deposit amount of the user for the proposal.
     */
    function getUserStatus(bytes32 proposeId, address userAddress)
        external
        view
        override
        returns (uint128 approvalAmount, uint128 denialAmount)
    {
        bytes32 account = keccak256(abi.encode(proposeId, userAddress));
        VoteAmount memory amountOfVotes = _amountOfVotes[account];
        approvalAmount = amountOfVotes.approval;
        denialAmount = amountOfVotes.denial;
    }

    /**
     * @notice Get the current status of the proposal.
     */
    function getStatus(bytes32 proposeId)
        external
        view
        override
        returns (
            uint128 currentApprovalVoteSum,
            uint128 currentDenialVoteSum,
            uint128 appliedMinimumVote,
            uint32 preVoteDeadline,
            uint32 mainVoteDeadline,
            uint32 expiration,
            bool lockin,
            bool applied
        )
    {
        preVoteDeadline = _proposeStatus[proposeId].preVoteDeadline;
        mainVoteDeadline = _proposeStatus[proposeId].mainVoteDeadline;
        expiration = _proposeStatus[proposeId].expiration;
        appliedMinimumVote = _proposeStatus[proposeId].appliedMinimumVote;
        currentApprovalVoteSum = _proposeStatus[proposeId].currentApprovalVoteSum;
        currentDenialVoteSum = _proposeStatus[proposeId].currentDenialVoteSum;
        lockin = _proposeStatus[proposeId].lockin;
        applied = _proposeStatus[proposeId].applied;
    }

    /**
     * @notice Get the status of multiple proposals.
     * @param offset is a proposal index. If 0 is given, this function searches from the latest proposal.
     * @param limit is the number of proposals you query. If 0 is given, this function returns all proposals.
     * @return allProposals which is the list of the from `[..., proposeId_k, votingResult_k, otherProposalStatus_k, ...]`
     *  (k = offset, ..., offset - limit + 1), where votingResult_k is the binary of the form.
     * `currentApprovalVoteSum_k << 128 | currentDenialVoteSum_k` and otherProposalStatus_k is the binary of the form.
     * `appliedMinimumVote_k << 128 | preVoteDeadline_k << 96 | mainVoteDeadline_k << 64 | expiration_k << 32
     *                              | lockin_k << 24 | applied_k << 16`.
     */
    function getProposals(uint256 offset, uint256 limit)
        external
        view
        override
        returns (bytes32[] memory allProposals)
    {
        if (offset == 0 || offset >= _proposalList.length) {
            offset = _proposalList.length - 1;
        }

        if (limit == 0 || limit > offset) {
            limit = offset;
        }

        allProposals = new bytes32[](3 * limit);
        for (uint256 i = 0; i < limit; i++) {
            bytes32 proposeId = _proposalList[offset - i];
            ProposeStatus memory proposeStatus = _proposeStatus[proposeId];
            allProposals[3 * i] = proposeId;
            allProposals[3 * i + 1] = abi.decode(
                abi.encodePacked(
                    proposeStatus.currentApprovalVoteSum,
                    proposeStatus.currentDenialVoteSum
                ),
                (bytes32)
            );
            allProposals[3 * i + 2] = abi.decode(
                abi.encodePacked(
                    proposeStatus.appliedMinimumVote,
                    proposeStatus.preVoteDeadline,
                    proposeStatus.mainVoteDeadline,
                    proposeStatus.expiration,
                    proposeStatus.lockin,
                    proposeStatus.applied,
                    bytes2(0) // padding
                ),
                (bytes32)
            );
        }
    }

    /**
     * @notice Get the info of the updating core parameters proposal.
     */
    function getInfoUpdateCoreParameters(bytes32 proposeId)
        external
        view
        override
        returns (
            uint64 preVoteLength,
            uint64 totalVoteLength,
            uint64 expirationLength,
            uint16 minVoteE4,
            uint16 minVoteCoreE4,
            uint16 minCommitE4
        )
    {
        preVoteLength = _proposeUpdateCore[proposeId].preVoteLength;
        totalVoteLength = _proposeUpdateCore[proposeId].totalVoteLength;
        expirationLength = _proposeUpdateCore[proposeId].expirationLength;
        minVoteE4 = _proposeUpdateCore[proposeId].minVoteE4;
        minVoteCoreE4 = _proposeUpdateCore[proposeId].minVoteCoreE4;
        minCommitE4 = _proposeUpdateCore[proposeId].minCommitE4;
    }

    /**
     * @notice Get the info of the listing proposal.
     */
    function getInfoUpdateWhitelist(bytes32 proposeId)
        external
        view
        override
        returns (address tokenAddress, address oracleAddress)
    {
        tokenAddress = _proposeList[proposeId].tokenAddress;
        oracleAddress = _proposeList[proposeId].oracleAddress;
    }

    /**
     * @notice Get the info of the delisting proposal.
     */
    function getInfoDelistWhitelist(bytes32 proposeId)
        external
        view
        override
        returns (address tokenAddress)
    {
        tokenAddress = _proposeDelist[proposeId].tokenAddress;
    }

    /**
     * @notice Get the info of the updating incentive proposal.
     */
    function getInfoUpdateIncentive(bytes32 proposeId)
        external
        view
        override
        returns (address[] memory incentiveAddresses, uint256[] memory incentiveAllocation)
    {
        incentiveAddresses = _proposeUpdateIncentive[proposeId].incentiveAddresses;
        incentiveAllocation = _proposeUpdateIncentive[proposeId].incentiveAllocation;
    }
}
