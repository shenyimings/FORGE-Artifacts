// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";

import {LlamaTokenVotingTestSetup} from "test/token-voting/LlamaTokenVotingTestSetup.sol";
import {LlamaCoreSigUtils} from "test/utils/LlamaCoreSigUtils.sol";

import {ActionState, VoteType} from "src/lib/Enums.sol";
import {Action, ActionInfo} from "src/lib/Structs.sol";
import {ILlamaCore} from "src/interfaces/ILlamaCore.sol";
import {ILlamaPolicy} from "src/interfaces/ILlamaPolicy.sol";
import {ILlamaRelativeStrategyBase} from "src/interfaces/ILlamaRelativeStrategyBase.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {PeriodPctCheckpoints} from "src/lib/PeriodPctCheckpoints.sol";
import {QuorumCheckpoints} from "src/lib/QuorumCheckpoints.sol";
import {LlamaTokenAdapterVotesTimestamp} from "src/token-voting/token-adapters/LlamaTokenAdapterVotesTimestamp.sol";
import {ILlamaTokenAdapter} from "src/token-voting/interfaces/ILlamaTokenAdapter.sol";
import {LlamaTokenGovernor} from "src/token-voting/LlamaTokenGovernor.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";

contract LlamaTokenGovernorCasting is LlamaTokenVotingTestSetup, LlamaCoreSigUtils {
  event VoteCast(uint256 id, address indexed tokenholder, uint8 indexed support, uint256 weight, string reason);
  event ApprovalSubmitted(
    uint256 id,
    address indexed caller,
    uint8 indexed role,
    uint256 weightFor,
    uint256 weightAgainst,
    uint256 weightAbstain
  );
  event DisapprovalSubmitted(
    uint256 id,
    address indexed caller,
    uint8 indexed role,
    uint256 weightFor,
    uint256 weightAgainst,
    uint256 weightAbstain
  );
  event VetoCast(uint256 id, address indexed tokenholder, uint8 indexed support, uint256 weight, string reason);
  event QuorumPctSet(uint16 voteQuorumPct, uint16 vetoQuorumPct);
  event PeriodPctSet(uint16 delayPeriodPct, uint16 castingPeriodPct);

  ActionInfo actionInfo;
  uint256 actionCreationTime;
  LlamaTokenGovernor llamaERC20TokenGovernor;
  ILlamaStrategy tokenVotingStrategy;

  function setUp() public virtual override {
    LlamaTokenVotingTestSetup.setUp();

    // Mint tokens to tokenholders so that there is an existing supply
    erc20VotesToken.mint(tokenHolder1, ERC20_CREATION_THRESHOLD / 2);
    vm.prank(tokenHolder1);
    erc20VotesToken.delegate(tokenHolder1);

    erc20VotesToken.mint(tokenHolder2, ERC20_CREATION_THRESHOLD / 2);
    vm.prank(tokenHolder2);
    erc20VotesToken.delegate(tokenHolder2);

    erc20VotesToken.mint(tokenHolder3, ERC20_CREATION_THRESHOLD / 2);
    vm.prank(tokenHolder3);
    erc20VotesToken.delegate(tokenHolder3);

    // Mine block so that the ERC20 and ERC721 supply will be available when doing a past timestamp check at initialize
    // during deployment.
    mineBlock();

    // Deploy ERC20 Token Voting Module.
    llamaERC20TokenGovernor = _deployERC20TokenVotingModuleAndSetRole();

    // Mine block so that Token Voting Caster Role will have supply during action creation (due to past timestamp check)
    mineBlock();

    tokenVotingStrategy = _deployRelativeQuantityQuorumAndSetRolePermissionToCoreTeam(tokenVotingGovernorRole);
    actionInfo = _createActionWithTokenVotingStrategy(tokenVotingStrategy);
    Action memory action = CORE.getAction(actionInfo.id);
    actionCreationTime = action.creationTime;

    // Setting LlamaTokenGovernor's EIP-712 Domain Hash
    setDomainHash(
      LlamaCoreSigUtils.EIP712Domain({
        name: CORE.name(),
        version: "1",
        chainId: block.chainid,
        verifyingContract: address(llamaERC20TokenGovernor)
      })
    );
  }

  function castVotesFor() public {
    vm.prank(tokenHolder1);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");
    vm.prank(tokenHolder2);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");
    vm.prank(tokenHolder3);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");
  }

  function castVetosFor() public {
    vm.prank(tokenHolder1);
    llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");
    vm.prank(tokenHolder2);
    llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");
    vm.prank(tokenHolder3);
    llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");
  }

  function createTimestampTokenAdapter(address token, uint256 nonce) public returns (ILlamaTokenAdapter tokenAdapter) {
    bytes memory adapterConfig = abi.encode(LlamaTokenAdapterVotesTimestamp.Config(address(token)));

    bytes32 salt = keccak256(abi.encodePacked(msg.sender, address(CORE), adapterConfig, nonce));

    tokenAdapter = ILlamaTokenAdapter(Clones.cloneDeterministic(address(llamaTokenAdapterTimestampLogic), salt));
    tokenAdapter.initialize(adapterConfig);
  }
}

contract Constructor is LlamaTokenGovernorCasting {
  function test_RevertIf_InitializeImplementationContract() public {
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    llamaTokenGovernorLogic.initialize(
      CORE, ILlamaTokenAdapter(address(0)), ERC20_CREATION_THRESHOLD, defaultCasterConfig
    );
  }
}

contract Initialize is LlamaTokenGovernorCasting {
  function test_RevertIf_InitializeAlreadyInitializedContract() public {
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    llamaERC20TokenGovernor.initialize(
      CORE, ILlamaTokenAdapter(address(0)), ERC20_CREATION_THRESHOLD, defaultCasterConfig
    );
  }
}

contract CastVote is LlamaTokenGovernorCasting {
  function setUp() public virtual override {
    LlamaTokenGovernorCasting.setUp();
    _skipVotingDelay(actionInfo);
  }

  function test_RevertIf_NotPastVotingDelay() public {
    vm.warp(block.timestamp - 1);
    vm.expectRevert(LlamaTokenGovernor.DelayPeriodNotOver.selector);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");
  }

  function test_RevertIf_ActionInfoMismatch(ActionInfo memory notActionInfo) public {
    vm.assume(notActionInfo.id != actionInfo.id);
    vm.expectRevert();
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, notActionInfo, uint8(VoteType.For), "");
  }

  function test_RevertIf_ActionNotActive() public {
    vm.warp(actionCreationTime + APPROVAL_PERIOD + 1);
    vm.expectRevert(abi.encodeWithSelector(LlamaTokenGovernor.InvalidActionState.selector, ActionState.Failed));
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");
  }

  function test_RevertIf_RoleHasBeenRevokedBeforeActionCreation() public {
    // Revoking Caster role from Token Holder Caster and assigning it to a random address so that Role has supply.
    vm.startPrank(address(EXECUTOR));
    POLICY.setRoleHolder(tokenVotingGovernorRole, address(llamaERC20TokenGovernor), 0, 0);
    POLICY.setRoleHolder(tokenVotingGovernorRole, address(0xdeadbeef), DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    vm.stopPrank();

    // Mine block so that the revoke will be effective
    mineBlock();

    ActionInfo memory _actionInfo = _createActionWithTokenVotingStrategy(tokenVotingStrategy);
    Action memory action = CORE.getAction(_actionInfo.id);

    // Skip voting delay
    vm.warp(action.creationTime + ((APPROVAL_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS) + 1);

    vm.startPrank(tokenHolder1);
    vm.expectRevert(LlamaTokenGovernor.InvalidPolicyholder.selector);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, _actionInfo, uint8(VoteType.For), "");
  }

  function test_RevertIf_AlreadyCastedVote() public {
    vm.startPrank(tokenHolder1);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");

    vm.expectRevert(LlamaTokenGovernor.DuplicateCast.selector);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");
  }

  function test_RevertIf_InvalidSupport() public {
    vm.expectRevert(abi.encodeWithSelector(LlamaTokenGovernor.InvalidSupport.selector, uint8(3)));
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, actionInfo, 3, "");
  }

  function test_RevertIf_CastingPeriodOver() public {
    uint256 delayPeriodEndTime = actionCreationTime + ((APPROVAL_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS);
    uint256 castingPeriodEndTime = delayPeriodEndTime + ((APPROVAL_PERIOD * TWO_QUARTERS_IN_BPS) / ONE_HUNDRED_IN_BPS);
    vm.warp(castingPeriodEndTime + 1);
    vm.expectRevert(LlamaTokenGovernor.CastingPeriodOver.selector);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");
  }

  function test_CanCastWithWeightZero() public {
    vm.expectEmit();
    emit VoteCast(actionInfo.id, address(this), uint8(VoteType.For), 0, "");
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");
  }

  function test_CanCastWhenCountisMax() public {
    // Warping to delayPeriodEndTime.
    vm.warp(actionCreationTime + ((APPROVAL_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS));
    // Minting type(uint128).max tokens and delegating
    erc20VotesToken.mint(address(0xdeadbeef), type(uint128).max);
    vm.prank(address(0xdeadbeef));
    erc20VotesToken.delegate(address(0xdeadbeef));

    // Warping to delayPeriodEndTime + 1 so that voting can start.
    mineBlock();
    // Casting vote with weight type(uint128).max. Count should now be type(uint128).max.
    vm.prank(address(0xdeadbeef));
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");

    (uint128 votesFor,,,,,) = llamaERC20TokenGovernor.casts(actionInfo.id);
    assertEq(votesFor, type(uint128).max);

    // Can still cast even if count is max.
    vm.expectEmit();
    emit VoteCast(actionInfo.id, tokenHolder1, uint8(VoteType.For), ERC20_CREATION_THRESHOLD / 2, "");
    vm.prank(tokenHolder1);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");

    (votesFor,,,,,) = llamaERC20TokenGovernor.casts(actionInfo.id);
    assertEq(votesFor, type(uint128).max);
  }

  function test_CastsVoteCorrectly(uint8 support) public {
    support = uint8(bound(support, uint8(VoteType.Against), uint8(VoteType.Against)));
    vm.expectEmit();
    emit VoteCast(
      actionInfo.id, tokenHolder1, support, erc20VotesToken.getPastVotes(tokenHolder1, block.timestamp - 1), ""
    );
    vm.prank(tokenHolder1);
    uint128 weight = llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, actionInfo, support, "");
    assertEq(weight, erc20VotesToken.getPastVotes(tokenHolder1, block.timestamp - 1));
  }

  function test_CastsVoteCorrectly_WithReason() public {
    vm.expectEmit();
    emit VoteCast(
      actionInfo.id,
      tokenHolder1,
      uint8(VoteType.For),
      erc20VotesToken.getPastVotes(tokenHolder1, erc20VotesToken.clock() - 1),
      "reason"
    );
    vm.prank(tokenHolder1);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "reason");
  }

  function test_GetsWeightAtDelayPeriodTimestamp() public {
    // Currently we are at delayPeriodEndTime + 1.
    vm.startPrank(tokenHolder1);
    assertEq(erc20VotesToken.getVotes(tokenHolder1), ERC20_CREATION_THRESHOLD / 2);
    // Burning all of tokenHolder1's votes at delayPeriodEndTime + 1
    erc20VotesToken.transfer(address(0xdeadbeef), ERC20_CREATION_THRESHOLD / 2);
    assertEq(erc20VotesToken.getVotes(tokenHolder1), 0);
    // However tokenholder1 is able to vote with the weight they had at delayPeriodEndTime
    vm.expectEmit();
    emit VoteCast(actionInfo.id, tokenHolder1, 1, ERC20_CREATION_THRESHOLD / 2, "");
    uint128 weight = llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, actionInfo, 1, "");
    assertEq(weight, ERC20_CREATION_THRESHOLD / 2);
    vm.stopPrank();
  }
}

contract CastVoteBySig is LlamaTokenGovernorCasting {
  function setUp() public virtual override {
    LlamaTokenGovernorCasting.setUp();
    _skipVotingDelay(actionInfo);
  }

  function createOffchainSignature(ActionInfo memory _actionInfo, uint256 privateKey)
    internal
    view
    returns (uint8 v, bytes32 r, bytes32 s)
  {
    LlamaCoreSigUtils.CastVote memory castApproval = LlamaCoreSigUtils.CastVote({
      role: tokenVotingGovernorRole,
      actionInfo: _actionInfo,
      support: uint8(VoteType.For),
      reason: "",
      tokenHolder: tokenHolder1,
      nonce: 0
    });
    bytes32 digest = getCastVoteTypedDataHash(castApproval);
    (v, r, s) = vm.sign(privateKey, digest);
  }

  function castVoteBySig(ActionInfo memory _actionInfo, uint8 support, uint8 v, bytes32 r, bytes32 s) internal {
    llamaERC20TokenGovernor.castVoteBySig(tokenHolder1, tokenVotingGovernorRole, _actionInfo, support, "", v, r, s);
  }

  function test_CastsVoteBySig() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, tokenHolder1PrivateKey);

    vm.expectEmit();
    emit VoteCast(
      actionInfo.id,
      tokenHolder1,
      uint8(VoteType.For),
      erc20VotesToken.getPastVotes(tokenHolder1, block.timestamp - 1),
      ""
    );

    castVoteBySig(actionInfo, uint8(VoteType.For), v, r, s);
  }

  function test_CheckNonceIncrements() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, tokenHolder1PrivateKey);

    assertEq(llamaERC20TokenGovernor.nonces(tokenHolder1, LlamaTokenGovernor.castVoteBySig.selector), 0);
    castVoteBySig(actionInfo, uint8(VoteType.For), v, r, s);
    assertEq(llamaERC20TokenGovernor.nonces(tokenHolder1, LlamaTokenGovernor.castVoteBySig.selector), 1);
  }

  function test_OperationCannotBeReplayed() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, tokenHolder1PrivateKey);
    castVoteBySig(actionInfo, uint8(VoteType.For), v, r, s);
    // Invalid Signature error since the recovered signer address during the second call is not the same as
    // erc20VotesTokenholder since nonce has increased.
    vm.expectRevert(LlamaTokenGovernor.InvalidSignature.selector);
    castVoteBySig(actionInfo, uint8(VoteType.For), v, r, s);
  }

  function test_RevertIf_SignerIsNotTokenHolder() public {
    (, uint256 randomSignerPrivateKey) = makeAddrAndKey("randomSigner");
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, randomSignerPrivateKey);
    // Invalid Signature error since the recovered signer address is not the same as the erc20VotesTokenholder passed
    // in as parameter.
    vm.expectRevert(LlamaTokenGovernor.InvalidSignature.selector);
    castVoteBySig(actionInfo, uint8(VoteType.For), v, r, s);
  }

  function test_RevertIf_SignerIsZeroAddress() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, tokenHolder1PrivateKey);
    // Invalid Signature error since the recovered signer address is zero address due to invalid signature values
    // (v,r,s).
    vm.expectRevert(LlamaTokenGovernor.InvalidSignature.selector);
    castVoteBySig(actionInfo, uint8(VoteType.For), (v + 1), r, s);
  }

  function test_RevertIf_TokenHolderIncrementsNonce() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, tokenHolder1PrivateKey);

    vm.prank(tokenHolder1);
    llamaERC20TokenGovernor.incrementNonce(LlamaTokenGovernor.castVoteBySig.selector);

    // Invalid Signature error since the recovered signer address during the call is not the same as
    // erc20VotesTokenholder since nonce has increased.
    vm.expectRevert(LlamaTokenGovernor.InvalidSignature.selector);
    castVoteBySig(actionInfo, uint8(VoteType.For), v, r, s);
  }
}

contract CastVeto is LlamaTokenGovernorCasting {
  function setUp() public virtual override {
    LlamaTokenGovernorCasting.setUp();

    _skipVotingDelay(actionInfo);
    castVotesFor();

    uint256 delayPeriodEndTime = actionCreationTime + ((APPROVAL_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS);
    uint256 castingPeriodEndTime = delayPeriodEndTime + ((APPROVAL_PERIOD * TWO_QUARTERS_IN_BPS) / ONE_HUNDRED_IN_BPS);
    vm.warp(castingPeriodEndTime + 1);

    llamaERC20TokenGovernor.submitApproval(actionInfo);
    _skipVetoDelay(actionInfo);
  }

  function test_RevertIf_NotPastVotingDelay() public {
    vm.warp(block.timestamp - 1);
    vm.expectRevert(LlamaTokenGovernor.DelayPeriodNotOver.selector);
    llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");
  }

  function test_RevertIf_ActionInfoMismatch(ActionInfo memory notActionInfo) public {
    vm.assume(notActionInfo.id != actionInfo.id);
    vm.expectRevert();
    llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, notActionInfo, uint8(VoteType.For), "");
  }

  function test_RevertIf_ActionNotQueued() public {
    bytes memory data = abi.encodeCall(mockProtocol.pause, (true));
    vm.prank(coreTeam1);
    uint256 actionId = CORE.createAction(CORE_TEAM_ROLE, tokenVotingStrategy, address(mockProtocol), 0, data, "");
    ActionInfo memory _actionInfo =
      ActionInfo(actionId, coreTeam1, CORE_TEAM_ROLE, tokenVotingStrategy, address(mockProtocol), 0, data);
    // Currently at actionCreationTime which is Active state.
    vm.expectRevert(abi.encodeWithSelector(LlamaTokenGovernor.InvalidActionState.selector, ActionState.Active));
    llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, _actionInfo, uint8(VoteType.For), "");
  }

  function test_RevertIf_AlreadyCastedVote() public {
    vm.startPrank(tokenHolder1);
    llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");

    vm.expectRevert(LlamaTokenGovernor.DuplicateCast.selector);
    llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");
  }

  function test_RevertIf_InvalidSupport() public {
    vm.expectRevert(abi.encodeWithSelector(LlamaTokenGovernor.InvalidSupport.selector, uint8(3)));
    llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, actionInfo, 3, "");
  }

  function test_RevertIf_CastingPeriodOver() public {
    Action memory action = CORE.getAction(actionInfo.id);
    uint256 delayPeriodEndTime =
      (action.minExecutionTime - QUEUING_PERIOD) + ((QUEUING_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS);
    uint256 castingPeriodEndTime = delayPeriodEndTime + ((QUEUING_PERIOD * TWO_QUARTERS_IN_BPS) / ONE_HUNDRED_IN_BPS);
    vm.warp(castingPeriodEndTime + 1);
    vm.expectRevert(LlamaTokenGovernor.CastingPeriodOver.selector);
    llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");
  }

  function test_CanCastWithWeightZero() public {
    vm.expectEmit();
    emit VetoCast(actionInfo.id, address(this), uint8(VoteType.For), 0, "");
    llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");
  }

  function test_CanCastWhenCountisMax() public {
    // Warping to delayPeriodEndTime.
    Action memory action = CORE.getAction(actionInfo.id);
    vm.warp((action.minExecutionTime - QUEUING_PERIOD) + ((QUEUING_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS));
    // Minting type(uint128).max tokens and delegating
    erc20VotesToken.mint(address(0xdeadbeef), type(uint128).max);
    vm.prank(address(0xdeadbeef));
    erc20VotesToken.delegate(address(0xdeadbeef));

    // Warping to delayPeriodEndTime + 1 so that voting can start.
    mineBlock();
    // Casting vote with weight type(uint128).max. Count should now be type(uint128).max.
    vm.prank(address(0xdeadbeef));
    llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");

    (,,, uint128 vetoesFor,,) = llamaERC20TokenGovernor.casts(actionInfo.id);
    assertEq(vetoesFor, type(uint128).max);

    // Can still cast even if count is max.
    vm.expectEmit();
    emit VetoCast(actionInfo.id, tokenHolder1, uint8(VoteType.For), ERC20_CREATION_THRESHOLD / 2, "");
    vm.prank(tokenHolder1);
    llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");

    (,,, vetoesFor,,) = llamaERC20TokenGovernor.casts(actionInfo.id);
    assertEq(vetoesFor, type(uint128).max);
  }

  function test_CastsVetoCorrectly(uint8 support) public {
    support = uint8(bound(support, uint8(VoteType.Against), uint8(VoteType.Abstain)));
    vm.expectEmit();
    emit VetoCast(
      actionInfo.id, tokenHolder1, support, erc20VotesToken.getPastVotes(tokenHolder1, block.timestamp - 1), ""
    );
    vm.prank(tokenHolder1);
    uint128 weight = llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, actionInfo, support, "");
    assertEq(weight, erc20VotesToken.getPastVotes(tokenHolder1, block.timestamp - 1));
  }

  function test_CastsVetoCorrectly_WithReason() public {
    vm.expectEmit();
    emit VetoCast(
      actionInfo.id,
      tokenHolder1,
      uint8(VoteType.For),
      erc20VotesToken.getPastVotes(tokenHolder1, erc20VotesToken.clock() - 1),
      "reason"
    );
    vm.prank(tokenHolder1);
    llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "reason");
  }

  function test_GetsWeightAtDelayPeriodTimestamp() public {
    // Currently we are at delayPeriodEndTime + 1.
    vm.startPrank(tokenHolder1);
    assertEq(erc20VotesToken.getVotes(tokenHolder1), ERC20_CREATION_THRESHOLD / 2);
    // Burning all of tokenHolder1's votes at delayPeriodEndTime + 1
    erc20VotesToken.transfer(address(0xdeadbeef), ERC20_CREATION_THRESHOLD / 2);
    assertEq(erc20VotesToken.getVotes(tokenHolder1), 0);
    // However tokenholder1 is able to vote with the weight they had at delayPeriodEndTime
    vm.expectEmit();
    emit VetoCast(actionInfo.id, tokenHolder1, 1, ERC20_CREATION_THRESHOLD / 2, "");
    uint128 weight = llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, actionInfo, 1, "");
    assertEq(weight, ERC20_CREATION_THRESHOLD / 2);
    vm.stopPrank();
  }
}

contract CastVetoBySig is LlamaTokenGovernorCasting {
  function setUp() public virtual override {
    LlamaTokenGovernorCasting.setUp();

    _skipVotingDelay(actionInfo);
    castVotesFor();

    uint256 delayPeriodEndTime = actionCreationTime + ((APPROVAL_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS);
    uint256 castingPeriodEndTime = delayPeriodEndTime + ((APPROVAL_PERIOD * TWO_QUARTERS_IN_BPS) / ONE_HUNDRED_IN_BPS);
    vm.warp(castingPeriodEndTime + 1);

    llamaERC20TokenGovernor.submitApproval(actionInfo);
    _skipVetoDelay(actionInfo);
  }

  function createOffchainSignature(ActionInfo memory _actionInfo, uint256 privateKey)
    internal
    view
    returns (uint8 v, bytes32 r, bytes32 s)
  {
    LlamaCoreSigUtils.CastVeto memory castDisapproval = LlamaCoreSigUtils.CastVeto({
      role: tokenVotingGovernorRole,
      actionInfo: _actionInfo,
      support: uint8(VoteType.For),
      reason: "",
      tokenHolder: tokenHolder1,
      nonce: 0
    });
    bytes32 digest = getCastVetoTypedDataHash(castDisapproval);
    (v, r, s) = vm.sign(privateKey, digest);
  }

  function castVetoBySig(ActionInfo memory _actionInfo, uint8 v, bytes32 r, bytes32 s) internal {
    llamaERC20TokenGovernor.castVetoBySig(
      tokenHolder1, tokenVotingGovernorRole, _actionInfo, uint8(VoteType.For), "", v, r, s
    );
  }

  function test_CastsVetoBySig() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, tokenHolder1PrivateKey);

    vm.expectEmit();
    emit VetoCast(
      actionInfo.id,
      tokenHolder1,
      uint8(VoteType.For),
      erc20VotesToken.getPastVotes(tokenHolder1, erc20VotesToken.clock() - 1),
      ""
    );

    castVetoBySig(actionInfo, v, r, s);

    // assertEq(CORE.getAction(0).totalDisapprovals, 1);
    // assertEq(CORE.disapprovals(0, disapproverDrake), true);
  }

  function test_CheckNonceIncrements() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, tokenHolder1PrivateKey);

    assertEq(llamaERC20TokenGovernor.nonces(tokenHolder1, LlamaTokenGovernor.castVetoBySig.selector), 0);
    castVetoBySig(actionInfo, v, r, s);
    assertEq(llamaERC20TokenGovernor.nonces(tokenHolder1, LlamaTokenGovernor.castVetoBySig.selector), 1);
  }

  function test_OperationCannotBeReplayed() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, tokenHolder1PrivateKey);
    castVetoBySig(actionInfo, v, r, s);
    // Invalid Signature error since the recovered signer address during the second call is not the same as
    // erc20VotesTokenholder
    // since nonce has increased.
    vm.expectRevert(LlamaTokenGovernor.InvalidSignature.selector);
    castVetoBySig(actionInfo, v, r, s);
  }

  function test_RevertIf_SignerIsNotPolicyHolder() public {
    (, uint256 randomSignerPrivateKey) = makeAddrAndKey("randomSigner");
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, randomSignerPrivateKey);
    // Invalid Signature error since the recovered signer address during the second call is not the same as
    // erc20VotesTokenholder
    // since nonce has increased.
    vm.expectRevert(LlamaTokenGovernor.InvalidSignature.selector);
    castVetoBySig(actionInfo, v, r, s);
  }

  function test_RevertIf_SignerIsZeroAddress() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, tokenHolder1PrivateKey);
    // Invalid Signature error since the recovered signer address is zero address due to invalid signature values
    // (v,r,s).
    vm.expectRevert(LlamaTokenGovernor.InvalidSignature.selector);
    castVetoBySig(actionInfo, (v + 1), r, s);
  }

  function test_RevertIf_PolicyholderIncrementsNonce() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, tokenHolder1PrivateKey);

    vm.prank(tokenHolder1);
    llamaERC20TokenGovernor.incrementNonce(LlamaTokenGovernor.castVetoBySig.selector);

    // Invalid Signature error since the recovered signer address during the second call is not the same as policyholder
    // since nonce has increased.
    vm.expectRevert(LlamaTokenGovernor.InvalidSignature.selector);
    castVetoBySig(actionInfo, v, r, s);
  }

  function test_FailsIfDisapproved() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, tokenHolder1PrivateKey);

    // First disapproval.
    vm.expectEmit();
    emit VetoCast(
      actionInfo.id,
      tokenHolder1,
      uint8(VoteType.For),
      erc20VotesToken.getPastVotes(tokenHolder1, erc20VotesToken.clock() - 1),
      ""
    );
    castVetoBySig(actionInfo, v, r, s);
    // assertEq(CORE.getAction(actionInfo.id).totalDisapprovals, 1);

    // Second disapproval.
    vm.prank(tokenHolder2);
    llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");

    Action memory action = CORE.getAction(actionInfo.id);
    uint256 delayPeriodEndTime =
      (action.minExecutionTime - QUEUING_PERIOD) + ((QUEUING_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS);
    uint256 castingPeriodEndTime = delayPeriodEndTime + ((QUEUING_PERIOD * TWO_QUARTERS_IN_BPS) / ONE_HUNDRED_IN_BPS);
    vm.warp(castingPeriodEndTime + 1);

    llamaERC20TokenGovernor.submitDisapproval(actionInfo);

    // Assertions.
    ActionState state = ActionState(CORE.getActionState(actionInfo));
    assertEq(uint8(state), uint8(ActionState.Failed));

    vm.expectRevert(abi.encodeWithSelector(ILlamaCore.InvalidActionState.selector, ActionState.Failed));
    CORE.executeAction(actionInfo);
  }
}

contract SubmitApprovals is LlamaTokenGovernorCasting {
  function setUp() public virtual override {
    LlamaTokenGovernorCasting.setUp();

    _skipVotingDelay(actionInfo);
    castVotesFor();

    uint256 delayPeriodEndTime = actionCreationTime + ((APPROVAL_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS);
    uint256 castingPeriodEndTime = delayPeriodEndTime + ((APPROVAL_PERIOD * TWO_QUARTERS_IN_BPS) / ONE_HUNDRED_IN_BPS);
    vm.warp(castingPeriodEndTime + 1);
  }

  function test_RevertIf_ActionInfoMismatch(ActionInfo memory notActionInfo) public {
    vm.assume(notActionInfo.id != actionInfo.id);
    vm.expectRevert();
    llamaERC20TokenGovernor.submitApproval(notActionInfo);
  }

  function test_RevertIf_AlreadySubmittedApproval() public {
    vm.startPrank(tokenHolder1);
    llamaERC20TokenGovernor.submitApproval(actionInfo);

    // This should revert since the underlying Action has transitioned to Queued state. Otherwise it would have reverted
    // due to `LlamaCore.DuplicateCast() error`.
    vm.expectRevert(abi.encodeWithSelector(ILlamaCore.InvalidActionState.selector, ActionState.Queued));
    llamaERC20TokenGovernor.submitApproval(actionInfo);
  }

  function test_RevertIf_SubmissionPeriodOver() public {
    vm.warp(actionCreationTime + APPROVAL_PERIOD + 1);
    vm.expectRevert(LlamaTokenGovernor.SubmissionPeriodOver.selector);
    llamaERC20TokenGovernor.submitApproval(actionInfo);
  }

  function test_RevertIf_InsufficientVotes() public {
    ActionInfo memory _actionInfo = _createActionWithTokenVotingStrategy(tokenVotingStrategy);
    Action memory action = CORE.getAction(_actionInfo.id);
    uint256 delayPeriodEndTime = action.creationTime + ((APPROVAL_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS);
    uint256 castingPeriodEndTime = delayPeriodEndTime + ((APPROVAL_PERIOD * TWO_QUARTERS_IN_BPS) / ONE_HUNDRED_IN_BPS);
    vm.warp(castingPeriodEndTime + 1);
    vm.expectRevert(abi.encodeWithSelector(LlamaTokenGovernor.InsufficientVotes.selector, 0, 75_000e18));
    llamaERC20TokenGovernor.submitApproval(_actionInfo);
  }

  function test_RevertIf_CastingPeriodNotOver() public {
    vm.warp(block.timestamp - 1);
    vm.expectRevert(LlamaTokenGovernor.CastingPeriodNotOver.selector);
    llamaERC20TokenGovernor.submitApproval(actionInfo);
  }

  function test_RevertIf_ForDoesNotSurpassAgainst() public {
    ActionInfo memory _actionInfo = _createActionWithTokenVotingStrategy(tokenVotingStrategy);
    Action memory action = CORE.getAction(_actionInfo.id);

    uint256 delayPeriodEndTime = action.creationTime + ((APPROVAL_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS);
    uint256 castingPeriodEndTime = delayPeriodEndTime + ((APPROVAL_PERIOD * TWO_QUARTERS_IN_BPS) / ONE_HUNDRED_IN_BPS);

    vm.warp(delayPeriodEndTime + 1);

    vm.prank(tokenHolder1);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, _actionInfo, uint8(VoteType.For), "");
    vm.prank(tokenHolder2);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, _actionInfo, uint8(VoteType.Against), "");
    vm.prank(tokenHolder3);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, _actionInfo, uint8(VoteType.Against), "");

    vm.warp(castingPeriodEndTime + 1);
    vm.expectRevert(
      abi.encodeWithSelector(LlamaTokenGovernor.ForDoesNotSurpassAgainst.selector, 250_000e18, 500_000e18)
    );
    llamaERC20TokenGovernor.submitApproval(_actionInfo);
  }

  function test_GovernorRoleDeterminedCorrectlyForApproval(uint8 governorRole) public {
    vm.assume(governorRole > 0);

    uint8 startingRole = POLICY.numRoles() + 1;
    if (governorRole >= startingRole) {
      for (uint256 i = startingRole; i <= governorRole; i++) {
        vm.prank(address(EXECUTOR));
        POLICY.initializeRole(RoleDescription.wrap(bytes32(abi.encode(i))));
      }
    }

    vm.prank(address(EXECUTOR));
    POLICY.setRoleHolder(governorRole, address(llamaERC20TokenGovernor), DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    uint8[] memory forceRoles;
    if (governorRole < type(uint8).max - 1) {
      vm.prank(address(EXECUTOR));
      POLICY.initializeRole(RoleDescription.wrap(bytes32(abi.encode(governorRole + 1))));

      vm.prank(address(EXECUTOR));
      POLICY.setRoleHolder(
        governorRole + 1, address(llamaERC20TokenGovernor), DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION
      );

      forceRoles = new uint8[](2);
      forceRoles[0] = governorRole;
      forceRoles[1] = governorRole + 1;
    } else {
      forceRoles = new uint8[](1);
      forceRoles[0] = governorRole;
    }

    mineBlock();

    ILlamaRelativeStrategyBase.Config memory strategyConfig = ILlamaRelativeStrategyBase.Config({
      approvalPeriod: APPROVAL_PERIOD,
      queuingPeriod: QUEUING_PERIOD,
      expirationPeriod: EXPIRATION_PERIOD,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: ONE_HUNDRED_IN_BPS,
      minDisapprovalPct: ONE_HUNDRED_IN_BPS,
      approvalRole: tokenVotingGovernorRole,
      disapprovalRole: tokenVotingGovernorRole,
      forceApprovalRoles: forceRoles,
      forceDisapprovalRoles: forceRoles
    });

    ILlamaRelativeStrategyBase.Config[] memory strategyConfigs = new ILlamaRelativeStrategyBase.Config[](1);
    strategyConfigs[0] = strategyConfig;

    vm.prank(address(EXECUTOR));
    CORE.createStrategies(RELATIVE_QUANTITY_QUORUM_LOGIC, encodeStrategyConfigs(strategyConfigs));

    ILlamaStrategy newStrategy = ILlamaStrategy(
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

    actionInfo = _createActionWithTokenVotingStrategy(newStrategy);
    Action memory action = CORE.getAction(actionInfo.id);
    actionCreationTime = action.creationTime;

    _skipVotingDelay(actionInfo);

    vm.prank(tokenHolder1);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");
    vm.prank(tokenHolder2);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");
    vm.prank(tokenHolder3);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");

    uint256 delayPeriodEndTime = actionCreationTime + ((APPROVAL_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS);
    uint256 castingPeriodEndTime = delayPeriodEndTime + ((APPROVAL_PERIOD * TWO_QUARTERS_IN_BPS) / ONE_HUNDRED_IN_BPS);
    vm.warp(castingPeriodEndTime + 1);

    vm.expectEmit();
    emit ApprovalSubmitted(actionInfo.id, address(this), governorRole, 750_000e18, 0, 0);
    llamaERC20TokenGovernor.submitApproval(actionInfo);
  }

  function test_SubmitsApprovalsCorrectly() public {
    vm.expectEmit();
    emit ApprovalSubmitted(actionInfo.id, address(this), tokenVotingGovernorRole, 750_000e18, 0, 0);
    llamaERC20TokenGovernor.submitApproval(actionInfo);
  }
}

contract SubmitDisapprovals is LlamaTokenGovernorCasting {
  function setUp() public virtual override {
    LlamaTokenGovernorCasting.setUp();

    _skipVotingDelay(actionInfo);
    castVotesFor();

    uint256 delayPeriodEndTime = actionCreationTime + ((APPROVAL_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS);
    uint256 castingPeriodEndTime = delayPeriodEndTime + ((APPROVAL_PERIOD * TWO_QUARTERS_IN_BPS) / ONE_HUNDRED_IN_BPS);
    vm.warp(castingPeriodEndTime + 1);

    llamaERC20TokenGovernor.submitApproval(actionInfo);

    _skipVetoDelay(actionInfo);
    castVetosFor();

    Action memory action = CORE.getAction(actionInfo.id);
    delayPeriodEndTime =
      (action.minExecutionTime - QUEUING_PERIOD) + ((QUEUING_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS);
    castingPeriodEndTime = delayPeriodEndTime + ((QUEUING_PERIOD * TWO_QUARTERS_IN_BPS) / ONE_HUNDRED_IN_BPS);
    vm.warp(castingPeriodEndTime + 1);
  }

  function test_RevertIf_ActionInfoMismatch(ActionInfo memory notActionInfo) public {
    vm.assume(notActionInfo.id != actionInfo.id);
    vm.expectRevert();
    llamaERC20TokenGovernor.submitDisapproval(notActionInfo);
  }

  function test_RevertIf_AlreadySubmittedDisapproval() public {
    vm.startPrank(tokenHolder1);
    llamaERC20TokenGovernor.submitDisapproval(actionInfo);

    // This should revert since the underlying Action has transitioned to Failed state. Otherwise it would have reverted
    // due to `LlamaCore.DuplicateCast() error`.
    vm.expectRevert(abi.encodeWithSelector(ILlamaCore.InvalidActionState.selector, ActionState.Failed));
    llamaERC20TokenGovernor.submitDisapproval(actionInfo);
  }

  function test_RevertIf_SubmissionPeriodOver() public {
    Action memory action = CORE.getAction(actionInfo.id);
    vm.warp(action.minExecutionTime);
    vm.expectRevert(LlamaTokenGovernor.SubmissionPeriodOver.selector);
    llamaERC20TokenGovernor.submitDisapproval(actionInfo);
  }

  function test_RevertIf_InsufficientDisapprovals() public {
    ActionInfo memory _actionInfo = _createActionWithTokenVotingStrategy(tokenVotingStrategy);
    Action memory action = CORE.getAction(_actionInfo.id);

    uint256 delayPeriodEndTime = action.creationTime + ((APPROVAL_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS);
    uint256 castingPeriodEndTime = delayPeriodEndTime + ((APPROVAL_PERIOD * TWO_QUARTERS_IN_BPS) / ONE_HUNDRED_IN_BPS);

    vm.warp(delayPeriodEndTime + 1);

    vm.prank(tokenHolder1);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, _actionInfo, uint8(VoteType.For), "");
    vm.prank(tokenHolder2);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, _actionInfo, uint8(VoteType.For), "");
    vm.prank(tokenHolder3);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, _actionInfo, uint8(VoteType.For), "");

    vm.warp(castingPeriodEndTime + 1);
    llamaERC20TokenGovernor.submitApproval(_actionInfo);

    action = CORE.getAction(_actionInfo.id);

    delayPeriodEndTime =
      (action.minExecutionTime - QUEUING_PERIOD) + ((QUEUING_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS);
    castingPeriodEndTime = delayPeriodEndTime + ((QUEUING_PERIOD * TWO_QUARTERS_IN_BPS) / ONE_HUNDRED_IN_BPS);
    vm.warp(castingPeriodEndTime + 1);
    vm.expectRevert(abi.encodeWithSelector(LlamaTokenGovernor.InsufficientVetoes.selector, 0, 75_000e18));
    llamaERC20TokenGovernor.submitDisapproval(_actionInfo);
  }

  function test_RevertIf_CastingPeriodNotOver() public {
    vm.warp(block.timestamp - 1);
    vm.expectRevert(LlamaTokenGovernor.CastingPeriodNotOver.selector);
    llamaERC20TokenGovernor.submitDisapproval(actionInfo);
  }

  function test_RevertIf_ForDoesNotSurpassAgainst() public {
    ActionInfo memory _actionInfo = _createActionWithTokenVotingStrategy(tokenVotingStrategy);
    Action memory action = CORE.getAction(_actionInfo.id);

    uint256 delayPeriodEndTime = action.creationTime + ((APPROVAL_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS);
    uint256 castingPeriodEndTime = delayPeriodEndTime + ((APPROVAL_PERIOD * TWO_QUARTERS_IN_BPS) / ONE_HUNDRED_IN_BPS);

    vm.warp(delayPeriodEndTime + 1);

    vm.prank(tokenHolder1);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, _actionInfo, uint8(VoteType.For), "");
    vm.prank(tokenHolder2);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, _actionInfo, uint8(VoteType.For), "");
    vm.prank(tokenHolder3);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, _actionInfo, uint8(VoteType.For), "");

    vm.warp(castingPeriodEndTime + 1);
    llamaERC20TokenGovernor.submitApproval(_actionInfo);

    action = CORE.getAction(_actionInfo.id);

    delayPeriodEndTime =
      (action.minExecutionTime - QUEUING_PERIOD) + ((QUEUING_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS);
    castingPeriodEndTime = delayPeriodEndTime + ((QUEUING_PERIOD * TWO_QUARTERS_IN_BPS) / ONE_HUNDRED_IN_BPS);

    vm.warp(delayPeriodEndTime + 1);

    vm.prank(tokenHolder1);
    llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, _actionInfo, uint8(VoteType.For), "");
    vm.prank(tokenHolder2);
    llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, _actionInfo, uint8(VoteType.Against), "");
    vm.prank(tokenHolder3);
    llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, _actionInfo, uint8(VoteType.Against), "");

    vm.warp(castingPeriodEndTime + 1);
    vm.expectRevert(
      abi.encodeWithSelector(LlamaTokenGovernor.ForDoesNotSurpassAgainst.selector, 250_000e18, 500_000e18)
    );
    llamaERC20TokenGovernor.submitDisapproval(_actionInfo);
  }

  function test_GovernorRoleDeterminedCorrectlyForDisapproval(uint8 governorRole) public {
    vm.assume(governorRole > 0);

    uint8 startingRole = POLICY.numRoles() + 1;
    if (governorRole >= startingRole) {
      for (uint256 i = startingRole; i <= governorRole; i++) {
        vm.prank(address(EXECUTOR));
        POLICY.initializeRole(RoleDescription.wrap(bytes32(abi.encode(i))));
      }
    }

    vm.prank(address(EXECUTOR));
    POLICY.setRoleHolder(governorRole, address(llamaERC20TokenGovernor), DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    uint8[] memory forceRoles;
    if (governorRole < type(uint8).max - 1) {
      vm.prank(address(EXECUTOR));
      POLICY.initializeRole(RoleDescription.wrap(bytes32(abi.encode(governorRole + 1))));

      vm.prank(address(EXECUTOR));
      POLICY.setRoleHolder(
        governorRole + 1, address(llamaERC20TokenGovernor), DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION
      );

      forceRoles = new uint8[](2);
      forceRoles[0] = governorRole;
      forceRoles[1] = governorRole + 1;
    } else {
      forceRoles = new uint8[](1);
      forceRoles[0] = governorRole;
    }

    mineBlock();

    ILlamaRelativeStrategyBase.Config memory strategyConfig = ILlamaRelativeStrategyBase.Config({
      approvalPeriod: APPROVAL_PERIOD,
      queuingPeriod: QUEUING_PERIOD,
      expirationPeriod: EXPIRATION_PERIOD,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: ONE_HUNDRED_IN_BPS,
      minDisapprovalPct: ONE_HUNDRED_IN_BPS,
      approvalRole: tokenVotingGovernorRole,
      disapprovalRole: tokenVotingGovernorRole,
      forceApprovalRoles: forceRoles,
      forceDisapprovalRoles: forceRoles
    });

    ILlamaRelativeStrategyBase.Config[] memory strategyConfigs = new ILlamaRelativeStrategyBase.Config[](1);
    strategyConfigs[0] = strategyConfig;

    vm.prank(address(EXECUTOR));
    CORE.createStrategies(RELATIVE_QUANTITY_QUORUM_LOGIC, encodeStrategyConfigs(strategyConfigs));

    ILlamaStrategy newStrategy = ILlamaStrategy(
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

    actionInfo = _createActionWithTokenVotingStrategy(newStrategy);
    Action memory action = CORE.getAction(actionInfo.id);
    actionCreationTime = action.creationTime;

    _skipVotingDelay(actionInfo);

    vm.prank(tokenHolder1);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");
    vm.prank(tokenHolder2);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");
    vm.prank(tokenHolder3);
    llamaERC20TokenGovernor.castVote(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");

    uint256 delayPeriodEndTime = actionCreationTime + ((APPROVAL_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS);
    uint256 castingPeriodEndTime = delayPeriodEndTime + ((APPROVAL_PERIOD * TWO_QUARTERS_IN_BPS) / ONE_HUNDRED_IN_BPS);
    vm.warp(castingPeriodEndTime + 1);

    llamaERC20TokenGovernor.submitApproval(actionInfo);

    action = CORE.getAction(actionInfo.id);

    delayPeriodEndTime =
      (action.minExecutionTime - QUEUING_PERIOD) + ((QUEUING_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS);
    castingPeriodEndTime = delayPeriodEndTime + ((QUEUING_PERIOD * TWO_QUARTERS_IN_BPS) / ONE_HUNDRED_IN_BPS);

    vm.warp(delayPeriodEndTime + 1);

    vm.prank(tokenHolder1);
    llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");
    vm.prank(tokenHolder2);
    llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");
    vm.prank(tokenHolder3);
    llamaERC20TokenGovernor.castVeto(tokenVotingGovernorRole, actionInfo, uint8(VoteType.For), "");

    vm.warp(castingPeriodEndTime + 1);

    vm.expectEmit();
    emit DisapprovalSubmitted(actionInfo.id, address(this), governorRole, 750_000e18, 0, 0);
    llamaERC20TokenGovernor.submitDisapproval(actionInfo);
  }

  function test_SubmitsDisapprovalsCorrectly() public {
    vm.expectEmit();
    emit DisapprovalSubmitted(actionInfo.id, address(this), tokenVotingGovernorRole, 750_000e18, 0, 0);
    llamaERC20TokenGovernor.submitDisapproval(actionInfo);
  }
}

contract SetQuorumPct is LlamaTokenGovernorCasting {
  function test_RevertIf_NotLlamaExecutor(address notLlamaExecutor) public {
    vm.assume(notLlamaExecutor != address(EXECUTOR));
    vm.expectRevert(LlamaTokenGovernor.OnlyLlamaExecutor.selector);
    vm.prank(notLlamaExecutor);
    llamaERC20TokenGovernor.setQuorumPct(ERC20_VOTE_QUORUM_PCT, ERC20_VETO_QUORUM_PCT);
  }

  function test_RevertIf_InvalidQuorumPct() public {
    vm.startPrank(address(EXECUTOR));
    vm.expectRevert(abi.encodeWithSelector(LlamaTokenGovernor.InvalidVetoQuorumPct.selector, uint256(0)));
    llamaERC20TokenGovernor.setQuorumPct(ERC20_VOTE_QUORUM_PCT, 0);
    vm.expectRevert(abi.encodeWithSelector(LlamaTokenGovernor.InvalidVoteQuorumPct.selector, uint256(0)));
    llamaERC20TokenGovernor.setQuorumPct(0, ERC20_VETO_QUORUM_PCT);
    vm.expectRevert(abi.encodeWithSelector(LlamaTokenGovernor.InvalidVetoQuorumPct.selector, uint256(10_001)));
    llamaERC20TokenGovernor.setQuorumPct(ERC20_VOTE_QUORUM_PCT, 10_001);
    vm.expectRevert(abi.encodeWithSelector(LlamaTokenGovernor.InvalidVoteQuorumPct.selector, uint256(10_001)));
    llamaERC20TokenGovernor.setQuorumPct(10_001, ERC20_VETO_QUORUM_PCT);
    vm.stopPrank();
  }

  function test_SetsQuorumPctCorrectly(uint16 _voteQuorum, uint16 _vetoQuorum) public {
    _voteQuorum = uint16(bound(_voteQuorum, 1, ONE_HUNDRED_IN_BPS));
    _vetoQuorum = uint16(bound(_vetoQuorum, 1, ONE_HUNDRED_IN_BPS));
    vm.expectEmit();
    emit QuorumPctSet(_voteQuorum, _vetoQuorum);
    vm.prank(address(EXECUTOR));
    llamaERC20TokenGovernor.setQuorumPct(_voteQuorum, _vetoQuorum);
  }
}

contract SetPeriodPct is LlamaTokenGovernorCasting {
  function test_RevertIf_NotLlamaExecutor(address notLlamaExecutor) public {
    vm.assume(notLlamaExecutor != address(EXECUTOR));
    vm.expectRevert(LlamaTokenGovernor.OnlyLlamaExecutor.selector);
    vm.prank(notLlamaExecutor);
    llamaERC20TokenGovernor.setPeriodPct(uint16(ONE_QUARTER_IN_BPS), uint16(TWO_QUARTERS_IN_BPS));
  }

  function test_RevertIf_InvalidPeriodPct() public {
    vm.startPrank(address(EXECUTOR));
    vm.expectRevert(
      abi.encodeWithSelector(
        LlamaTokenGovernor.InvalidPeriodPcts.selector, uint16(ONE_QUARTER_IN_BPS), uint16(THREE_QUARTERS_IN_BPS)
      )
    );
    llamaERC20TokenGovernor.setPeriodPct(uint16(ONE_QUARTER_IN_BPS), uint16(THREE_QUARTERS_IN_BPS));
    vm.expectRevert(
      abi.encodeWithSelector(
        LlamaTokenGovernor.InvalidPeriodPcts.selector, uint16(ONE_QUARTER_IN_BPS), uint16(THREE_QUARTERS_IN_BPS) + 1
      )
    );
    llamaERC20TokenGovernor.setPeriodPct(uint16(ONE_QUARTER_IN_BPS), uint16(THREE_QUARTERS_IN_BPS) + 1);
    vm.stopPrank();
  }

  function test_SetsPeriodPctCorrectly() public {
    vm.expectEmit();
    emit PeriodPctSet(uint16(ONE_QUARTER_IN_BPS), uint16(TWO_QUARTERS_IN_BPS));
    vm.prank(address(EXECUTOR));
    llamaERC20TokenGovernor.setPeriodPct(uint16(ONE_QUARTER_IN_BPS), uint16(TWO_QUARTERS_IN_BPS));
  }
}

contract CastData is LlamaTokenGovernorCasting {
  function setUp() public virtual override {
    LlamaTokenGovernorCasting.setUp();

    _skipVotingDelay(actionInfo);
    castVotesFor();

    uint256 delayPeriodEndTime = actionCreationTime + ((APPROVAL_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS);
    uint256 castingPeriodEndTime = delayPeriodEndTime + ((APPROVAL_PERIOD * TWO_QUARTERS_IN_BPS) / ONE_HUNDRED_IN_BPS);
    vm.warp(castingPeriodEndTime + 1);

    llamaERC20TokenGovernor.submitApproval(actionInfo);

    _skipVetoDelay(actionInfo);
    castVetosFor();

    Action memory action = CORE.getAction(actionInfo.id);
    delayPeriodEndTime =
      (action.minExecutionTime - QUEUING_PERIOD) + ((QUEUING_PERIOD * ONE_QUARTER_IN_BPS) / ONE_HUNDRED_IN_BPS);
    castingPeriodEndTime = delayPeriodEndTime + ((QUEUING_PERIOD * TWO_QUARTERS_IN_BPS) / ONE_HUNDRED_IN_BPS);
    vm.warp(castingPeriodEndTime + 1);

    llamaERC20TokenGovernor.submitDisapproval(actionInfo);
  }

  function test_CanGetCastData() public {
    (
      uint128 votesFor,
      uint128 votesAbstain,
      uint128 votesAgainst,
      uint128 vetoesFor,
      uint128 vetoesAbstain,
      uint128 vetoesAgainst
    ) = llamaERC20TokenGovernor.casts(actionInfo.id);
    assertEq(votesFor, (ERC20_CREATION_THRESHOLD / 2) * 3);
    assertEq(votesAbstain, 0);
    assertEq(votesAgainst, 0);
    assertEq(vetoesFor, (ERC20_CREATION_THRESHOLD / 2) * 3);
    assertEq(vetoesAbstain, 0);
    assertEq(vetoesAgainst, 0);

    assertTrue(llamaERC20TokenGovernor.hasTokenHolderCast(actionInfo.id, tokenHolder1, true));
    assertTrue(llamaERC20TokenGovernor.hasTokenHolderCast(actionInfo.id, tokenHolder2, true));
    assertTrue(llamaERC20TokenGovernor.hasTokenHolderCast(actionInfo.id, tokenHolder3, true));
    assertFalse(llamaERC20TokenGovernor.hasTokenHolderCast(actionInfo.id, notTokenHolder, true));
    assertTrue(llamaERC20TokenGovernor.hasTokenHolderCast(actionInfo.id, tokenHolder1, false));
    assertTrue(llamaERC20TokenGovernor.hasTokenHolderCast(actionInfo.id, tokenHolder2, false));
    assertTrue(llamaERC20TokenGovernor.hasTokenHolderCast(actionInfo.id, tokenHolder3, false));
    assertFalse(llamaERC20TokenGovernor.hasTokenHolderCast(actionInfo.id, notTokenHolder, false));
  }
}

contract GetQuorums is LlamaTokenGovernorCasting {
  function test_GetPastQuorum(uint8 iterations) public {
    vm.assume(iterations > 0);
    for (uint256 i = 1; i < iterations; i++) {
      vm.prank(address(EXECUTOR));
      llamaERC20TokenGovernor.setQuorumPct(uint16(i), uint16(i));
      vm.warp(block.timestamp + 1);
      uint16 voteQuorum;
      uint16 vetoQuorum;
      (voteQuorum, vetoQuorum) = llamaERC20TokenGovernor.getPastQuorum(block.timestamp - 1);
      assertEq(voteQuorum, uint16(i));
      assertEq(vetoQuorum, uint16(i));
    }
  }

  function test_GetQuorumCheckpoints(uint8 iterations) public {
    for (uint256 i = 0; i < iterations; i++) {
      vm.prank(address(EXECUTOR));
      llamaERC20TokenGovernor.setQuorumPct(uint16(i + 1), uint16(i + 1));
      vm.warp(block.timestamp + 1);
      QuorumCheckpoints.History memory checkpoints = llamaERC20TokenGovernor.getQuorumCheckpoints();
      assertEq(checkpoints._checkpoints.length, i + 2);
    }
  }

  function test_RevertIf_StartIsGTEnd(uint256 start, uint256 end) public {
    vm.assume(start > end);
    vm.expectRevert(LlamaTokenGovernor.InvalidIndices.selector);
    llamaERC20TokenGovernor.getQuorumCheckpoints(start, end);
  }

  function test_RevertIf_EndIsGTLength(uint256 end) public {
    vm.assume(end > 2);
    vm.expectRevert(LlamaTokenGovernor.InvalidIndices.selector);
    llamaERC20TokenGovernor.getQuorumCheckpoints(0, end);
  }

  function test_getQuorumCheckpointsWithIndexes(uint8 iterations, uint256 start, uint256 end) public {
    vm.assume(start < end);
    vm.assume(end <= uint256(iterations) + 1);
    for (uint256 i = 0; i < iterations; i++) {
      vm.prank(address(EXECUTOR));
      llamaERC20TokenGovernor.setQuorumPct(uint16(i + 1), uint16(i + 1));
      vm.warp(block.timestamp + 1);
    }
    QuorumCheckpoints.History memory checkpoints = llamaERC20TokenGovernor.getQuorumCheckpoints(start, end);
    assertEq(checkpoints._checkpoints.length, end - start);
  }
}

contract GetPeriodPcts is LlamaTokenGovernorCasting {
  function test_GetPastPeriodPcts(uint8 iterations) public {
    vm.assume(iterations > 0);
    vm.prank(address(EXECUTOR));
    llamaERC20TokenGovernor.setPeriodPct(0, 0);
    vm.warp(block.timestamp + 1);
    for (uint256 i = 1; i < iterations; i++) {
      vm.prank(address(EXECUTOR));
      llamaERC20TokenGovernor.setPeriodPct(uint16(i), uint16(i));
      vm.warp(block.timestamp + 1);
      uint16 approvalPeriodPct;
      uint16 queuingPeriodPct;
      (approvalPeriodPct, queuingPeriodPct) = llamaERC20TokenGovernor.getPastPeriodPcts(block.timestamp - 1);
      assertEq(approvalPeriodPct, uint16(i));
      assertEq(queuingPeriodPct, uint16(i));
    }
  }

  function test_GetPeriodPctCheckpoints(uint8 iterations) public {
    for (uint256 i = 0; i < iterations; i++) {
      vm.prank(address(EXECUTOR));
      llamaERC20TokenGovernor.setPeriodPct(uint16(i + 1), uint16(i + 1));
      vm.warp(block.timestamp + 1);
      PeriodPctCheckpoints.History memory checkpoints = llamaERC20TokenGovernor.getPeriodPctCheckpoints();
      assertEq(checkpoints._checkpoints.length, i + 2);
    }
  }

  function test_RevertIf_StartIsGTEnd(uint256 start, uint256 end) public {
    vm.assume(start > end);
    vm.expectRevert(LlamaTokenGovernor.InvalidIndices.selector);
    llamaERC20TokenGovernor.getPeriodPctCheckpoints(start, end);
  }

  function test_RevertIf_EndIsGTLength(uint256 end) public {
    vm.assume(end > 2);
    vm.expectRevert(LlamaTokenGovernor.InvalidIndices.selector);
    llamaERC20TokenGovernor.getPeriodPctCheckpoints(0, end);
  }

  function test_getPeriodPctCheckpointsWithIndexes(uint8 iterations, uint256 start, uint256 end) public {
    vm.assume(start < end);
    vm.assume(end <= uint256(iterations));
    for (uint256 i = 0; i < iterations; i++) {
      vm.prank(address(EXECUTOR));
      llamaERC20TokenGovernor.setPeriodPct(uint16(i + 1), uint16(i + 1));
      vm.warp(block.timestamp + 1);
    }
    PeriodPctCheckpoints.History memory checkpoints = llamaERC20TokenGovernor.getPeriodPctCheckpoints(start, end);
    assertEq(checkpoints._checkpoints.length, end - start);
  }
}
