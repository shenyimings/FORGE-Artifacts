// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../contracts/ETHVaultHandler.sol";
import "../contracts/Orchestrator.sol";
import "../contracts/oracles/ChainlinkOracle.sol";
import "../contracts/mocks/AggregatorInterfaceTCAP.sol";
import "../contracts/mocks/AggregatorInterface.sol";
import "../contracts/mocks/WETH.sol";

contract VaultDisablingTest is Test {
  // events
  event FunctionToggled(
    address indexed _owner,
    uint8 _function,
    bool _isDisabled
  );

  // Setup
  ETHVaultHandler ethVault;
  Orchestrator orchestrator = new Orchestrator(address(this));
  TCAP tcap =
    new TCAP("Total Crypto Market Cap Token", "TCAP", 0, (orchestrator));
  AggregatorInterfaceTCAP tcapAggregator = new AggregatorInterfaceTCAP();
  AggregatorInterface ethAggregator = new AggregatorInterface();
  ChainlinkOracle tcapOracle =
    new ChainlinkOracle(address(tcapAggregator), address(this));
  ChainlinkOracle ethOracle =
    new ChainlinkOracle(address(ethAggregator), address(this));
  WETH weth = new WETH();
  address user = address(0x1);
  address user2 = address(0x2);

  //// Params
  uint256 divisor = 10000000000;
  uint256 ratio = 110;
  uint256 burnFee = 50;
  uint256 mintFee = 50;
  uint256 liquidationPenalty = 5;
  address treasury = address(0x3);

  function setUp() public {
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

    orchestrator.addTCAPVault(tcap, ethVault);
  }

  function testToggleFunction_ShouldRevert_WhenNotOwner() public {
    //setUp
    vm.expectRevert("Ownable: caller is not the owner");

    //execution
    ethVault.toggleFunction(IVaultHandler.FunctionChoices.CreateVault, true);

    //assert
    assertEq(
      ethVault.isDisabled(IVaultHandler.FunctionChoices.CreateVault),
      false
    );
  }

  function testToggleFunction_ShouldDisableFunction() public {
    //setUp
    vm.startPrank(address(orchestrator));
    vm.expectEmit(true, true, true, true);
    emit FunctionToggled(address(orchestrator), 0, true);

    //execution
    ethVault.toggleFunction(IVaultHandler.FunctionChoices.CreateVault, true);

    //assert
    assertEq(
      ethVault.isDisabled(IVaultHandler.FunctionChoices.CreateVault),
      true
    );
  }

  function testCreateVault_ShouldRevert_WhenIsDisabled() public {
    //setUp
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(IVaultHandler.FunctionChoices.CreateVault, true);
    vm.startPrank(user);
    vm.expectRevert("VaultHandler:: function disabled");

    //execution
    ethVault.createVault();

    //assert
    assertEq(ethVault.userToVault(user), 0);
  }

  function testCreateVault_ShouldWork_WhenToogleDisabledFalse() public {
    //setUp
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(IVaultHandler.FunctionChoices.CreateVault, true);
    vm.prank(user);
    vm.expectRevert("VaultHandler:: function disabled");
    ethVault.createVault();
    assertEq(ethVault.userToVault(user), 0);
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(IVaultHandler.FunctionChoices.CreateVault, false);
    //execution
    vm.prank(user);
    ethVault.createVault();

    //assert
    assertEq(ethVault.userToVault(user), 1);
  }

  function testAddCollateral_ShouldRevert_WhenIsDisabled() public {
    //setUp
    uint256 amount = 1 ether;
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(IVaultHandler.FunctionChoices.AddCollateral, true);
    vm.startPrank(user);
    vm.deal(user, amount);
    weth.deposit{value: amount}();
    weth.approve(address(ethVault), amount);
    ethVault.createVault();
    vm.expectRevert("VaultHandler:: function disabled");

    //execution
    ethVault.addCollateral(amount);

    //assert
    (uint256 id, uint256 collateral, uint256 debt, address owner) = ethVault
      .vaults(1);
    assertEq(ethVault.userToVault(user), 1);
    assertEq(id, 1);
    assertEq(collateral, 0);
    assertEq(debt, 0);
    assertEq(owner, user);
  }

  function testAddCollateralETH_ShouldRevert_WhenIsDisabled() public {
    //setup
    uint256 amount = 1 ether;
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(IVaultHandler.FunctionChoices.AddCollateral, true);
    vm.startPrank(user);
    vm.deal(user, amount);
    ethVault.createVault();
    vm.expectRevert("VaultHandler:: function disabled");
    //execution
    ethVault.addCollateralETH{value: amount}();

    //assert
    (uint256 id, uint256 collateral, uint256 debt, address owner) = ethVault
      .vaults(1);
    assertEq(ethVault.userToVault(user), 1);
    assertEq(id, 1);
    assertEq(collateral, 0);
    assertEq(debt, 0);
    assertEq(owner, user);
  }

  function testAddCollateral_ShouldWork_WhenToogleDisabledFalse() public {
    uint256 amount = 1 ether;
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(IVaultHandler.FunctionChoices.AddCollateral, true);
    vm.startPrank(user);
    vm.deal(user, amount);
    weth.deposit{value: amount}();
    weth.approve(address(ethVault), amount);
    ethVault.createVault();
    vm.expectRevert("VaultHandler:: function disabled");
    //execution
    ethVault.addCollateral(amount);
    vm.stopPrank();
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(IVaultHandler.FunctionChoices.AddCollateral, false);
    vm.prank(user);
    ethVault.addCollateral(amount);
    //assert
    (uint256 id, uint256 collateral, uint256 debt, address owner) = ethVault
      .vaults(1);
    assertEq(ethVault.userToVault(user), 1);
    assertEq(id, 1);
    assertEq(collateral, amount);
    assertEq(debt, 0);
    assertEq(owner, user);
  }

  function testAddCollateralETH_ShouldWork_WhenToogleDisabledFalse() public {
    //setUp
    uint256 amount = 1 ether;
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(IVaultHandler.FunctionChoices.AddCollateral, true);
    vm.startPrank(user);
    vm.deal(user, amount);
    ethVault.createVault();

    //execution
    vm.expectRevert("VaultHandler:: function disabled");
    ethVault.addCollateralETH{value: amount}();
    vm.stopPrank();
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(IVaultHandler.FunctionChoices.AddCollateral, false);
    vm.prank(user);
    ethVault.addCollateralETH{value: amount}();
    //assert
    (uint256 id, uint256 collateral, uint256 debt, address owner) = ethVault
      .vaults(1);
    assertEq(ethVault.userToVault(user), 1);
    assertEq(id, 1);
    assertEq(collateral, amount);
    assertEq(debt, 0);
    assertEq(owner, user);
  }

  function testRemoveCollateral_ShouldRevert_WhenIsDisabled() public {
    //setup
    uint256 amount = 1 ether;
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(
      IVaultHandler.FunctionChoices.RemoveCollateral,
      true
    );
    vm.startPrank(user);
    vm.deal(user, amount);
    ethVault.createVault();
    ethVault.addCollateralETH{value: amount}();
    vm.expectRevert("VaultHandler:: function disabled");

    //execution
    ethVault.removeCollateral(amount);

    //assert
    (uint256 id, uint256 collateral, uint256 debt, address owner) = ethVault
      .vaults(1);
    assertEq(ethVault.userToVault(user), 1);
    assertEq(id, 1);
    assertEq(collateral, 1 ether);
    assertEq(debt, 0);
    assertEq(owner, user);
  }

  function testRemoveCollateralETH_ShouldRevert_WhenIsDisabled() public {
    //setup
    uint256 amount = 1 ether;
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(
      IVaultHandler.FunctionChoices.RemoveCollateral,
      true
    );
    vm.startPrank(user);
    vm.deal(user, amount);
    ethVault.createVault();
    ethVault.addCollateralETH{value: amount}();
    vm.expectRevert("VaultHandler:: function disabled");

    //execution
    ethVault.removeCollateralETH(amount);

    //assert
    (uint256 id, uint256 collateral, uint256 debt, address owner) = ethVault
      .vaults(1);
    assertEq(ethVault.userToVault(user), 1);
    assertEq(id, 1);
    assertEq(collateral, 1 ether);
    assertEq(debt, 0);
    assertEq(owner, user);
  }

  function testRemoveCollateral_ShouldWork_WhenToogleDisabledFalse() public {
    //setup
    uint256 amount = 1 ether;
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(
      IVaultHandler.FunctionChoices.RemoveCollateral,
      true
    );
    vm.startPrank(user);
    vm.deal(user, amount);
    ethVault.createVault();
    ethVault.addCollateralETH{value: amount}();
    vm.expectRevert("VaultHandler:: function disabled");
    ethVault.removeCollateral(amount);
    vm.stopPrank();
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(
      IVaultHandler.FunctionChoices.RemoveCollateral,
      false
    );

    //execution
    vm.prank(user);
    ethVault.removeCollateral(amount);

    //assert
    (uint256 id, uint256 collateral, uint256 debt, address owner) = ethVault
      .vaults(1);
    assertEq(ethVault.userToVault(user), 1);
    assertEq(id, 1);
    assertEq(collateral, 0);
    assertEq(debt, 0);
    assertEq(owner, user);
  }

  function testRemoveCollateralETH_ShouldWork_WhenToogleDisabledFalse() public {
    //setup
    uint256 amount = 1 ether;
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(
      IVaultHandler.FunctionChoices.RemoveCollateral,
      true
    );
    vm.startPrank(user);
    vm.deal(user, amount);
    ethVault.createVault();
    ethVault.addCollateralETH{value: amount}();
    vm.expectRevert("VaultHandler:: function disabled");
    ethVault.removeCollateralETH(amount);
    vm.stopPrank();
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(
      IVaultHandler.FunctionChoices.RemoveCollateral,
      false
    );

    //execution
    vm.prank(user);
    ethVault.removeCollateralETH(amount);

    //assert
    (uint256 id, uint256 collateral, uint256 debt, address owner) = ethVault
      .vaults(1);
    assertEq(ethVault.userToVault(user), 1);
    assertEq(id, 1);
    assertEq(collateral, 0);
    assertEq(debt, 0);
    assertEq(owner, user);
  }

  function testMint_ShouldRevert_WhenIsDisabled() public {
    //setup
    uint256 amount = 1 ether;
    uint256 mfee = ethVault.getMintFee(amount);
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(IVaultHandler.FunctionChoices.Mint, true);
    vm.startPrank(user);
    vm.deal(user, amount + mfee);
    ethVault.createVault();
    ethVault.addCollateralETH{value: amount}();
    vm.expectRevert("VaultHandler:: function disabled");

    //execution
    ethVault.mint{value: mfee}(1 ether);

    //assert
    (uint256 id, uint256 collateral, uint256 debt, address owner) = ethVault
      .vaults(1);
    assertEq(ethVault.userToVault(user), 1);
    assertEq(id, 1);
    assertEq(collateral, 1 ether);
    assertEq(debt, 0);
    assertEq(owner, user);
  }

  function testMint_ShouldWork_WhenToogleDisabledFalse() public {
    //setup
    uint256 amount = 1 ether;
    uint256 mfee = ethVault.getMintFee(amount);
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(IVaultHandler.FunctionChoices.Mint, true);
    vm.startPrank(user);
    vm.deal(user, amount + mfee);
    ethVault.createVault();
    ethVault.addCollateralETH{value: amount}();
    vm.expectRevert("VaultHandler:: function disabled");
    ethVault.mint{value: mfee}(1 ether);
    vm.stopPrank();
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(IVaultHandler.FunctionChoices.Mint, false);

    //execution
    vm.prank(user);
    ethVault.mint{value: mfee}(1 ether);

    //assert
    (uint256 id, uint256 collateral, uint256 debt, address owner) = ethVault
      .vaults(1);
    assertEq(ethVault.userToVault(user), 1);
    assertEq(id, 1);
    assertEq(collateral, 1 ether);
    assertEq(debt, 1 ether);
    assertEq(owner, user);
  }

  function testBurn_ShouldNotBurn_WhenIsDisabled() public {
    //setup
    uint256 amount = 1 ether;
    uint256 mfee = ethVault.getMintFee(amount);
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(IVaultHandler.FunctionChoices.Burn, true);
    vm.startPrank(user);
    vm.deal(user, amount * 2);
    ethVault.createVault();
    ethVault.addCollateralETH{value: amount}();
    ethVault.mint{value: mfee}(1 ether);
    uint256 fee = ethVault.getBurnFee(amount);

    //execution
    vm.expectRevert("VaultHandler:: function disabled");
    ethVault.burn{value: fee}(1 ether);

    //assert
    (uint256 id, uint256 collateral, uint256 debt, address owner) = ethVault
      .vaults(1);
    assertEq(ethVault.userToVault(user), 1);
    assertEq(id, 1);
    assertEq(collateral, 1 ether);
    assertEq(debt, 1 ether);
    assertEq(owner, user);
  }

  function testBurn_ShouldWork_WhenToogleDisabledFalse() public {
    //setup
    uint256 amount = 1 ether;
    uint256 mfee = ethVault.getMintFee(amount);
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(IVaultHandler.FunctionChoices.Burn, true);
    vm.startPrank(user);
    vm.deal(user, mfee + amount * 2);
    ethVault.createVault();
    ethVault.addCollateralETH{value: amount}();
    ethVault.mint{value: mfee}(1 ether);
    uint256 fee = ethVault.getBurnFee(amount);
    vm.expectRevert("VaultHandler:: function disabled");
    ethVault.burn{value: fee}(1 ether);
    vm.stopPrank();
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(IVaultHandler.FunctionChoices.Burn, false);

    //execution
    vm.prank(user);
    ethVault.burn{value: fee}(1 ether);

    //assert
    (uint256 id, uint256 collateral, uint256 debt, address owner) = ethVault
      .vaults(1);
    assertEq(ethVault.userToVault(user), 1);
    assertEq(id, 1);
    assertEq(collateral, 1 ether);
    assertEq(debt, 0 ether);
    assertEq(owner, user);
  }

  function testLiquidateVault_ShouldNotLiquidate_WhenIsDisabled() public {
    //setup
    uint256 amount = 1 ether;
    uint256 mfee = ethVault.getMintFee(amount);
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(IVaultHandler.FunctionChoices.LiquidateVault, true);
    vm.startPrank(user);
    vm.deal(user, mfee + amount);
    vm.deal(user2, amount * 2);
    ethVault.createVault();
    ethVault.addCollateralETH{value: amount}();
    ethVault.mint{value: mfee}(1 ether);
    uint256 fee = ethVault.getBurnFee(amount);
    vm.stopPrank();

    //execution
    vm.expectRevert("VaultHandler:: function disabled");
    vm.startPrank(user2);
    ethVault.liquidateVault{value: fee}(1, 1 ether);

    //assert
    (uint256 id, uint256 collateral, uint256 debt, address owner) = ethVault
      .vaults(1);
    assertEq(ethVault.userToVault(user), 1);
    assertEq(id, 1);
    assertEq(collateral, 1 ether);
    assertEq(debt, 1 ether);
    assertEq(owner, user);
  }

  function testLiquidateVault_ShouldWork_WhenToogleDisabledFalse() public {
    //setup
    uint256 amount = 1 ether;
    uint256 mfee = ethVault.getMintFee(amount);
    uint256 mfeeHigh = ethVault.getMintFee(9 ether);
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(IVaultHandler.FunctionChoices.LiquidateVault, true);
    vm.startPrank(user);
    vm.deal(user,mfeeHigh+ amount + mfee);
    vm.deal(user2, ( amount) * 2);
    ethVault.createVault();
    ethVault.addCollateralETH{value: amount}();
    ethVault.mint{value: mfeeHigh}(3 ether);
    tcap.transfer(user2, 3 ether);
    uint256 fee = ethVault.getBurnFee(amount);
    vm.stopPrank();
    vm.expectRevert("VaultHandler:: function disabled");
    vm.prank(user2);
    ethVault.liquidateVault{value: fee}(1, 1 ether);
    vm.prank(address(orchestrator));
    ethVault.toggleFunction(
      IVaultHandler.FunctionChoices.LiquidateVault,
      false
    );
    tcapAggregator.setLatestAnswer(143129732288636297500);
    fee = ethVault.getBurnFee(9 ether);

    //execution
    vm.prank(user2);
    ethVault.liquidateVault{value: fee}(1, 9 ether);
    //assert
    (uint256 id, uint256 collateral, uint256 debt, address owner) = ethVault
      .vaults(1);
    assertEq(ethVault.userToVault(user), 1);
    assertEq(id, 1);
    assertEq(collateral, 0 ether);
    assertEq(debt, 0);
    assertEq(owner, user);
  }

  function testToggleFunction_ShouldOnlyDisableOneFunction_WhenToogled()
    public
  {
    //setup
    vm.startPrank(address(orchestrator));
    ethVault.toggleFunction(IVaultHandler.FunctionChoices.CreateVault, true);
    ethVault.toggleFunction(IVaultHandler.FunctionChoices.AddCollateral, true);
    assertEq(
      ethVault.isDisabled(IVaultHandler.FunctionChoices.CreateVault),
      true
    );
    assertEq(
      ethVault.isDisabled(IVaultHandler.FunctionChoices.AddCollateral),
      true
    );
    //execution
    ethVault.toggleFunction(IVaultHandler.FunctionChoices.CreateVault, false);
    assertEq(
      ethVault.isDisabled(IVaultHandler.FunctionChoices.CreateVault),
      false
    );
    //assert
    assertEq(
      ethVault.isDisabled(IVaultHandler.FunctionChoices.AddCollateral),
      true
    );
  }
}
