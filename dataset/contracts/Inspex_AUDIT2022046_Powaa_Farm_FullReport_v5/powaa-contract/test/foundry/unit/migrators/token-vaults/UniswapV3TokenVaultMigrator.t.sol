// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./BaseUniswapV3TokenVaultMigratorFixture.sol";
import "../../_mock/MockWETH9.sol";
import "../../../../../contracts/v0.8.16/TokenVault.sol";
import "../../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

contract UniswapV3TokenVaultMigrator_Test is
  BaseUniswapV3TokenVaultMigratorFixture
{
  using SafeMath for uint256;
  using FixedPointMathLib for uint256;

  UniswapV3TokenVaultMigratorTestState public fixture;
  address public constant WETH9 =
    address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

  uint256 public constant WETH9_NATIVE_BALANCE = 100000000 ether;

  function _setUpWithFeeParameters(
    uint256 _treasuryFeeRate,
    uint256 _controllerFeeRate,
    uint256 _govLPTokenVaultFeeRate
  ) internal {
    UniswapV3TokenVaultMigratorTestState
      memory _fixture = _scaffoldUniswapV3TokenVaultMigratorTestState(
        _treasuryFeeRate,
        _controllerFeeRate,
        _govLPTokenVaultFeeRate
      );

    fixture = UniswapV3TokenVaultMigratorTestState({
      migrator: _fixture.migrator,
      treasury: _fixture.treasury,
      controller: _fixture.controller,
      govLPTokenVault: _fixture.govLPTokenVault,
      fakeSwapRouter: _fixture.fakeSwapRouter,
      fakeTokenVault: _fixture.fakeTokenVault,
      fakeStakingToken: _fixture.fakeStakingToken
    });

    vm.expectEmit(true, true, true, true);
    emit WhitelistTokenVault(address(fixture.fakeTokenVault), true);
    fixture.migrator.whitelistTokenVault(address(fixture.fakeTokenVault), true);
  }

  function setUp() public {
    _setUpWithFeeParameters(0.1 ether, 0.5 ether, 0.1 ether);

    MockWETH9 mockWETH9 = new MockWETH9();
    bytes memory wrappedETH9Code = address(mockWETH9).code;

    vm.etch(WETH9, wrappedETH9Code);
    MockWETH9(payable(WETH9)).initialize("Wrapped Ether", "WETH");

    // pre-minted token for mocking purposes
    vm.deal(WETH9, WETH9_NATIVE_BALANCE);
    MockERC20(payable(WETH9)).mint(
      address(fixture.fakeSwapRouter),
      1000000 ether
    );
  }

  function testExecute_WhenProperlyCallWithWhitelistedAccount() external {
    fixture.fakeStakingToken.mint(address(fixture.migrator), 1000 ether);
    fixture.fakeSwapRouter.mockSetSwapRate(
      address(fixture.fakeStakingToken),
      1 ether
    );

    bytes memory data = abi.encode(
      address(fixture.fakeStakingToken),
      uint24(0)
    );

    vm.expectEmit(true, true, true, true);
    emit Execute(300 ether, 100 ether, 500 ether, 100 ether);

    vm.prank(address(fixture.fakeTokenVault));
    fixture.migrator.execute(data);

    // 10% treasury fee, 10% gov Vault fee, 50% controller fee
    assertEq(300 ether, address(fixture.fakeTokenVault).balance);
    assertEq(100 ether, address(fixture.treasury).balance);
    assertEq(100 ether, address(fixture.govLPTokenVault).balance);
    assertEq(500 ether, address(fixture.controller).balance);
  }

  function testExecute_WhenProperlyCallWithWhitelistedAccount_Fuzzy(
    uint256 amount,
    uint256 stakingTokenToEthRate,
    uint256 govLPTokenVaultFeeRate,
    uint256 treasuryFeeRate,
    uint256 controllerFeeRate
  ) external {
    amount = bound(amount, 1 ether, 10 ether);
    stakingTokenToEthRate = bound(stakingTokenToEthRate, 1 ether, 100 ether);

    // govLPTokenVaultFeeRate + treasuryFeeRate should not be more than 1e18
    govLPTokenVaultFeeRate = bound(govLPTokenVaultFeeRate, 1, 0.99 ether);
    treasuryFeeRate = bound(
      treasuryFeeRate,
      1,
      uint256(0.99 ether).sub(govLPTokenVaultFeeRate)
    );
    controllerFeeRate = bound(
      controllerFeeRate,
      1,
      uint256(0.99 ether).sub(govLPTokenVaultFeeRate).sub(treasuryFeeRate)
    );

    _setUpWithFeeParameters(
      treasuryFeeRate,
      controllerFeeRate,
      govLPTokenVaultFeeRate
    );
    fixture.fakeStakingToken.mint(address(fixture.migrator), amount);

    fixture.fakeSwapRouter.mockSetSwapRate(
      address(fixture.fakeStakingToken),
      stakingTokenToEthRate
    );
    bytes memory data = abi.encode(
      address(fixture.fakeStakingToken),
      uint24(0)
    );

    uint256 swappedEth = amount.mulWadDown(stakingTokenToEthRate);
    uint256 expectedGovTokenVaultFee = govLPTokenVaultFeeRate.mulWadDown(
      swappedEth
    );
    uint256 expectedTreasuryFee = treasuryFeeRate.mulWadDown(swappedEth);
    uint256 expectedControllerFee = controllerFeeRate.mulWadDown(swappedEth);
    uint256 expectedEthBalance = swappedEth
      .sub(expectedGovTokenVaultFee)
      .sub(expectedTreasuryFee)
      .sub(expectedControllerFee);

    MockERC20(payable(WETH9)).mint(address(fixture.fakeSwapRouter), swappedEth);
    vm.deal(WETH9, swappedEth);

    vm.expectEmit(true, true, true, true);
    emit Execute(
      expectedEthBalance,
      expectedTreasuryFee,
      expectedControllerFee,
      expectedGovTokenVaultFee
    );
    vm.prank(address(fixture.fakeTokenVault));
    fixture.migrator.execute(data);
    // 0.1 treasury fee, 0.1 gov Vault fee
    assertEq(expectedEthBalance, address(fixture.fakeTokenVault).balance);
    assertEq(expectedTreasuryFee, address(fixture.treasury).balance);
    assertEq(
      expectedGovTokenVaultFee,
      address(fixture.govLPTokenVault).balance
    );
  }

  function testExecute_WhenCallWithWhitelistedAccount_WithNoStakedTokenBalance()
    external
  {
    fixture.fakeStakingToken.mint(address(fixture.migrator), 0);

    bytes memory data = abi.encode(
      address(fixture.fakeStakingToken),
      uint24(0)
    );

    vm.expectEmit(true, true, true, true);
    emit Execute(0, 0, 0, 0);

    vm.prank(address(fixture.fakeTokenVault));
    fixture.migrator.execute(data);

    // 0.1 treasury fee, 0.1 gov Vault fee
    assertEq(0, address(fixture.fakeTokenVault).balance);
    assertEq(0, address(fixture.treasury).balance);
    assertEq(0, address(fixture.govLPTokenVault).balance);
  }

  function testExecute_WhenCallWithUnauthorizedAccount() external {
    vm.expectRevert(
      abi.encodeWithSignature(
        "UniswapV3TokenVaultMigrator_OnlyWhitelistedTokenVault()"
      )
    );

    bytes memory data = abi.encode(address(0), uint24(0));
    fixture.migrator.execute(data);
  }
}
