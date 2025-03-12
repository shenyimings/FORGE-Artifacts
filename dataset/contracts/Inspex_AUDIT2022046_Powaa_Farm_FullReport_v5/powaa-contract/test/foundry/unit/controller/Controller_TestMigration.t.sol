// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./ControllerBase.t.sol";

contract Controller_TestMigration is ControllerBaseTest {
  address internal constant MOCK_REWARD_DISTRIBUTION = address(10);
  address internal constant MOCK_REWARD_TOKEN = address(11);
  address internal constant MOCK_WITHDRAWAL_FEE_MODEL = address(12);

  // Controller event
  event Migrate(address[] vaults);
  event TransferFee(address beneficiary, uint256 fee);

  /// @dev foundry's setUp method
  function setUp() public override {
    super.setUp();
  }

  function _deployVault(address _stakingToken, address _impl)
    internal
    returns (address)
  {
    // Vault can be deterministically get using staking token as a salt
    address deterministicAddress = controller.getDeterministicVault(
      _impl,
      _stakingToken
    );

    controller.deployDeterministicVault(
      _impl,
      MOCK_REWARD_DISTRIBUTION,
      MOCK_REWARD_TOKEN,
      _stakingToken
    );

    return deterministicAddress;
  }

  function test_WhenMigrationVault_WhenNoGovLPVault() external {
    address stakingToken = address(13);

    // Deploy only token vault
    _deployVault(stakingToken, address(mockTokenVaultImpl));

    // Migration requires to have both token vault and gov LP vault
    vm.expectRevert(abi.encodeWithSignature("Controller_NoGovLPVault()"));
    controller.migrate();
  }

  function test_WhenMigrationVault_WithNoVaults() external {
    vm.expectRevert(abi.encodeWithSignature("Controller_NoVaults()"));
    controller.migrate();
  }

  function test_WhenMigrationVault_WhenAllParamsAreCorrect_WithExecutionFeeEqZero()
    external
  {
    address stakingToken = address(13);
    address govLPToken = address(14);
    address[] memory expectedMigratedVaults = new address[](2);

    // Deploy a token vault
    expectedMigratedVaults[0] = _deployVault(
      stakingToken,
      address(mockTokenVaultImpl)
    );

    // Deploy a gov LP vault
    expectedMigratedVaults[1] = _deployVault(
      govLPToken,
      address(mockGovLPVaultImpl)
    );

    // Events should be correctly emitted
    vm.expectEmit(true, true, true, true);
    emit Migrate(expectedMigratedVaults);

    // Migration requires to have both token vault and gov LP vault
    controller.migrate();
  }

  function test_WhenMigrationVault_WhenAllParamsAreCorrect_WithExecutionFeeGtZero()
    external
  {
    address stakingToken = address(13);
    address govLPToken = address(14);
    address[] memory expectedMigratedVaults = new address[](2);

    // Deploy a token vault
    expectedMigratedVaults[0] = _deployVault(
      stakingToken,
      address(mockTokenVaultImpl)
    );

    // Deploy a gov LP vault
    expectedMigratedVaults[1] = _deployVault(
      govLPToken,
      address(mockGovLPVaultImpl)
    );

    // Events should be correctly emitted
    vm.expectEmit(true, true, true, true);
    emit TransferFee(address(this), 1000 ether);
    vm.expectEmit(true, true, true, true);
    emit Migrate(expectedMigratedVaults);

    vm.deal(address(controller), 1000 ether);

    // Migration requires to have both token vault and gov LP vault
    controller.migrate();
  }

  function test_WhenMigrationVault_WhenAllParamsAreCorrect_WithFuzzyLengthOfTokenVaults(
    uint256 tokenVaultsLength,
    uint256 executionFee
  ) external {
    // token vaults length is set between 1 and 100
    tokenVaultsLength = bound(tokenVaultsLength, 1, 100);
    executionFee = bound(executionFee, 1, 1000 ether);
    uint256 startStakingToken = 13;
    address govLPToken = address(
      uint160(startStakingToken + tokenVaultsLength)
    );
    address[] memory expectedMigratedVaults = new address[](
      tokenVaultsLength + 1
    );

    // Deploy a token vaults
    for (uint256 i = 0; i < tokenVaultsLength; i++) {
      address stakingToken = address(uint160(startStakingToken + i));
      expectedMigratedVaults[i] = _deployVault(
        stakingToken,
        address(mockTokenVaultImpl)
      );
    }

    // Deploy a gov LP vault
    expectedMigratedVaults[expectedMigratedVaults.length - 1] = _deployVault(
      govLPToken,
      address(mockGovLPVaultImpl)
    );

    // Events should be correctly emitted
    vm.expectEmit(true, true, true, true);
    emit TransferFee(address(this), executionFee);
    vm.expectEmit(true, true, true, true);
    emit Migrate(expectedMigratedVaults);

    vm.deal(address(controller), executionFee);

    // Migration requires to have both token vault and gov LP vault
    controller.migrate();
  }
}
