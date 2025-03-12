// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";

import {LlamaTokenVotingTestSetup} from "test/token-voting/LlamaTokenVotingTestSetup.sol";
import {LlamaCoreSigUtils} from "test/utils/LlamaCoreSigUtils.sol";

import {ILlamaCore} from "src/interfaces/ILlamaCore.sol";
import {ILlamaTokenAdapter} from "src/token-voting/interfaces/ILlamaTokenAdapter.sol";
import {ActionState} from "src/lib/Enums.sol";
import {Action, ActionInfo} from "src/lib/Structs.sol";
import {LlamaTokenGovernor} from "src/token-voting/LlamaTokenGovernor.sol";

contract LlamaTokenGovernorActionCreation is LlamaTokenVotingTestSetup, LlamaCoreSigUtils {
  event ActionCreated(uint256 id, address indexed creator);
  event ActionCanceled(uint256 id, address indexed creator);
  event ActionThresholdSet(uint256 newThreshold);

  LlamaTokenGovernor llamaERC20TokenGovernor;

  function setUp() public virtual override {
    LlamaTokenVotingTestSetup.setUp();

    // Mint tokens to tokenholders so that there is an existing supply.
    erc20VotesToken.mint(tokenHolder0, ERC20_CREATION_THRESHOLD);

    // Mine block so that the ERC20 and ERC721 supply will be available when doing a past timestamp check at initialize
    // during deployment.
    mineBlock();

    // Deploy ERC20 Token Voting Module.
    llamaERC20TokenGovernor = _deployERC20TokenVotingModuleAndSetRole();

    // Setting ERC20TokenHolderActionCreator's EIP-712 Domain Hash
    setDomainHash(
      LlamaCoreSigUtils.EIP712Domain({
        name: CORE.name(),
        version: "1",
        chainId: block.chainid,
        verifyingContract: address(llamaERC20TokenGovernor)
      })
    );
  }
}

contract Constructor is LlamaTokenGovernorActionCreation {
  function test_RevertIf_InitializeImplementationContract() public {
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    llamaTokenGovernorLogic.initialize(
      CORE, ILlamaTokenAdapter(address(0)), ERC20_CREATION_THRESHOLD, defaultCasterConfig
    );
  }
}

contract Initialize is LlamaTokenGovernorActionCreation {
  function test_RevertIf_InitializeAlreadyInitializedContract() public {
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    llamaERC20TokenGovernor.initialize(
      CORE, ILlamaTokenAdapter(address(0)), ERC20_CREATION_THRESHOLD, defaultCasterConfig
    );
  }
}

contract CreateAction is LlamaTokenGovernorActionCreation {
  bytes data = abi.encodeCall(mockProtocol.pause, (true));

  function test_RevertIf_InsufficientBalance() public {
    erc20VotesToken.mint(tokenHolder1, ERC20_CREATION_THRESHOLD);
    vm.prank(tokenHolder1);
    erc20VotesToken.delegate(tokenHolder1);

    mineBlock();

    vm.expectRevert(abi.encodeWithSelector(LlamaTokenGovernor.InsufficientBalance.selector, 0));
    vm.prank(notTokenHolder);
    llamaERC20TokenGovernor.createAction(tokenVotingGovernorRole, STRATEGY, address(mockProtocol), 0, data, "");
  }

  function test_RevertIf_LlamaTokenGovernorDoesNotHavePermission() public {
    erc20VotesToken.mint(tokenHolder1, ERC20_CREATION_THRESHOLD);
    vm.prank(tokenHolder1);
    erc20VotesToken.delegate(tokenHolder1);

    mineBlock();

    vm.expectRevert(ILlamaCore.PolicyholderDoesNotHavePermission.selector);
    vm.prank(tokenHolder1);
    llamaERC20TokenGovernor.createAction(tokenVotingGovernorRole, STRATEGY, address(mockProtocol), 0, data, "");
  }

  function test_RevertIf_LlamaTokenGovernorDoesNotHaveRole() public {
    erc20VotesToken.mint(tokenHolder1, ERC20_CREATION_THRESHOLD);
    vm.prank(tokenHolder1);
    erc20VotesToken.delegate(tokenHolder1);

    mineBlock();

    vm.expectRevert(ILlamaCore.PolicyholderDoesNotHavePermission.selector);
    vm.prank(tokenHolder1);
    llamaERC20TokenGovernor.createAction(madeUpRole, STRATEGY, address(mockProtocol), 0, data, "");
  }

  function test_RevertIf_CreatesActionWithRoleWithoutPermission() public {
    erc20VotesToken.mint(tokenHolder1, ERC20_CREATION_THRESHOLD);
    vm.prank(tokenHolder1);
    erc20VotesToken.delegate(tokenHolder1);

    mineBlock();

    vm.expectRevert(ILlamaCore.PolicyholderDoesNotHavePermission.selector);
    vm.prank(tokenHolder1);
    llamaERC20TokenGovernor.createAction(madeUpRole, STRATEGY, address(mockProtocol), 0, data, "");
  }

  function test_ProperlyCreatesAction() public {
    // Assigns Permission to LlamaTokenGovernor.
    _setRolePermissionToLlamaTokenGovernor();

    // Mint tokens to tokenholder so that they can create action.
    erc20VotesToken.mint(tokenHolder1, ERC20_CREATION_THRESHOLD);
    vm.prank(tokenHolder1);
    erc20VotesToken.delegate(tokenHolder1);

    // Mine block so that the ERC20 supply will be available when doing a past timestamp check at createAction.
    mineBlock();

    uint256 actionCount = CORE.actionsCount();

    vm.expectEmit();
    emit ActionCreated(actionCount, address(tokenHolder1));
    vm.prank(tokenHolder1);
    uint256 actionId =
      llamaERC20TokenGovernor.createAction(tokenVotingGovernorRole, STRATEGY, address(mockProtocol), 0, data, "");

    Action memory action = CORE.getAction(actionId);
    assertEq(actionId, actionCount);
    assertEq(action.creationTime, block.timestamp);
  }
}

contract CreateActionBySig is LlamaTokenGovernorActionCreation {
  function setUp() public virtual override {
    LlamaTokenGovernorActionCreation.setUp();

    // Assigns Permission to LlamaTokenGovernor.
    _setRolePermissionToLlamaTokenGovernor();

    // Mint tokens to tokenholder so that they can create action.
    erc20VotesToken.mint(tokenHolder1, ERC20_CREATION_THRESHOLD);
    vm.prank(tokenHolder1);
    erc20VotesToken.delegate(tokenHolder1);

    // Mine block so that the ERC20 supply will be available when doing a past timestamp check at createAction.
    mineBlock();
  }

  function createOffchainSignature(uint256 privateKey) internal view returns (uint8 v, bytes32 r, bytes32 s) {
    (v, r, s) = createOffchainSignatureWithDescription(privateKey, "");
  }

  function createOffchainSignatureWithDescription(uint256 privateKey, string memory description)
    internal
    view
    returns (uint8 v, bytes32 r, bytes32 s)
  {
    LlamaCoreSigUtils.CreateAction memory _createAction = LlamaCoreSigUtils.CreateAction({
      tokenHolder: tokenHolder1,
      role: tokenVotingGovernorRole,
      strategy: address(STRATEGY),
      target: address(mockProtocol),
      value: 0,
      data: abi.encodeCall(mockProtocol.pause, (true)),
      description: description,
      nonce: 0
    });
    bytes32 digest = getCreateActionTypedDataHash(_createAction);
    (v, r, s) = vm.sign(privateKey, digest);
  }

  function createActionBySig(uint8 v, bytes32 r, bytes32 s) internal returns (uint256 actionId) {
    actionId = llamaERC20TokenGovernor.createActionBySig(
      tokenHolder1,
      tokenVotingGovernorRole,
      STRATEGY,
      address(mockProtocol),
      0,
      abi.encodeCall(mockProtocol.pause, (true)),
      "",
      v,
      r,
      s
    );
  }

  function test_CreatesActionBySig() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(tokenHolder1PrivateKey);

    uint256 actionCount = CORE.actionsCount();

    vm.expectEmit();
    emit ActionCreated(actionCount, tokenHolder1);

    uint256 actionId = createActionBySig(v, r, s);
    Action memory action = CORE.getAction(actionId);

    assertEq(actionId, actionCount);
    assertEq(CORE.actionsCount() - 1, actionCount);
    assertEq(action.creationTime, block.timestamp);
  }

  function test_CreatesActionBySigWithDescription() public {
    (uint8 v, bytes32 r, bytes32 s) =
      createOffchainSignatureWithDescription(tokenHolder1PrivateKey, "# Action 0 \n This is my action.");

    uint256 actionCount = CORE.actionsCount();

    vm.expectEmit();
    emit ActionCreated(actionCount, tokenHolder1);

    uint256 actionId = llamaERC20TokenGovernor.createActionBySig(
      tokenHolder1,
      tokenVotingGovernorRole,
      STRATEGY,
      address(mockProtocol),
      0,
      abi.encodeCall(mockProtocol.pause, (true)),
      "# Action 0 \n This is my action.",
      v,
      r,
      s
    );
    Action memory action = CORE.getAction(actionId);

    assertEq(actionId, actionCount);
    assertEq(CORE.actionsCount() - 1, actionCount);
    assertEq(action.creationTime, block.timestamp);
  }

  function test_CheckNonceIncrements() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(tokenHolder1PrivateKey);
    assertEq(llamaERC20TokenGovernor.nonces(tokenHolder1, LlamaTokenGovernor.createActionBySig.selector), 0);
    createActionBySig(v, r, s);
    assertEq(llamaERC20TokenGovernor.nonces(tokenHolder1, LlamaTokenGovernor.createActionBySig.selector), 1);
  }

  function test_OperationCannotBeReplayed() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(tokenHolder1PrivateKey);
    createActionBySig(v, r, s);
    // Invalid Signature error since the recovered signer address during the second call is not the same as
    // policyholder since nonce has increased.
    vm.expectRevert(LlamaTokenGovernor.InvalidSignature.selector);
    createActionBySig(v, r, s);
  }

  function test_RevertIf_SignerIsNotPolicyHolder() public {
    (, uint256 randomSignerPrivateKey) = makeAddrAndKey("randomSigner");
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(randomSignerPrivateKey);
    // Invalid Signature error since the recovered signer address is not the same as the policyholder passed in as
    // parameter.
    vm.expectRevert(LlamaTokenGovernor.InvalidSignature.selector);
    createActionBySig(v, r, s);
  }

  function test_RevertIf_SignerIsZeroAddress() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(tokenHolder1PrivateKey);
    // Invalid Signature error since the recovered signer address is zero address due to invalid signature values
    // (v,r,s).
    vm.expectRevert(LlamaTokenGovernor.InvalidSignature.selector);
    createActionBySig((v + 1), r, s);
  }

  function test_RevertIf_PolicyholderIncrementsNonce() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(tokenHolder1PrivateKey);

    vm.prank(tokenHolder1);
    llamaERC20TokenGovernor.incrementNonce(LlamaTokenGovernor.createActionBySig.selector);

    // Invalid Signature error since the recovered signer address during the call is not the same as policyholder
    // since nonce has increased.
    vm.expectRevert(LlamaTokenGovernor.InvalidSignature.selector);
    createActionBySig(v, r, s);
  }
}

contract CancelAction is LlamaTokenGovernorActionCreation {
  uint256 actionId;
  ActionInfo actionInfo;

  function setUp() public virtual override {
    LlamaTokenGovernorActionCreation.setUp();

    // Assigns Permission to LlamaTokenGovernor.
    _setRolePermissionToLlamaTokenGovernor();

    // Mint tokens to tokenholder so that they can create action.
    erc20VotesToken.mint(tokenHolder1, ERC20_CREATION_THRESHOLD);
    vm.prank(tokenHolder1);
    erc20VotesToken.delegate(tokenHolder1);

    // Mine block so that the ERC20 supply will be available when doing a past timestamp check at createAction.
    mineBlock();

    bytes memory data = abi.encodeCall(mockProtocol.pause, (true));

    vm.prank(tokenHolder1);
    actionId =
      llamaERC20TokenGovernor.createAction(tokenVotingGovernorRole, STRATEGY, address(mockProtocol), 0, data, "");

    actionInfo = ActionInfo(
      actionId, address(llamaERC20TokenGovernor), tokenVotingGovernorRole, STRATEGY, address(mockProtocol), 0, data
    );
  }

  function test_PassesIf_CallerIsActionCreator() public {
    vm.expectEmit();
    emit ActionCanceled(actionId, tokenHolder1);
    vm.prank(tokenHolder1);
    llamaERC20TokenGovernor.cancelAction(actionInfo);
  }

  function test_RevertIf_CallerIsNotActionCreator(address notCreator) public {
    vm.assume(notCreator != tokenHolder1);
    vm.expectRevert(LlamaTokenGovernor.OnlyActionCreator.selector);
    vm.prank(notCreator);
    llamaERC20TokenGovernor.cancelAction(actionInfo);
  }
}

contract CancelActionBySig is LlamaTokenGovernorActionCreation {
  uint256 actionId;
  ActionInfo actionInfo;

  function setUp() public virtual override {
    LlamaTokenGovernorActionCreation.setUp();

    // Assigns Permission to LlamaTokenGovernor.
    _setRolePermissionToLlamaTokenGovernor();

    // Mint tokens to tokenholder so that they can create action.
    erc20VotesToken.mint(tokenHolder1, ERC20_CREATION_THRESHOLD);
    vm.prank(tokenHolder1);
    erc20VotesToken.delegate(tokenHolder1);

    // Mine block so that the ERC20 supply will be available when doing a past timestamp check at createAction.
    mineBlock();

    bytes memory data = abi.encodeCall(mockProtocol.pause, (true));

    vm.prank(tokenHolder1);
    actionId =
      llamaERC20TokenGovernor.createAction(tokenVotingGovernorRole, STRATEGY, address(mockProtocol), 0, data, "");

    actionInfo = ActionInfo(
      actionId, address(llamaERC20TokenGovernor), tokenVotingGovernorRole, STRATEGY, address(mockProtocol), 0, data
    );
  }

  function createOffchainSignature(ActionInfo memory _actionInfo, uint256 privateKey)
    internal
    view
    returns (uint8 v, bytes32 r, bytes32 s)
  {
    LlamaCoreSigUtils.CancelAction memory cancelAction = LlamaCoreSigUtils.CancelAction({
      tokenHolder: tokenHolder1,
      actionInfo: _actionInfo,
      nonce: llamaERC20TokenGovernor.nonces(tokenHolder1, LlamaTokenGovernor.cancelActionBySig.selector)
    });
    bytes32 digest = getCancelActionTypedDataHash(cancelAction);
    (v, r, s) = vm.sign(privateKey, digest);
  }

  function cancelActionBySig(ActionInfo memory _actionInfo, uint8 v, bytes32 r, bytes32 s) internal {
    llamaERC20TokenGovernor.cancelActionBySig(tokenHolder1, _actionInfo, v, r, s);
  }

  function test_CancelActionBySig() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, tokenHolder1PrivateKey);

    vm.expectEmit();
    emit ActionCanceled(actionId, tokenHolder1);
    cancelActionBySig(actionInfo, v, r, s);

    uint256 state = uint256(CORE.getActionState(actionInfo));
    uint256 canceled = uint256(ActionState.Canceled);
    assertEq(state, canceled);
  }

  function test_CheckNonceIncrements() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, tokenHolder1PrivateKey);

    assertEq(llamaERC20TokenGovernor.nonces(tokenHolder1, LlamaTokenGovernor.cancelActionBySig.selector), 0);
    cancelActionBySig(actionInfo, v, r, s);
    assertEq(llamaERC20TokenGovernor.nonces(tokenHolder1, LlamaTokenGovernor.cancelActionBySig.selector), 1);
  }

  function test_OperationCannotBeReplayed() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, tokenHolder1PrivateKey);
    cancelActionBySig(actionInfo, v, r, s);
    // Invalid Signature error since the recovered signer address during the second call is not the same as policyholder
    // since nonce has increased.
    vm.expectRevert(LlamaTokenGovernor.InvalidSignature.selector);
    cancelActionBySig(actionInfo, v, r, s);
  }

  function test_RevertIf_SignerIsNotTokenHolder() public {
    (, uint256 randomSignerPrivateKey) = makeAddrAndKey("randomSigner");
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, randomSignerPrivateKey);
    // Invalid Signature error since the recovered signer address is not the same as the policyholder passed in as
    // parameter.
    vm.expectRevert(LlamaTokenGovernor.InvalidSignature.selector);
    cancelActionBySig(actionInfo, v, r, s);
  }

  function test_RevertIf_SignerIsZeroAddress() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, tokenHolder1PrivateKey);
    // Invalid Signature error since the recovered signer address is zero address due to invalid signature values
    // (v,r,s).
    vm.expectRevert(LlamaTokenGovernor.InvalidSignature.selector);
    cancelActionBySig(actionInfo, (v + 1), r, s);
  }

  function test_RevertIf_PolicyholderIncrementsNonce() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, tokenHolder1PrivateKey);

    vm.prank(tokenHolder1);
    llamaERC20TokenGovernor.incrementNonce(LlamaTokenGovernor.cancelActionBySig.selector);

    // Invalid Signature error since the recovered signer address during the call is not the same as policyholder
    // since nonce has increased.
    vm.expectRevert(LlamaTokenGovernor.InvalidSignature.selector);
    cancelActionBySig(actionInfo, v, r, s);
  }
}

contract SetActionThreshold is LlamaTokenGovernorActionCreation {
  function testFuzz_SetsCreationThreshold(uint256 threshold) public {
    threshold = bound(threshold, 0, erc20VotesToken.getPastTotalSupply(block.timestamp - 1));

    assertEq(llamaERC20TokenGovernor.creationThreshold(), ERC20_CREATION_THRESHOLD);

    vm.expectEmit();
    emit ActionThresholdSet(threshold);
    vm.prank(address(EXECUTOR));
    llamaERC20TokenGovernor.setActionThreshold(threshold);

    assertEq(llamaERC20TokenGovernor.creationThreshold(), threshold);
  }

  function testFuzz_RevertIf_CreationThresholdExceedsTotalSupply(uint256 threshold) public {
    vm.assume(threshold > erc20VotesToken.getPastTotalSupply(block.timestamp - 1));

    vm.expectRevert(LlamaTokenGovernor.InvalidCreationThreshold.selector);
    vm.prank(address(EXECUTOR));
    llamaERC20TokenGovernor.setActionThreshold(threshold);
  }

  function testFuzz_RevertIf_CalledByNotLlamaExecutor(address notLlamaExecutor) public {
    vm.assume(notLlamaExecutor != address(EXECUTOR));

    vm.expectRevert(LlamaTokenGovernor.OnlyLlamaExecutor.selector);
    vm.prank(notLlamaExecutor);
    llamaERC20TokenGovernor.setActionThreshold(ERC20_CREATION_THRESHOLD);
  }
}

contract setActionThreshold is LlamaTokenGovernorActionCreation {
  function test_RevertIf_CreationThresholdExceedsTotalSupply(uint256 threshold) public {
    vm.assume(threshold > erc20VotesToken.getPastTotalSupply(block.timestamp - 1));

    vm.expectRevert(LlamaTokenGovernor.InvalidCreationThreshold.selector);
    vm.prank(address(EXECUTOR));
    llamaERC20TokenGovernor.setActionThreshold(threshold);
  }

  function test_RevertIf_CalledByNotLlamaExecutor(address notLlamaExecutor) public {
    vm.assume(notLlamaExecutor != address(EXECUTOR));

    vm.expectRevert(LlamaTokenGovernor.OnlyLlamaExecutor.selector);
    vm.prank(notLlamaExecutor);
    llamaERC20TokenGovernor.setActionThreshold(ERC20_CREATION_THRESHOLD);
  }

  function test_ProperlySetsCreationThreshold() public {
    assertEq(llamaERC20TokenGovernor.creationThreshold(), ERC20_CREATION_THRESHOLD);

    vm.expectEmit();
    emit ActionThresholdSet(ERC20_CREATION_THRESHOLD - 1);
    vm.prank(address(EXECUTOR));
    llamaERC20TokenGovernor.setActionThreshold(ERC20_CREATION_THRESHOLD - 1);

    assertEq(llamaERC20TokenGovernor.creationThreshold(), ERC20_CREATION_THRESHOLD - 1);
  }
}
