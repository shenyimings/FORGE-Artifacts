// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {Clones} from "@openzeppelin/proxy/Clones.sol";

import {MockERC20VotesChangingClock} from "test/mock/MockERC20VotesChangingClock.sol";
import {LlamaTokenVotingTestSetup} from "test/token-voting/LlamaTokenVotingTestSetup.sol";

import {ActionInfo, LlamaTokenVotingConfig} from "src/lib/Structs.sol";
import {ILlamaCore} from "src/interfaces/ILlamaCore.sol";
import {ILlamaPolicy} from "src/interfaces/ILlamaPolicy.sol";
import {ILlamaTokenAdapter} from "src/token-voting/interfaces/ILlamaTokenAdapter.sol";
import {LlamaTokenAdapterVotesTimestamp} from "src/token-voting/token-adapters/LlamaTokenAdapterVotesTimestamp.sol";
import {LlamaTokenGovernor} from "src/token-voting/LlamaTokenGovernor.sol";
import {LlamaTokenVotingFactory} from "src/token-voting/LlamaTokenVotingFactory.sol";

contract LlamaTokenVotingFactoryTest is LlamaTokenVotingTestSetup {
  event LlamaTokenVotingInstanceCreated(
    address indexed deployer,
    ILlamaCore indexed llamaCore,
    address indexed token,
    ILlamaTokenAdapter tokenAdapterLogic,
    ILlamaTokenAdapter tokenAdapter,
    uint256 nonce,
    LlamaTokenGovernor llamaTokenGovernor,
    uint256 chainId
  );
  event ActionThresholdSet(uint256 newThreshold);
  event QuorumPctSet(uint16 voteQuorumPct, uint16 vetoQuorumPct);
  event PeriodPctSet(uint16 delayPeriodPct, uint16 castingPeriodPct);

  function setUp() public override {
    LlamaTokenVotingTestSetup.setUp();

    // Mint tokens to tokenholders so that there is an existing supply.
    erc20VotesToken.mint(tokenHolder0, ERC20_CREATION_THRESHOLD);
    erc721VotesToken.mint(tokenHolder0, 0);

    // Mine block so that the ERC20 and ERC721 supply will be available when doing a past timestamp check at initialize
    // during deployment.
    mineBlock();
  }
}

contract Constructor is LlamaTokenVotingFactoryTest {
  function test_SetsLlamaERC20TokenGovernorLogicAddress() public {
    assertEq(address(tokenVotingFactory.LLAMA_TOKEN_GOVERNOR_LOGIC()), address(llamaTokenGovernorLogic));
  }
}

contract DeployTokenVotingModule is LlamaTokenVotingFactoryTest {
  function _setPermissionCreateApproveAndQueueAction(bytes memory data) internal returns (ActionInfo memory actionInfo) {
    // Assign `deploy` permission to the `CORE_TEAM_ROLE` role.
    ILlamaPolicy.PermissionData memory deployTokenVotingPermission = ILlamaPolicy.PermissionData(
      address(tokenVotingFactory), LlamaTokenVotingFactory.deploy.selector, address(STRATEGY)
    );

    vm.prank(address(EXECUTOR));
    POLICY.setRolePermission(CORE_TEAM_ROLE, deployTokenVotingPermission, true);

    // Create an action and queue it to deploy the token voting module.
    vm.prank(coreTeam4);
    uint256 actionId = CORE.createAction(CORE_TEAM_ROLE, STRATEGY, address(tokenVotingFactory), 0, data, "");
    actionInfo = ActionInfo(actionId, coreTeam4, CORE_TEAM_ROLE, STRATEGY, address(tokenVotingFactory), 0, data);

    vm.prank(coreTeam1);
    CORE.castApproval(CORE_TEAM_ROLE, actionInfo, "");
    vm.prank(coreTeam2);
    CORE.castApproval(CORE_TEAM_ROLE, actionInfo, "");
    vm.prank(coreTeam3);
    CORE.castApproval(CORE_TEAM_ROLE, actionInfo, "");
  }

  function test_RevertIf_InconsistentClock() public {
    MockERC20VotesChangingClock token = new MockERC20VotesChangingClock();
    token.mint(tokenHolder0, ERC20_CREATION_THRESHOLD); // minting to pass total supply check
    token.setUseBlockNumber(true);
    vm.warp(block.timestamp + 1);
    vm.roll(block.number + 1);
    bytes memory adapterConfig = abi.encode(LlamaTokenAdapterVotesTimestamp.Config(address(token)));
    LlamaTokenVotingConfig memory config = LlamaTokenVotingConfig(
      CORE, llamaTokenAdapterTimestampLogic, adapterConfig, 0, ERC20_CREATION_THRESHOLD, defaultCasterConfig
    );

    // Set up action to call `deploy` with the ERC20 token.
    bytes memory data = abi.encodeWithSelector(LlamaTokenVotingFactory.deploy.selector, config);
    ActionInfo memory actionInfo = _setPermissionCreateApproveAndQueueAction(data);

    vm.expectRevert(); //LlamaTokenAdapterVotesTimestamp.ERC6372InconsistentClock.selector
    CORE.executeAction(actionInfo);

    token.setUseBlockNumber(false);

    // will succeed now that clock is timestamp
    CORE.executeAction(actionInfo);
  }

  function test_RevertIf_TokenAdapterLogicIsAddressZero() public {
    bytes memory adapterConfig = abi.encode(LlamaTokenAdapterVotesTimestamp.Config(address(0)));
    LlamaTokenVotingConfig memory config = LlamaTokenVotingConfig(
      CORE, llamaTokenAdapterTimestampLogic, adapterConfig, 0, ERC20_CREATION_THRESHOLD, defaultCasterConfig
    );

    // Set up action to call `deploy` with the ERC20 token.
    bytes memory data = abi.encodeWithSelector(LlamaTokenVotingFactory.deploy.selector, config);
    ActionInfo memory actionInfo = _setPermissionCreateApproveAndQueueAction(data);

    // Execute call to `deploy`.
    vm.expectRevert(); //LlamaTokenVotingFactory.InvalidTokenAdapterConfig.selector
    CORE.executeAction(actionInfo);
  }

  function test_RevertIf_ClocksReturnZero() public {
    bytes memory adapterConfig = abi.encode(LlamaTokenAdapterVotesTimestamp.Config(address(erc20VotesToken)));
    LlamaTokenVotingConfig memory config = LlamaTokenVotingConfig(
      CORE, ILlamaTokenAdapter(address(0)), adapterConfig, 0, ERC20_CREATION_THRESHOLD, defaultCasterConfig
    );

    // Set up action to call `deploy` with the ERC20 token.
    bytes memory data = abi.encodeWithSelector(LlamaTokenVotingFactory.deploy.selector, config);
    ActionInfo memory actionInfo = _setPermissionCreateApproveAndQueueAction(data);

    // Execute call to `deploy`.
    vm.expectRevert(); //LlamaTokenVotingFactory.InvalidTokenAdapterConfig.selector
    CORE.executeAction(actionInfo);
  }

  function test_CanDeployERC20TokenVotingModule() public {
    bytes memory adapterConfig = abi.encode(LlamaTokenAdapterVotesTimestamp.Config(address(erc20VotesToken)));
    LlamaTokenVotingConfig memory config = LlamaTokenVotingConfig(
      CORE, llamaTokenAdapterTimestampLogic, adapterConfig, 0, ERC20_CREATION_THRESHOLD, defaultCasterConfig
    );

    // Set up action to call `deploy` with the ERC20 token.
    bytes memory data = abi.encodeWithSelector(LlamaTokenVotingFactory.deploy.selector, config);
    ActionInfo memory actionInfo = _setPermissionCreateApproveAndQueueAction(data);

    bytes32 salt = keccak256(abi.encodePacked(address(EXECUTOR), address(CORE), adapterConfig, uint256(0)));

    // Compute addresses of ERC20 Token Voting Module
    LlamaTokenGovernor llamaERC20TokenGovernor = LlamaTokenGovernor(
      Clones.predictDeterministicAddress(
        address(llamaTokenGovernorLogic),
        salt,
        address(tokenVotingFactory) // deployer
      )
    );
    ILlamaTokenAdapter llamaERC20TokenAdapter = ILlamaTokenAdapter(
      Clones.predictDeterministicAddress(
        address(llamaTokenAdapterTimestampLogic),
        salt,
        address(tokenVotingFactory) // deployer
      )
    );

    // Execute call to `deploy`.
    vm.expectEmit();
    emit ActionThresholdSet(ERC20_CREATION_THRESHOLD);
    vm.expectEmit();
    emit QuorumPctSet(ERC20_VOTE_QUORUM_PCT, ERC20_VETO_QUORUM_PCT);
    vm.expectEmit();
    emit PeriodPctSet(uint16(ONE_QUARTER_IN_BPS), uint16(TWO_QUARTERS_IN_BPS));
    vm.expectEmit();
    emit LlamaTokenVotingInstanceCreated(
      address(EXECUTOR),
      CORE,
      address(erc20VotesToken),
      llamaTokenAdapterTimestampLogic,
      llamaERC20TokenAdapter,
      0,
      llamaERC20TokenGovernor,
      block.chainid
    );
    CORE.executeAction(actionInfo);

    assertEq(address(llamaERC20TokenAdapter.token()), address(erc20VotesToken));
    assertEq(LlamaTokenAdapterVotesTimestamp(address(llamaERC20TokenAdapter)).CLOCK_MODE(), "mode=timestamp");
    assertEq(address(llamaERC20TokenGovernor.llamaCore()), address(CORE));
    assertEq(address(llamaERC20TokenGovernor.tokenAdapter()), address(llamaERC20TokenAdapter));
    assertEq(llamaERC20TokenGovernor.creationThreshold(), ERC20_CREATION_THRESHOLD);
    (uint16 voteQuorumPct, uint16 vetoQuorumPct) = llamaERC20TokenGovernor.getQuorum();
    assertEq(voteQuorumPct, ERC20_VOTE_QUORUM_PCT);
    assertEq(vetoQuorumPct, ERC20_VETO_QUORUM_PCT);
    (uint16 delayPeriodPct, uint16 castingPeriodPct) = llamaERC20TokenGovernor.getPeriodPcts();
    assertEq(delayPeriodPct, uint16(ONE_QUARTER_IN_BPS));
    assertEq(castingPeriodPct, uint16(TWO_QUARTERS_IN_BPS));
  }

  function test_CanDeployERC721TokenVotingModule() public {
    bytes memory adapterConfig = abi.encode(LlamaTokenAdapterVotesTimestamp.Config(address(erc721VotesToken)));
    LlamaTokenVotingConfig memory config = LlamaTokenVotingConfig(
      CORE, llamaTokenAdapterTimestampLogic, adapterConfig, 0, ERC721_CREATION_THRESHOLD, defaultCasterConfig
    );

    // Set up action to call `deploy` with the ERC721 token.
    bytes memory data = abi.encodeWithSelector(LlamaTokenVotingFactory.deploy.selector, config);
    ActionInfo memory actionInfo = _setPermissionCreateApproveAndQueueAction(data);

    bytes32 salt = keccak256(abi.encodePacked(address(EXECUTOR), address(CORE), adapterConfig, uint256(0)));

    // Compute addresses of ERC721 Token Voting Module
    LlamaTokenGovernor llamaERC721TokenGovernor = LlamaTokenGovernor(
      Clones.predictDeterministicAddress(
        address(llamaTokenGovernorLogic),
        salt,
        address(tokenVotingFactory) // deployer
      )
    );
    ILlamaTokenAdapter llamaERC721TokenAdapter = ILlamaTokenAdapter(
      Clones.predictDeterministicAddress(
        address(llamaTokenAdapterTimestampLogic),
        salt,
        address(tokenVotingFactory) // deployer
      )
    );

    // Execute call to `deploy`.
    vm.expectEmit();
    emit ActionThresholdSet(ERC721_CREATION_THRESHOLD);
    vm.expectEmit();
    emit QuorumPctSet(ERC721_VOTE_QUORUM_PCT, ERC721_VETO_QUORUM_PCT);
    vm.expectEmit();
    emit PeriodPctSet(uint16(ONE_QUARTER_IN_BPS), uint16(TWO_QUARTERS_IN_BPS));
    vm.expectEmit();
    emit LlamaTokenVotingInstanceCreated(
      address(EXECUTOR),
      CORE,
      address(erc721VotesToken),
      llamaTokenAdapterTimestampLogic,
      llamaERC721TokenAdapter,
      0,
      llamaERC721TokenGovernor,
      block.chainid
    );
    CORE.executeAction(actionInfo);

    assertEq(address(llamaERC721TokenAdapter.token()), address(erc721VotesToken));
    assertEq(LlamaTokenAdapterVotesTimestamp(address(llamaERC721TokenAdapter)).CLOCK_MODE(), "mode=timestamp");
    assertEq(address(llamaERC721TokenGovernor.llamaCore()), address(CORE));
    assertEq(address(llamaERC721TokenGovernor.tokenAdapter()), address(llamaERC721TokenAdapter));
    assertEq(llamaERC721TokenGovernor.creationThreshold(), ERC721_CREATION_THRESHOLD);
    (uint16 voteQuorumPct, uint16 vetoQuorumPct) = llamaERC721TokenGovernor.getQuorum();
    assertEq(voteQuorumPct, ERC721_VOTE_QUORUM_PCT);
    assertEq(vetoQuorumPct, ERC721_VETO_QUORUM_PCT);
    (uint16 delayPeriodPct, uint16 castingPeriodPct) = llamaERC721TokenGovernor.getPeriodPcts();
    assertEq(delayPeriodPct, uint16(ONE_QUARTER_IN_BPS));
    assertEq(castingPeriodPct, uint16(TWO_QUARTERS_IN_BPS));
  }

  function test_CanBeDeployedByAnyone(address randomCaller) public {
    vm.assume(randomCaller != address(0));
    vm.deal(randomCaller, 1 ether);

    bytes memory adapterConfig = abi.encode(LlamaTokenAdapterVotesTimestamp.Config(address(erc20VotesToken)));
    bytes32 salt = keccak256(abi.encodePacked(randomCaller, address(CORE), adapterConfig, uint256(0)));

    LlamaTokenGovernor llamaERC20TokenGovernor = LlamaTokenGovernor(
      Clones.predictDeterministicAddress(
        address(llamaTokenGovernorLogic),
        salt,
        address(tokenVotingFactory) // deployer
      )
    );
    ILlamaTokenAdapter llamaERC20TokenAdapter = ILlamaTokenAdapter(
      Clones.predictDeterministicAddress(
        address(llamaTokenAdapterTimestampLogic),
        salt,
        address(tokenVotingFactory) // deployer
      )
    );

    vm.expectEmit();
    emit ActionThresholdSet(ERC20_CREATION_THRESHOLD);
    vm.expectEmit();
    emit QuorumPctSet(ERC20_VOTE_QUORUM_PCT, ERC20_VETO_QUORUM_PCT);
    vm.expectEmit();
    emit PeriodPctSet(uint16(ONE_QUARTER_IN_BPS), uint16(TWO_QUARTERS_IN_BPS));
    vm.expectEmit();
    emit LlamaTokenVotingInstanceCreated(
      randomCaller,
      CORE,
      address(erc20VotesToken),
      llamaTokenAdapterTimestampLogic,
      llamaERC20TokenAdapter,
      0,
      llamaERC20TokenGovernor,
      block.chainid
    );

    LlamaTokenVotingConfig memory config = LlamaTokenVotingConfig(
      CORE, llamaTokenAdapterTimestampLogic, adapterConfig, 0, ERC20_CREATION_THRESHOLD, defaultCasterConfig
    );

    vm.prank(randomCaller);
    tokenVotingFactory.deploy(config);

    assertEq(address(llamaERC20TokenAdapter.token()), address(erc20VotesToken));
    assertEq(LlamaTokenAdapterVotesTimestamp(address(llamaERC20TokenAdapter)).CLOCK_MODE(), "mode=timestamp");
    assertEq(address(llamaERC20TokenGovernor.llamaCore()), address(CORE));
    assertEq(address(llamaERC20TokenGovernor.tokenAdapter()), address(llamaERC20TokenAdapter));
    assertEq(llamaERC20TokenGovernor.creationThreshold(), ERC20_CREATION_THRESHOLD);
    (uint16 voteQuorumPct, uint16 vetoQuorumPct) = llamaERC20TokenGovernor.getQuorum();
    assertEq(voteQuorumPct, ERC20_VOTE_QUORUM_PCT);
    assertEq(vetoQuorumPct, ERC20_VETO_QUORUM_PCT);
    (uint16 delayPeriodPct, uint16 castingPeriodPct) = llamaERC20TokenGovernor.getPeriodPcts();
    assertEq(delayPeriodPct, uint16(ONE_QUARTER_IN_BPS));
    assertEq(castingPeriodPct, uint16(TWO_QUARTERS_IN_BPS));
  }

  function test_CanBeDeployedMoreThanOnceBySameDeployer() public {
    /////////////////////
    // First deployment//
    /////////////////////

    bytes memory adapterConfig = abi.encode(LlamaTokenAdapterVotesTimestamp.Config(address(erc20VotesToken)));
    LlamaTokenVotingConfig memory config = LlamaTokenVotingConfig(
      CORE, llamaTokenAdapterTimestampLogic, adapterConfig, 0, ERC20_CREATION_THRESHOLD, defaultCasterConfig
    );

    // Set up action to call `deploy` with the ERC20 token.
    bytes memory data = abi.encodeWithSelector(LlamaTokenVotingFactory.deploy.selector, config);

    ActionInfo memory actionInfo = _setPermissionCreateApproveAndQueueAction(data);

    bytes32 salt = keccak256(abi.encodePacked(address(EXECUTOR), address(CORE), adapterConfig, uint256(0)));

    // Compute addresses of ERC20 Token Voting Module
    LlamaTokenGovernor llamaERC20TokenGovernor = LlamaTokenGovernor(
      Clones.predictDeterministicAddress(
        address(llamaTokenGovernorLogic),
        salt,
        address(tokenVotingFactory) // deployer
      )
    );
    ILlamaTokenAdapter llamaERC20TokenAdapter = ILlamaTokenAdapter(
      Clones.predictDeterministicAddress(
        address(llamaTokenAdapterTimestampLogic),
        salt,
        address(tokenVotingFactory) // deployer
      )
    );

    // Execute call to `deploy`.
    vm.expectEmit();
    emit LlamaTokenVotingInstanceCreated(
      address(EXECUTOR),
      CORE,
      address(erc20VotesToken),
      llamaTokenAdapterTimestampLogic,
      llamaERC20TokenAdapter,
      0,
      llamaERC20TokenGovernor,
      block.chainid
    );
    CORE.executeAction(actionInfo);

    //////////////////////
    // Second deployment//
    //////////////////////

    adapterConfig = abi.encode(LlamaTokenAdapterVotesTimestamp.Config(address(erc20VotesToken)));
    config = LlamaTokenVotingConfig(
      CORE, llamaTokenAdapterTimestampLogic, adapterConfig, 1, ERC20_CREATION_THRESHOLD, defaultCasterConfig
    );

    // Set up action to call `deploy` with the ERC20 token.
    data = abi.encodeWithSelector(LlamaTokenVotingFactory.deploy.selector, config);

    actionInfo = _setPermissionCreateApproveAndQueueAction(data);

    salt = keccak256(abi.encodePacked(address(EXECUTOR), address(CORE), adapterConfig, uint256(1)));

    // Compute addresses of ERC20 Token Voting Module
    llamaERC20TokenGovernor = LlamaTokenGovernor(
      Clones.predictDeterministicAddress(
        address(llamaTokenGovernorLogic),
        salt, // salt
        address(tokenVotingFactory) // deployer
      )
    );
    llamaERC20TokenAdapter = ILlamaTokenAdapter(
      Clones.predictDeterministicAddress(
        address(llamaTokenAdapterTimestampLogic),
        salt,
        address(tokenVotingFactory) // deployer
      )
    );

    // Execute call to `deploy`.
    vm.expectEmit();
    emit LlamaTokenVotingInstanceCreated(
      address(EXECUTOR),
      CORE,
      address(erc20VotesToken),
      llamaTokenAdapterTimestampLogic,
      llamaERC20TokenAdapter,
      1,
      llamaERC20TokenGovernor,
      block.chainid
    );
    CORE.executeAction(actionInfo);
  }
}
