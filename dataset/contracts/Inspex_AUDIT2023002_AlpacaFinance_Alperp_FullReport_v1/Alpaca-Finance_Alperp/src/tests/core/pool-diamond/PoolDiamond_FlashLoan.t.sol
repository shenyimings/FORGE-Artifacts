// SPDX-License-Identifier: MIT
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/
pragma solidity 0.8.17;

import { PoolDiamond_BaseTest, LibPoolConfigV1, console, GetterFacetInterface, LiquidityFacetInterface, MockFlashLoanBorrower } from "./PoolDiamond_BaseTest.t.sol";

contract PoolDiamond_FlashLoanTest is PoolDiamond_BaseTest {
  MockFlashLoanBorrower mockFlashLoanBorrower;

  function setUp() public override {
    super.setUp();

    (
      address[] memory tokens2,
      LibPoolConfigV1.TokenConfig[] memory tokenConfigs2
    ) = buildDefaultSetTokenConfigInput2();

    poolAdminFacet.setTokenConfigs(tokens2, tokenConfigs2);

    // Feed prices
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(60000 * 10**8);
    bnbPriceFeed.setLatestAnswer(300 * 10**8);

    mockFlashLoanBorrower = deployMockFlashLoanBorrower();
  }

  function testRevert_WhenFlashLoanMoreThanPoolBalance() external {
    address[] memory tokens = new address[](1);
    tokens[0] = address(dai);

    uint256[] memory amounts = new uint256[](1);
    amounts[0] = 100 ether;

    address[] memory receivers = new address[](1);
    receivers[0] = address(mockFlashLoanBorrower);

    vm.expectRevert("ERC20: transfer amount exceeds balance");
    poolLiquidityFacet.flashLoan(
      mockFlashLoanBorrower,
      receivers,
      tokens,
      amounts,
      ""
    );
  }

  function testRevert_WhenAmountLengthMoreThanTokenLength() external {
    address[] memory tokens = new address[](1);
    tokens[0] = address(dai);

    uint256[] memory amounts = new uint256[](2);
    amounts[0] = 100 ether;
    amounts[1] = 100 ether;

    address[] memory receivers = new address[](1);
    receivers[0] = address(mockFlashLoanBorrower);

    vm.expectRevert(abi.encodeWithSignature("LiquidityFacet_BadLength()"));
    poolLiquidityFacet.flashLoan(
      mockFlashLoanBorrower,
      receivers,
      tokens,
      amounts,
      ""
    );
  }

  function testRevert_WhenReceiversLengthMoreThanTokenLength() external {
    address[] memory tokens = new address[](1);
    tokens[0] = address(dai);

    uint256[] memory amounts = new uint256[](1);
    amounts[0] = 100 ether;

    address[] memory receivers = new address[](2);
    receivers[0] = address(mockFlashLoanBorrower);
    receivers[1] = address(mockFlashLoanBorrower);

    vm.expectRevert(abi.encodeWithSignature("LiquidityFacet_BadLength()"));
    poolLiquidityFacet.flashLoan(
      mockFlashLoanBorrower,
      receivers,
      tokens,
      amounts,
      ""
    );
  }

  function testRevert_WhenReceiversAndAmountLengthMoreThanTokenLength()
    external
  {
    address[] memory tokens = new address[](1);
    tokens[0] = address(dai);

    uint256[] memory amounts = new uint256[](2);
    amounts[0] = 100 ether;
    amounts[1] = 100 ether;

    address[] memory receivers = new address[](2);
    receivers[0] = address(mockFlashLoanBorrower);
    receivers[1] = address(mockFlashLoanBorrower);

    vm.expectRevert(abi.encodeWithSignature("LiquidityFacet_BadLength()"));
    poolLiquidityFacet.flashLoan(
      mockFlashLoanBorrower,
      receivers,
      tokens,
      amounts,
      ""
    );
  }

  function testRevert_WhenReturnBalanceNotCorrect() external {
    // Add some liquidity
    dai.mint(address(poolDiamond), 200 ether);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    address[] memory tokens = new address[](1);
    tokens[0] = address(dai);

    uint256[] memory amounts = new uint256[](1);
    amounts[0] = 100 ether;

    address[] memory receivers = new address[](1);
    receivers[0] = address(mockFlashLoanBorrower);

    vm.expectRevert(abi.encodeWithSignature("LiquidityFacet_BadFlashLoan()"));
    poolLiquidityFacet.flashLoan(
      mockFlashLoanBorrower,
      receivers,
      tokens,
      amounts,
      ""
    );
  }

  function testCorrectness_WhenFlashLoan() external {
    // Add some liquidity
    dai.mint(address(poolDiamond), 200 ether);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    address[] memory tokens = new address[](1);
    tokens[0] = address(dai);

    uint256[] memory amounts = new uint256[](1);
    amounts[0] = 100 ether;

    address[] memory receivers = new address[](1);
    receivers[0] = address(mockFlashLoanBorrower);

    // Mint 100 * 0.05% = 0.05 DAI to mockFlashLoanBorrower as a fee
    dai.mint(address(mockFlashLoanBorrower), 0.05 ether);

    poolLiquidityFacet.flashLoan(
      mockFlashLoanBorrower,
      receivers,
      tokens,
      amounts,
      ""
    );

    // Assert pool's state
    // Pool's DAI balance should be:
    // = 200 + 0.05
    // = 200.05 DAI
    // Pool should make:
    // = (200 * 0.003) + 0.05 = 0.65 DAI
    // DAI's balance should match with pool state.
    assertEq(dai.balanceOf(address(poolDiamond)), 200 ether + 0.05 ether);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.65 ether);
    checkPoolBalanceWithState(address(dai), 0);
  }
}
