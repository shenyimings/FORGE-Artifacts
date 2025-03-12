// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {MockERC20Votes} from "test/mock/MockERC20Votes.sol";
import {MockERC721Votes} from "test/mock/MockERC721Votes.sol";
import {LlamaPeripheryTestSetup} from "test/LlamaPeripheryTestSetup.sol";

import {DeployLlamaTokenVotingFactory} from "script/DeployLlamaTokenVotingFactory.s.sol";

import {Action, ActionInfo, CasterConfig, LlamaTokenVotingConfig} from "src/lib/Structs.sol";
import {ILlamaPolicy} from "src/interfaces/ILlamaPolicy.sol";
import {ILlamaRelativeStrategyBase} from "src/interfaces/ILlamaRelativeStrategyBase.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {LlamaTokenAdapterVotesTimestamp} from "src/token-voting/token-adapters/LlamaTokenAdapterVotesTimestamp.sol";
import {LlamaTokenGovernor} from "src/token-voting/LlamaTokenGovernor.sol";

contract LlamaTokenVotingTestSetup is LlamaPeripheryTestSetup, DeployLlamaTokenVotingFactory {
  // Percentages
  uint16 internal constant ONE_HUNDRED_IN_BPS = 10_000;
  uint256 internal constant ONE_QUARTER_IN_BPS = 2500;
  uint256 internal constant TWO_QUARTERS_IN_BPS = 5000;
  uint256 internal constant THREE_QUARTERS_IN_BPS = 7500;

  // ERC20 Token Voting Constants.
  uint256 public constant ERC20_CREATION_THRESHOLD = 500_000e18;
  uint16 public constant ERC20_VOTE_QUORUM_PCT = 1000;
  uint16 public constant ERC20_VETO_QUORUM_PCT = 1000;

  // ERC721 Token Voting Constants.
  uint256 public constant ERC721_CREATION_THRESHOLD = 1;
  uint16 public constant ERC721_VOTE_QUORUM_PCT = 1000;
  uint16 public constant ERC721_VETO_QUORUM_PCT = 1000;

  // Time Periods
  uint64 public constant APPROVAL_PERIOD = 1 days;
  uint64 public constant QUEUING_PERIOD = 1 days;
  uint64 public constant EXPIRATION_PERIOD = 1 days;

  // Votes Tokens
  MockERC20Votes public erc20VotesToken;
  MockERC721Votes public erc721VotesToken;

  CasterConfig public defaultCasterConfig;

  // Token Voting Roles
  uint8 tokenVotingGovernorRole;
  uint8 madeUpRole;

  // Token holders.
  address tokenHolder0;
  uint256 tokenHolder0PrivateKey;
  address tokenHolder1;
  uint256 tokenHolder1PrivateKey;
  address tokenHolder2;
  uint256 tokenHolder2PrivateKey;
  address tokenHolder3;
  uint256 tokenHolder3PrivateKey;
  address notTokenHolder;
  uint256 notTokenHolderPrivateKey;

  function setUp() public virtual override {
    LlamaPeripheryTestSetup.setUp();

    // Deploy the Llama Token Voting factory and logic contracts.
    DeployLlamaTokenVotingFactory.run();

    // Deploy the ERC20 and ERC721 tokens.
    erc20VotesToken = new MockERC20Votes();
    erc721VotesToken = new MockERC721Votes();

    defaultCasterConfig = CasterConfig({
      voteQuorumPct: ERC20_VOTE_QUORUM_PCT,
      vetoQuorumPct: ERC20_VETO_QUORUM_PCT,
      delayPeriodPct: uint16(ONE_QUARTER_IN_BPS),
      castingPeriodPct: uint16(TWO_QUARTERS_IN_BPS)
    });

    //Deploy

    // Setting up tokenholder addresses and private keys.
    (tokenHolder0, tokenHolder0PrivateKey) = makeAddrAndKey("tokenHolder0");
    (tokenHolder1, tokenHolder1PrivateKey) = makeAddrAndKey("tokenHolder1");
    (tokenHolder2, tokenHolder2PrivateKey) = makeAddrAndKey("tokenHolder2");
    (tokenHolder3, tokenHolder3PrivateKey) = makeAddrAndKey("tokenHolder3");
    (notTokenHolder, notTokenHolderPrivateKey) = makeAddrAndKey("notTokenHolder");

    // Initialize required roles.
    vm.startPrank(address(EXECUTOR));
    POLICY.initializeRole(RoleDescription.wrap("Token Voting Governor Role"));
    tokenVotingGovernorRole = POLICY.numRoles();
    POLICY.initializeRole(RoleDescription.wrap("Made Up Role"));
    madeUpRole = POLICY.numRoles();
    vm.stopPrank();
  }

  // =========================
  // ======== Helpers ========
  // =========================

  function _deployERC20TokenVotingModuleAndSetRole() internal returns (LlamaTokenGovernor) {
    bytes memory adapterConfig = abi.encode(LlamaTokenAdapterVotesTimestamp.Config(address(erc20VotesToken)));
    LlamaTokenVotingConfig memory config = LlamaTokenVotingConfig(
      CORE, llamaTokenAdapterTimestampLogic, adapterConfig, 0, ERC20_CREATION_THRESHOLD, defaultCasterConfig
    );

    vm.startPrank(address(EXECUTOR));
    // Deploy Token Voting Module
    (LlamaTokenGovernor llamaERC20TokenGovernor) = tokenVotingFactory.deploy(config);
    // Assign roles to Token Voting Modules
    POLICY.setRoleHolder(
      tokenVotingGovernorRole, address(llamaERC20TokenGovernor), DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION
    );
    vm.stopPrank();

    return LlamaTokenGovernor(llamaERC20TokenGovernor);
  }

  function _deployERC721TokenVotingModuleAndSetRole() internal returns (LlamaTokenGovernor) {
    bytes memory adapterConfig = abi.encode(LlamaTokenAdapterVotesTimestamp.Config(address(erc721VotesToken)));
    LlamaTokenVotingConfig memory config = LlamaTokenVotingConfig(
      CORE, llamaTokenAdapterTimestampLogic, adapterConfig, 0, ERC721_CREATION_THRESHOLD, defaultCasterConfig
    );

    vm.startPrank(address(EXECUTOR));
    // Deploy Token Voting Module
    (LlamaTokenGovernor llamaERC721TokenGovernor) = tokenVotingFactory.deploy(config);
    // Assign roles to Token Voting Modules
    POLICY.setRoleHolder(
      tokenVotingGovernorRole, address(llamaERC721TokenGovernor), DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION
    );
    vm.stopPrank();

    return LlamaTokenGovernor(llamaERC721TokenGovernor);
  }

  function _setRolePermissionToLlamaTokenGovernor() internal {
    // Assign permission for `MockProtocol.pause` to the LlamaTokenGovernor.
    vm.prank(address(EXECUTOR));
    POLICY.setRolePermission(
      tokenVotingGovernorRole,
      ILlamaPolicy.PermissionData(address(mockProtocol), PAUSE_SELECTOR, address(STRATEGY)),
      true
    );
    vm.stopPrank();
  }

  function _deployRelativeQuantityQuorumAndSetRolePermissionToCoreTeam(uint8 _tokenVotingGovernorRole)
    internal
    returns (ILlamaStrategy newStrategy)
  {
    uint8[] memory forceRoles = new uint8[](0);

    ILlamaRelativeStrategyBase.Config memory strategyConfig = ILlamaRelativeStrategyBase.Config({
      approvalPeriod: APPROVAL_PERIOD,
      queuingPeriod: QUEUING_PERIOD,
      expirationPeriod: EXPIRATION_PERIOD,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: ONE_HUNDRED_IN_BPS,
      minDisapprovalPct: ONE_HUNDRED_IN_BPS,
      approvalRole: _tokenVotingGovernorRole,
      disapprovalRole: _tokenVotingGovernorRole,
      forceApprovalRoles: forceRoles,
      forceDisapprovalRoles: forceRoles
    });

    ILlamaRelativeStrategyBase.Config[] memory strategyConfigs = new ILlamaRelativeStrategyBase.Config[](1);
    strategyConfigs[0] = strategyConfig;

    vm.prank(address(EXECUTOR));
    CORE.createStrategies(RELATIVE_QUANTITY_QUORUM_LOGIC, encodeStrategyConfigs(strategyConfigs));

    newStrategy = ILlamaStrategy(
      LENS.computeLlamaStrategyAddress(
        address(RELATIVE_QUANTITY_QUORUM_LOGIC), encodeStrategy(strategyConfig), address(CORE)
      )
    );

    {
      vm.prank(address(EXECUTOR));
      POLICY.setRolePermission(
        CORE_TEAM_ROLE, ILlamaPolicy.PermissionData(address(mockProtocol), PAUSE_SELECTOR, address(newStrategy)), true
      );
    }
  }

  function _createActionWithTokenVotingStrategy(ILlamaStrategy _tokenVotingStrategy)
    public
    returns (ActionInfo memory _actionInfo)
  {
    bytes memory data = abi.encodeCall(mockProtocol.pause, (true));
    vm.prank(coreTeam1);
    uint256 actionId = CORE.createAction(CORE_TEAM_ROLE, _tokenVotingStrategy, address(mockProtocol), 0, data, "");
    _actionInfo = ActionInfo(actionId, coreTeam1, CORE_TEAM_ROLE, _tokenVotingStrategy, address(mockProtocol), 0, data);
  }

  function _skipVotingDelay(ActionInfo storage actionInfo) internal {
    Action memory action = CORE.getAction(actionInfo.id);
    vm.warp(action.creationTime + ((APPROVAL_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS) + 1);
  }

  function _skipVetoDelay(ActionInfo storage actionInfo) internal {
    Action memory action = CORE.getAction(actionInfo.id);
    vm.warp(
      (action.minExecutionTime - QUEUING_PERIOD) + ((QUEUING_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS) + 1
    );
  }
}
