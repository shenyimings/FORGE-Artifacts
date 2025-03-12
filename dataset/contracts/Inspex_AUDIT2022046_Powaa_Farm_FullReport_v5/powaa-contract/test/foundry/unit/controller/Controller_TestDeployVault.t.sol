// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./ControllerBase.t.sol";
import "../_mock/MockTokenVault.sol";

contract Controller_TestDeployVault is ControllerBaseTest {
  address internal constant MOCK_REWARD_DISTRIBUTION = address(10);
  address internal constant MOCK_REWARD_TOKEN = address(11);
  address internal constant MOCK_STAKING_TOKEN = address(12);
  // Controller event
  event Migrate(address[] vaults);
  event SetVault(address vault, bool isGovLPVault);
  event NewVault(address instance);

  /// @dev foundry's setUp method
  function setUp() public override {
    super.setUp();
  }

  function _deployVault(
    address _stakingToken,
    address _impl,
    bool _isGovLPVault
  ) internal returns (address) {
    // Vault can be deterministically get using staking token as a salt
    address deterministicAddress = controller.getDeterministicVault(
      _impl,
      _stakingToken
    );

    // Events should be correctly emitted
    vm.expectEmit(true, true, true, true);
    emit NewVault(deterministicAddress);
    emit SetVault(deterministicAddress, _isGovLPVault);

    controller.deployDeterministicVault(
      _impl,
      MOCK_REWARD_DISTRIBUTION,
      MOCK_REWARD_TOKEN,
      _stakingToken
    );

    return deterministicAddress;
  }

  function test_WhenCallerIsNotTheOwner() external {
    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));

    controller.deployDeterministicVault(
      address(mockTokenVaultImpl),
      MOCK_REWARD_DISTRIBUTION,
      MOCK_REWARD_TOKEN,
      MOCK_STAKING_TOKEN
    );

    vm.stopPrank();
  }

  function test_WhenSuccessFullyDeployedVault_WithTokenVault() external {
    // Vault can be deterministically get using staking token as a salt
    address deterministicAddress = _deployVault(
      MOCK_STAKING_TOKEN,
      address(mockTokenVaultImpl),
      false
    );

    // Storage of Controller should be correctly updated
    assertEq(controller.registeredVaults(deterministicAddress), true);
    assertEq(controller.tokenVaults(0), deterministicAddress);

    // Storage of a cloned instance should be correctly updated
    assertEq(
      address(MockTokenVault(payable(deterministicAddress)).masterContract()),
      address(mockTokenVaultImpl)
    );
    assertEq(
      MockTokenVault(payable(deterministicAddress)).masterContractOwner(),
      address(this)
    );
    assertEq(
      MockTokenVault(payable(deterministicAddress)).rewardsDistribution(),
      MOCK_REWARD_DISTRIBUTION
    );
    assertEq(
      MockTokenVault(payable(deterministicAddress)).rewardsToken(),
      MOCK_REWARD_TOKEN
    );
    assertEq(
      address(MockTokenVault(payable(deterministicAddress)).stakingToken()),
      MOCK_STAKING_TOKEN
    );
    assertEq(
      MockTokenVault(payable(deterministicAddress)).controller(),
      address(controller)
    );
    assertEq(
      MockTokenVault(payable(deterministicAddress)).isGovLpVault(),
      false
    );
  }

  function test_WhenSuccessFullyDeployedVault_WithTokenVault_WithFuzzyStakingToken(
    address _stakingToken
  ) external {
    // Vault can be deterministically get using staking token as a salt
    address deterministicAddress = _deployVault(
      _stakingToken,
      address(mockTokenVaultImpl),
      false
    );

    // Storage of Controller should be correctly updated
    assertEq(controller.registeredVaults(deterministicAddress), true);
    assertEq(controller.tokenVaults(0), deterministicAddress);

    // Storage of a cloned instance should be correctly updated
    assertEq(
      address(MockTokenVault(payable(deterministicAddress)).masterContract()),
      address(mockTokenVaultImpl)
    );
    assertEq(
      MockTokenVault(payable(deterministicAddress)).masterContractOwner(),
      address(this)
    );
    assertEq(
      MockTokenVault(payable(deterministicAddress)).rewardsDistribution(),
      MOCK_REWARD_DISTRIBUTION
    );
    assertEq(
      MockTokenVault(payable(deterministicAddress)).rewardsToken(),
      MOCK_REWARD_TOKEN
    );
    assertEq(
      address(MockTokenVault(payable(deterministicAddress)).stakingToken()),
      _stakingToken
    );
    assertEq(
      MockTokenVault(payable(deterministicAddress)).controller(),
      address(controller)
    );
    assertEq(
      MockTokenVault(payable(deterministicAddress)).isGovLpVault(),
      false
    );
  }

  function test_WhenSuccessFullyDeployedVault_WithGovLPVault() external {
    // Vault can be deterministically get using staking token as a salt
    address deterministicAddress = _deployVault(
      MOCK_STAKING_TOKEN,
      address(mockGovLPVaultImpl),
      true
    );

    // Storage of Controller should be correctly updated
    assertEq(controller.registeredVaults(deterministicAddress), true);
    assertEq(controller.govLPVault(), deterministicAddress);

    // Storage of a cloned instance should be correctly updated
    assertEq(
      address(MockTokenVault(payable(deterministicAddress)).masterContract()),
      address(mockGovLPVaultImpl)
    );
    assertEq(
      MockTokenVault(payable(deterministicAddress)).masterContractOwner(),
      address(this)
    );
    assertEq(
      MockTokenVault(payable(deterministicAddress)).rewardsDistribution(),
      MOCK_REWARD_DISTRIBUTION
    );
    assertEq(
      MockTokenVault(payable(deterministicAddress)).rewardsToken(),
      MOCK_REWARD_TOKEN
    );
    assertEq(
      address(MockTokenVault(payable(deterministicAddress)).stakingToken()),
      MOCK_STAKING_TOKEN
    );
    assertEq(
      MockTokenVault(payable(deterministicAddress)).controller(),
      address(controller)
    );
    assertEq(
      MockTokenVault(payable(deterministicAddress)).isGovLpVault(),
      true
    );
  }

  function test_WhenSuccessFullyDeployedVault_WithGovLPVault_WithFuzzyStakingToken(
    address _stakingToken
  ) external {
    // Vault can be deterministically get using staking token as a salt
    address deterministicAddress = _deployVault(
      _stakingToken,
      address(mockGovLPVaultImpl),
      true
    );

    // Storage of Controller should be correctly updated
    assertEq(controller.registeredVaults(deterministicAddress), true);
    assertEq(controller.govLPVault(), deterministicAddress);

    // Storage of a cloned instance should be correctly updated
    assertEq(
      address(MockTokenVault(payable(deterministicAddress)).masterContract()),
      address(mockGovLPVaultImpl)
    );
    assertEq(
      MockTokenVault(payable(deterministicAddress)).masterContractOwner(),
      address(this)
    );
    assertEq(
      MockTokenVault(payable(deterministicAddress)).rewardsDistribution(),
      MOCK_REWARD_DISTRIBUTION
    );
    assertEq(
      MockTokenVault(payable(deterministicAddress)).rewardsToken(),
      MOCK_REWARD_TOKEN
    );
    assertEq(
      address(MockTokenVault(payable(deterministicAddress)).stakingToken()),
      _stakingToken
    );
    assertEq(
      MockTokenVault(payable(deterministicAddress)).controller(),
      address(controller)
    );
    assertEq(
      MockTokenVault(payable(deterministicAddress)).isGovLpVault(),
      true
    );
  }
}
