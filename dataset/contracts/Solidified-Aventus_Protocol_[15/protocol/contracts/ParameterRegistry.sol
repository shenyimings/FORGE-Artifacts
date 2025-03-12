pragma solidity 0.5.12;

import "./interfaces/IAventusStorage.sol";
import "./Owned.sol";
import "./Versioned.sol";

contract ParameterRegistry is Owned, Versioned {

  string private constant validatorsTable = "Validators";
  string private constant parameterRegistryTable = "ParameterRegistry";
  string private constant proposalsTable = "Proposals";
  string private constant merkleRootsTable = "MerkleRoots";

  uint private constant oneAVTInAttoAVT = 10**18;

  // Proposal default values.
  uint private constant COMMUNITY_PROPOSAL_LOBBYING_PERIOD = 2 weeks;
  uint private constant COMMUNITY_PROPOSAL_VOTING_PERIOD = 1 weeks;
  uint private constant COMMUNITY_PROPOSAL_REVEALING_PERIOD = 1 weeks;
  uint private constant COMMUNITY_PROPOSAL_DEPOSIT = 100 * oneAVTInAttoAVT;
  uint private constant GOVERNANCE_PROPOSAL_LOBBYING_PERIOD = 2 weeks;
  uint private constant GOVERNANCE_PROPOSAL_VOTING_PERIOD = 1 weeks;
  uint private constant GOVERNANCE_PROPOSAL_REVEALING_PERIOD = 1 weeks;
  uint private constant GOVERNANCE_PROPOSAL_DEPOSIT = 100 * oneAVTInAttoAVT;
  uint private constant VALIDATOR_CHALLENGE_LOBBYING_PERIOD = 2 weeks;
  uint private constant VALIDATOR_CHALLENGE_VOTING_PERIOD = 1 weeks;
  uint private constant VALIDATOR_CHALLENGE_REVEALING_PERIOD = 1 weeks;
  uint private constant WINNINGS_FOR_CHALLENGE_ENDER_PERCENTAGE = 10;
  uint private constant WINNINGS_FOR_CHALLENGE_WINNER_PERCENTAGE = 10;

  // Validator default values.
  uint private constant VALIDATOR_DEPOSIT = 5000 * oneAVTInAttoAVT;
  // Times after last merkle root time per lost merkle root challenge.
  uint[] private VALIDATOR_COOLING_OFF_PERIODS = [
    uint(2 days),  // Must be greater than MERKLE_ROOT_DEPOSIT_LOCK_PERIOD.
    15 weeks, // 3 months more than for zero challenges
    41 weeks, // 6 months more than for one challenges
    80 weeks  // 9 months more than for two challenges
  ];

  // Base value for merkle root deposits
  uint private constant MERKLE_ROOT_DEPOSIT = 200 * oneAVTInAttoAVT;
  // Merkle root deposit lock period (length after root registration time at which root deposit can be unlocked)
  uint private constant MERKLE_ROOT_DEPOSIT_LOCK_PERIOD = 1 days;

  IAventusStorage public s;

  constructor(IAventusStorage _s)
    public
  {
    s = _s;
  }

  // @dev This must be called ONCE and ONCE ONLY, after the permission is given to write to storage as part of migration.
  function init()
    external
    onlyOwner
  {
    require(!s.getBoolean(keccak256(abi.encodePacked(parameterRegistryTable, "Init"))), "Cannot reinit ParameterRegistry");

    s.setBoolean(keccak256(abi.encodePacked(parameterRegistryTable, "Init")), true);

    s.setUInt(keccak256(abi.encodePacked(proposalsTable, "CommunityProposalLobbyingPeriod")),
        COMMUNITY_PROPOSAL_LOBBYING_PERIOD);
    s.setUInt(keccak256(abi.encodePacked(proposalsTable, "CommunityProposalVotingPeriod")), COMMUNITY_PROPOSAL_VOTING_PERIOD);
    s.setUInt(keccak256(abi.encodePacked(proposalsTable, "CommunityProposalRevealingPeriod")),
        COMMUNITY_PROPOSAL_REVEALING_PERIOD);
    s.setUInt(keccak256(abi.encodePacked(proposalsTable, "CommunityProposalFixedDeposit")), COMMUNITY_PROPOSAL_DEPOSIT);

    s.setUInt(keccak256(abi.encodePacked(proposalsTable, "GovernanceProposalLobbyingPeriod")),
        GOVERNANCE_PROPOSAL_LOBBYING_PERIOD);
    s.setUInt(keccak256(abi.encodePacked(proposalsTable, "GovernanceProposalVotingPeriod")), GOVERNANCE_PROPOSAL_VOTING_PERIOD);
    s.setUInt(keccak256(abi.encodePacked(proposalsTable, "GovernanceProposalRevealingPeriod")),
        GOVERNANCE_PROPOSAL_REVEALING_PERIOD);
    s.setUInt(keccak256(abi.encodePacked(proposalsTable, "GovernanceProposalFixedDeposit")), GOVERNANCE_PROPOSAL_DEPOSIT);

    s.setUInt(keccak256(abi.encodePacked(validatorsTable, "ChallengeLobbyingPeriod")), VALIDATOR_CHALLENGE_LOBBYING_PERIOD);
    s.setUInt(keccak256(abi.encodePacked(validatorsTable, "ChallengeVotingPeriod")), VALIDATOR_CHALLENGE_VOTING_PERIOD);
    s.setUInt(keccak256(abi.encodePacked(validatorsTable, "ChallengeRevealingPeriod")), VALIDATOR_CHALLENGE_REVEALING_PERIOD);
    s.setUInt(keccak256(abi.encodePacked(validatorsTable, "WinningsForChallengeEnderPercentage")),
        WINNINGS_FOR_CHALLENGE_ENDER_PERCENTAGE);
    s.setUInt(keccak256(abi.encodePacked(validatorsTable, "WinningsForChallengeWinnerPercentage")),
        WINNINGS_FOR_CHALLENGE_WINNER_PERCENTAGE);

    s.setUInt(keccak256(abi.encodePacked(validatorsTable, "FixedDepositAmount")), VALIDATOR_DEPOSIT);
    s.setUInt(keccak256(abi.encodePacked(validatorsTable, "NumValidatorCoolingOffPeriods")), VALIDATOR_COOLING_OFF_PERIODS.length);
    assert(VALIDATOR_COOLING_OFF_PERIODS[0] > MERKLE_ROOT_DEPOSIT_LOCK_PERIOD);

    for (uint i = 0; i < VALIDATOR_COOLING_OFF_PERIODS.length; ++i) {
      s.setUInt(keccak256(abi.encodePacked(validatorsTable, "ValidatorCoolingOffPeriod", i)), VALIDATOR_COOLING_OFF_PERIODS[i]);
    }

    s.setUInt(keccak256(abi.encodePacked(merkleRootsTable, "RootDeposit")), MERKLE_ROOT_DEPOSIT);
    s.setUInt(keccak256(abi.encodePacked(merkleRootsTable, "RootDepositLockPeriod")), MERKLE_ROOT_DEPOSIT_LOCK_PERIOD);
  }
}