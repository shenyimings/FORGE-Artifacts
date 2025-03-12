// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../contracts/governance/Ctx.sol";
import "../../contracts/governance/GovernorBeta.sol";
import "../../contracts/governance/Timelock.sol";
import "../../contracts/arbitrum/L1MessageRelayer.sol";
import "../../contracts/arbitrum/L2AdminProxy.sol";
import "../../contracts/arbitrum/L2MessageExecutor.sol";
import "../../contracts/arbitrum/L2MessageExecutorProxy.sol";
import "../../contracts/arbitrum/AddressAliasHelper.sol";
import "../../contracts/ETHVaultHandler.sol";
import "../../contracts/Orchestrator.sol";
import "../../contracts/oracles/ChainlinkOracle.sol";
import "../../contracts/mocks/AggregatorInterfaceTCAP.sol";
import "../../contracts/mocks/AggregatorInterface.sol";
import "../../contracts/mocks/WETH.sol";
import "../../contracts/TCAP.sol";
import "../../contracts/mocks/Greeter.sol";
import "./mocks/MockInbox.sol";


pragma experimental ABIEncoderV2;

contract GovernanceBridgeIntegration is Test {
  enum ProposalState {
    Pending,
    Active,
    Canceled,
    Defeated,
    Succeeded,
    Queued,
    Expired,
    Executed
  }

  address user = address(0x51);
  address user1 = address(0x52);

  L1MessageRelayer l1MessageRelayer;
	L2AdminProxy l2AdminProxy;
  L2MessageExecutor l2MessageExecutor;
	L2MessageExecutorProxy proxy;
  MockInbox inbox;
  Ctx ctx;
  GovernorBeta governorBeta;
  Timelock timeLock;

  ETHVaultHandler ethVault;
  Orchestrator orchestrator;
  TCAP tcap;
  AggregatorInterfaceTCAP tcapAggregator;
  AggregatorInterface ethAggregator;
  ChainlinkOracle tcapOracle;
  ChainlinkOracle ethOracle;
  WETH weth;

  uint256 divisor = 10000000000;
  uint256 ratio = 110;
  uint256 burnFee = 50;
  uint256 mintFee =50;
  uint256 liquidationPenalty = 5;
  address treasury = address(0x53);

  function setUp() public {
    vm.startPrank(address(user));
    ctx = new Ctx(user, user, block.timestamp);
    timeLock = new Timelock(user, 2 days);
    governorBeta = new GovernorBeta(address(timeLock), address(ctx), user);
    inbox = new MockInbox();
    l1MessageRelayer = new L1MessageRelayer(
      address(timeLock),
      address(inbox)
    );
		l2AdminProxy = new L2AdminProxy(address(l1MessageRelayer));
		l2MessageExecutor = new L2MessageExecutor();
		bytes memory data = abi.encodeWithSelector(
      l2MessageExecutor.initialize.selector,
			address(l1MessageRelayer)
    );
		proxy = new L2MessageExecutorProxy(address(l2MessageExecutor), address(l2AdminProxy), data);
    ctx.delegate(user);

    orchestrator = new Orchestrator(user);
    orchestrator.transferOwnership(address(proxy));
    tcap = new TCAP("Total Crypto Market Cap Token", "TCAP", 0, orchestrator);
    tcapAggregator = new AggregatorInterfaceTCAP();
    ethAggregator = new AggregatorInterface();
    tcapOracle = new ChainlinkOracle(
      address(tcapAggregator),
      address(proxy)
    );
    ethOracle = new ChainlinkOracle(
      address(ethAggregator),
      address(proxy)
    );
    weth = new WETH();
    ethVault = new ETHVaultHandler(
      orchestrator,
      divisor,
      ratio,
      burnFee,
      mintFee,
      liquidationPenalty,
      address(tcapOracle),
      tcap,
      address(weth),
      address(ethOracle),
      address(ethOracle),
      treasury,
      1 ether
    );
    vm.stopPrank();
    updateTimelockAdmin();
  }

  function updateTimelockAdmin() public {
    vm.startPrank(user);
    uint256 eta = block.timestamp + timeLock.delay();
    timeLock.queueTransaction(
      address(timeLock),
      0,
      "setPendingAdmin(address)",
      abi.encode(address(governorBeta)),
      eta
    );
    vm.warp(block.timestamp + timeLock.delay() + 1 days);
    timeLock.executeTransaction(
      address(timeLock),
      0,
      "setPendingAdmin(address)",
      abi.encode(address(governorBeta)),
      eta
    );
    vm.stopPrank();
    vm.prank(address(governorBeta));
    timeLock.acceptAdmin();
    assertEq(timeLock.admin(), address(governorBeta));
  }

  function createAndExecuteGovernanceProposal(
    address[] memory targets,
    uint256[] memory values,
    string[] memory signatures,
    bytes[] memory calldatas
  ) public {
    vm.startPrank(user);
    vm.roll(block.number + 100);
    governorBeta.propose(targets, values, signatures, calldatas, "");
    uint256 proposalID = governorBeta.latestProposalIds(user);
    vm.roll(block.number + governorBeta.votingDelay() + 1);
    governorBeta.castVote(proposalID, true);
    vm.roll(block.number + governorBeta.votingPeriod() + 1);
    governorBeta.queue(proposalID);
    vm.warp(block.timestamp + timeLock.delay() + 1 days);
    governorBeta.execute(proposalID);
    assertEq(
      uint256(governorBeta.state(proposalID)),
      uint256(ProposalState.Executed)
    );
    vm.stopPrank();
  }

  function testAddVault() public {
    bytes memory _callData = abi.encodeWithSelector(
      orchestrator.addTCAPVault.selector,
      address(tcap),
      address(ethVault)
    );
    bytes memory _payLoad = abi.encode(address(orchestrator), _callData);
    address[] memory targets = new address[](1);
    uint256[] memory values = new uint256[](1);
    string[] memory signatures = new string[](1);
    bytes[] memory calldatas = new bytes[](1);
    targets[0] = address(l1MessageRelayer);
    values[0] = 0;
    signatures[0] = "relayMessage(address,bytes,uint256,uint256,uint256)";
    calldatas[0] = abi.encode(
			address(proxy),
			abi.encodeWithSelector(l2MessageExecutor.executeMessage.selector, _payLoad),
      uint256(21000 * 5),
      uint256(21000 * 5),
      uint256(21000 * 5)
    );

    assertEq(tcap.vaultHandlers(address(ethVault)), false);

    createAndExecuteGovernanceProposal(targets, values, signatures, calldatas);

    assertEq(tcap.vaultHandlers(address(ethVault)), true);
  }

	function testUpgradeProxyImplementation() external {
		Greeter greeter = new Greeter("");

    address[] memory targets = new address[](1);
    uint256[] memory values = new uint256[](1);
    string[] memory signatures = new string[](1);
    bytes[] memory calldatas = new bytes[](1);
    targets[0] = address(l1MessageRelayer);
    values[0] = 0;
    signatures[0] = "relayMessage(address,bytes,uint256,uint256,uint256)";
    calldatas[0] = abi.encode(
			address(l2AdminProxy),
			abi.encodeWithSignature(
				"upgradeAndCall(address,address,bytes)",
				address(proxy),
				address(greeter),
				abi.encodeWithSelector(greeter.setGreeting.selector, "Governance Test 1")
			),
      uint256(21000 * 5),
      uint256(21000 * 5),
      uint256(21000 * 5)
    );
		createAndExecuteGovernanceProposal(targets, values, signatures, calldatas);

		bytes memory message = Address.functionCall(
      address(proxy),
      abi.encodeWithSelector(greeter.greet.selector)
    );
		assertEq(abi.decode(message, (string)), "Governance Test 1");

		// update message
		calldatas[0] = abi.encode(
			address(l2AdminProxy),
			abi.encodeWithSignature(
				"upgradeAndCall(address,address,bytes)",
				address(proxy),
				address(greeter),
				abi.encodeWithSelector(greeter.setGreeting.selector, "Governance Test 2")
			),
      uint256(21000 * 5),
      uint256(21000 * 5),
      uint256(21000 * 5)
    );
		createAndExecuteGovernanceProposal(targets, values, signatures, calldatas);

		message = Address.functionCall(
      address(proxy),
      abi.encodeWithSelector(greeter.greet.selector)
    );
		assertEq(abi.decode(message, (string)), "Governance Test 2");
	}
}
