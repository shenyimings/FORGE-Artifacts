// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../../contracts/ETHVaultHandler.sol";
import "../../contracts/ERC20VaultHandler.sol";
import "../../contracts/TCAP.sol";
import "../../contracts/governance/GovernorBeta.sol";
import "../../contracts/governance/Timelock.sol";
import "../../contracts/governance/Ctx.sol";
import "../../contracts/arbitrum/AddressAliasHelper.sol";
import "../../contracts/arbitrum/ArbitrumOrchestrator.sol";
import "../../contracts/arbitrum/ArbitrumTreasury.sol";
import "../../contracts/arbitrum/L1MessageRelayer.sol";
import "../../contracts/arbitrum/L2MessageExecutorProxy.sol";
import "../../contracts/arbitrum/L2MessageExecutor.sol";
import "../../contracts/arbitrum/L2AdminProxy.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract JPEGZBridgeFork is Test {
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

  // Setup
  address user = address(0x51);
  address deployer = 0xd322a9876222Dea06a478D4a69B75cb83b81Eb3c;
  address guardian = 0x8705b41F9193f05ba166a1D5C0771E9cB2Ca0aa3;
  address arbitrumInbox = 0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f;
  ETHVaultHandler ethVault =
    ETHVaultHandler(0xe30C148Ca3cCe47341aB9bEbD7A8db031aB207D0);
  ERC20VaultHandler daiVault =
    ERC20VaultHandler(0x76fD6b835d21E1e411F5927950Ec9A0146cDB54B);
  ArbitrumOrchestrator orchestrator =
    ArbitrumOrchestrator(0x60f5C89C26cd424DF5E8513FDe150D2CA8F0eB9f);
  ArbitrumTreasury treasury =
    ArbitrumTreasury(0x9474B771Fb46E538cfED114Ca816A3e25Bb346CF);
  TCAP jpegz = TCAP(0xD5536c80191c624F6bFD5590A45b9E93B16DEA97);
  GovernorBeta governorBeta =
    GovernorBeta(0x874C5D592AfC6803c3DD60d6442357879F196d5b);
  Timelock timeLock = Timelock(0xa54074b2cc0e96a43048d4a68472F7F046aC0DA8);
  Ctx ctx = Ctx(0x321C2fE4446C7c963dc41Dd58879AF648838f98D);
  L1MessageRelayer l1MessageRelayer =
    L1MessageRelayer(0x209c23DB16298504354112fa4210d368e1d564dA);
  L2MessageExecutor l2MessageExecutor =
    L2MessageExecutor(0x4a6BA90F6938c769816c1B6808EF02Dc98531983);
  L2MessageExecutorProxy l2MessageExecutorProxy =
    L2MessageExecutorProxy(0x3769b6aA269995297a539BEd7a463105466733A5);
  L2AdminProxy l2AdminProxy =
    L2AdminProxy(0x7877f3C9c57467b1ad92D27608E706CD277c7817);
  ERC20 DAI = ERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
  ERC20 ARB = ERC20(0x912CE59144191C1204E64559FE8253a0e49E6548);
  uint256 mainnetFork;
  uint256 arbitrumFork;

  function setUp() external {
    string memory MAINNET_RPC_URL = vm.envString("MAINNET_API_URL");
    string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_API_URL");
    mainnetFork = vm.createFork(MAINNET_RPC_URL);
    arbitrumFork = vm.createFork(ARBITRUM_RPC_URL);
    vm.selectFork(mainnetFork);
    deal(address(timeLock), 100 ether);
    deal(user, 100 ether);
    deal({token: address(ctx), to: user, give: 500_000e18});
    vm.prank(user);
    ctx.delegate(user);
  }

  function testRelayerTimelockAddress() external {
    vm.selectFork(mainnetFork);
    assertEq(l1MessageRelayer.timeLock(), address(timeLock));
  }

  function testRelayerOwner() external {
    vm.selectFork(mainnetFork);
    assertEq(l1MessageRelayer.owner(), deployer);
  }

  function testRelayerInboxAddress() external {
    vm.selectFork(mainnetFork);
    assertEq(address(l1MessageRelayer.inbox()), arbitrumInbox);
  }

  function testAdminProxyOwner() external {
    vm.selectFork(arbitrumFork);
    assertEq(
      l2AdminProxy.owner(),
      AddressAliasHelper.applyL1ToL2Alias(address(l1MessageRelayer))
    );
  }

  function testL2ExecutorProxyAdmin() external {
    vm.selectFork(arbitrumFork);
    vm.prank(address(l2AdminProxy));
    assertEq(l2MessageExecutorProxy.admin(), address(l2AdminProxy));
  }

  function testL2ExecutorProxyRelayer() external {
    vm.selectFork(arbitrumFork);
    bytes memory message = Address.functionCall(
      address(l2MessageExecutorProxy),
      abi.encodeWithSelector(l2MessageExecutor.l1MessageRelayer.selector)
    );
    assertEq(abi.decode(message, (address)), address(l1MessageRelayer));
  }

  function testOrchestratorOwner() external {
    vm.selectFork(arbitrumFork);
    assertEq(orchestrator.owner(), address(l2MessageExecutorProxy));
  }

  function testOrchestratorGuardian() external {
    vm.selectFork(arbitrumFork);
    assertEq(orchestrator.guardian(), guardian);
  }

  function testTreasuryOwner() external {
    vm.selectFork(arbitrumFork);
    assertEq(treasury.owner(), address(l2MessageExecutorProxy));
  }

  function testETHVaultOwner() external {
    vm.selectFork(arbitrumFork);
    assertEq(ethVault.owner(), address(orchestrator));
  }

  function testDAIVaultOwner() external {
    vm.selectFork(arbitrumFork);
    assertEq(daiVault.owner(), address(orchestrator));
  }

  function testJPEGZOwner() external {
    vm.selectFork(arbitrumFork);
    assertEq(jpegz.owner(), address(orchestrator));
  }

  function createAndExecuteGovernanceMessageExecutorProposal(
    bytes memory _payLoad
  ) public {
    _createAndExecuteGovernanceProposal(
      address(l2MessageExecutorProxy),
      abi.encodeWithSelector(
        l2MessageExecutor.executeMessage.selector,
        _payLoad
      )
    );
  }

  function createAndExecuteGovernanceAdminProxyProposal(bytes memory _payLoad)
    public
  {
    _createAndExecuteGovernanceProposal(address(l2AdminProxy), _payLoad);
  }

  function _createAndExecuteGovernanceProposal(
    address target,
    bytes memory _payLoad
  ) public {
    address[] memory targets = new address[](1);
    uint256[] memory values = new uint256[](1);
    string[] memory signatures = new string[](1);
    bytes[] memory calldatas = new bytes[](1);
    targets[0] = address(l1MessageRelayer);
    values[0] = 2694764530612800;
    signatures[0] = "relayMessage(address,bytes,uint256,uint256,uint256)";
    calldatas[0] = abi.encode(
      target,
      _payLoad,
      uint256(2686308330612800),
      uint256(84562),
      uint256(100000000)
    );

    vm.selectFork(mainnetFork);
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

    vm.selectFork(arbitrumFork);
    vm.startPrank(
      AddressAliasHelper.applyL1ToL2Alias(address(l1MessageRelayer))
    );
    (address target, bytes memory payload, , , ) = abi.decode(
      calldatas[0],
      (address, bytes, uint256, uint256, uint256)
    );
    (bool success, ) = target.call(payload);
    require(success, "tx to arbitrum failed");
    vm.stopPrank();
  }

  function testSetGuardian() external {
    bytes memory _callData = abi.encodeWithSelector(
      orchestrator.setGuardian.selector,
      user
    );
    bytes memory _payLoad = abi.encode(address(orchestrator), _callData);
    vm.selectFork(arbitrumFork);
    assertEq(orchestrator.guardian(), guardian);
    createAndExecuteGovernanceMessageExecutorProposal(_payLoad);
    assertEq(orchestrator.guardian(), user);
  }

  function testSetMintFee() external {
    uint256 newMintFee = 205;
    bytes memory _callData = abi.encodeWithSelector(
      orchestrator.setMintFee.selector,
      address(ethVault),
      newMintFee
    );
    bytes memory _payLoad = abi.encode(address(orchestrator), _callData);
    createAndExecuteGovernanceMessageExecutorProposal(_payLoad);
    vm.selectFork(arbitrumFork);
    assertEq(ethVault.mintFee(), newMintFee);
  }

  function testEthVAultSetRatio() external {
    uint256 newVaultRatio = 500;
    bytes memory _callData = abi.encodeWithSelector(
      orchestrator.setRatio.selector,
      address(ethVault),
      newVaultRatio
    );
    bytes memory _payLoad = abi.encode(address(orchestrator), _callData);
    createAndExecuteGovernanceMessageExecutorProposal(_payLoad);
    vm.selectFork(arbitrumFork);
    assertEq(ethVault.ratio(), newVaultRatio);
  }

  function testDAISetRatio() external {
    uint256 newVaultRatio = 500;
    bytes memory _callData = abi.encodeWithSelector(
      orchestrator.setRatio.selector,
      address(daiVault),
      newVaultRatio
    );
    bytes memory _payLoad = abi.encode(address(orchestrator), _callData);
    createAndExecuteGovernanceMessageExecutorProposal(_payLoad);
    vm.selectFork(arbitrumFork);
    assertEq(daiVault.ratio(), newVaultRatio);
  }

  function testEthVaultSetBurnFee() external {
    uint256 newBurnFee = 317;
    bytes memory _callData = abi.encodeWithSelector(
      orchestrator.setBurnFee.selector,
      address(ethVault),
      newBurnFee
    );
    bytes memory _payLoad = abi.encode(address(orchestrator), _callData);
    createAndExecuteGovernanceMessageExecutorProposal(_payLoad);
    vm.selectFork(arbitrumFork);
    assertEq(ethVault.burnFee(), newBurnFee);
  }

  function testDAIVaultSetBurnFee() external {
    uint256 newBurnFee = 317;
    bytes memory _callData = abi.encodeWithSelector(
      orchestrator.setBurnFee.selector,
      address(daiVault),
      newBurnFee
    );
    bytes memory _payLoad = abi.encode(address(orchestrator), _callData);
    createAndExecuteGovernanceMessageExecutorProposal(_payLoad);
    vm.selectFork(arbitrumFork);
    assertEq(daiVault.burnFee(), newBurnFee);
  }

  function testEthVaultSetLiquidationPenalty() external {
    uint256 liquidationPenalty = 23;
    bytes memory _callData = abi.encodeWithSelector(
      orchestrator.setLiquidationPenalty.selector,
      address(ethVault),
      liquidationPenalty
    );
    bytes memory _payLoad = abi.encode(address(orchestrator), _callData);
    createAndExecuteGovernanceMessageExecutorProposal(_payLoad);
    vm.selectFork(arbitrumFork);
    assertEq(ethVault.liquidationPenalty(), liquidationPenalty);
  }

  function testDAIVaultSetLiquidationPenalty() external {
    uint256 liquidationPenalty = 23;
    bytes memory _callData = abi.encodeWithSelector(
      orchestrator.setLiquidationPenalty.selector,
      address(daiVault),
      liquidationPenalty
    );
    bytes memory _payLoad = abi.encode(address(orchestrator), _callData);
    createAndExecuteGovernanceMessageExecutorProposal(_payLoad);
    vm.selectFork(arbitrumFork);
    assertEq(daiVault.liquidationPenalty(), liquidationPenalty);
  }

  function testAdminProxyCanUpgrade() external {
    bytes memory _payLoad = abi.encodeWithSignature(
      "upgrade(address,address)",
      address(l2MessageExecutorProxy),
      // Implementation contract needs to be deployed on the network that is being tested.this
      // Chose ethVault as a dummy implementation to check if the upgrade works
      address(ethVault)
    );
    createAndExecuteGovernanceAdminProxyProposal(_payLoad);
    bytes memory message = Address.functionCall(
      address(l2MessageExecutorProxy),
      abi.encodeWithSelector(ethVault.MAX_DECIMAL_PLACES.selector)
    );
    assertEq(uint256(abi.decode(message, (uint8))), 18);
  }

  function testTreasuryETHTransfer() external {
    vm.selectFork(arbitrumFork);
    uint256 initialUserBalance = user.balance;
    uint256 treasuryBalance = address(treasury).balance;
    if (treasuryBalance == 0) {
      vm.deal(address(treasury), 100 ether);
      treasuryBalance = 100 ether;
    }
    bytes memory _callData = abi.encodeWithSelector(
      treasury.retrieveETH.selector,
      user
    );
    bytes memory _payLoad = abi.encode(address(treasury), _callData);
    createAndExecuteGovernanceMessageExecutorProposal(_payLoad);
    vm.selectFork(arbitrumFork);
    assertEq(user.balance, initialUserBalance + treasuryBalance);
    assertEq(address(treasury).balance, 0);
  }

  function testTreasuryERC20Transfer() external {
    vm.selectFork(arbitrumFork);
    uint256 initialUserBalance = DAI.balanceOf(user);
    uint256 treasuryBalance = DAI.balanceOf(address(treasury));
    if (treasuryBalance == 0) {
      deal({token: address(DAI), to: address(treasury), give: 100 ether});
      treasuryBalance = 100 ether;
    }
    bytes memory _callData = abi.encodeWithSelector(
      treasury.executeTransaction.selector,
      address(DAI),
      0,
      "transfer(address,uint256)",
      abi.encode(user, treasuryBalance)
    );
    bytes memory _payLoad = abi.encode(address(treasury), _callData);
    createAndExecuteGovernanceMessageExecutorProposal(_payLoad);
    vm.selectFork(arbitrumFork);
    assertEq(DAI.balanceOf(user), initialUserBalance + treasuryBalance);
    assertEq(DAI.balanceOf(address(treasury)), 0);
  }

  function testTreasuryArbTransfer() external {
    vm.selectFork(arbitrumFork);
    uint256 initialUserBalance = ARB.balanceOf(user);
    uint256 treasuryBalance = ARB.balanceOf(address(treasury));
    if (treasuryBalance == 0) {
      deal({token: address(ARB), to: address(treasury), give: 100 ether});
      treasuryBalance = 100 ether;
    }
    bytes memory _callData = abi.encodeWithSelector(
      treasury.executeTransaction.selector,
      address(ARB),
      0,
      "transfer(address,uint256)",
      abi.encode(user, treasuryBalance)
    );
    bytes memory _payLoad = abi.encode(address(treasury), _callData);
    createAndExecuteGovernanceMessageExecutorProposal(_payLoad);
    vm.selectFork(arbitrumFork);
    assertEq(ARB.balanceOf(user), initialUserBalance + treasuryBalance);
    assertEq(ARB.balanceOf(address(treasury)), 0);
  }
}
