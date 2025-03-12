// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../_base/BaseTest.sol";
import "../_mock/MockERC20.sol";
import "../_mock/MockETHLpToken.sol";
import "../_mock/MockGovLPMigrator.sol";
import "../../../../contracts/v0.8.16/GovLPVault.sol";

abstract contract BaseGovLPVaultFixture is BaseTest {
  uint256 public constant STAKE_AMOUNT_1000 = 1000 * 1e18;

  address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  event Staked(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount, uint256 fee);
  event Migrate(
    uint256 stakingTokenAmount,
    uint256 returnETHAmount,
    uint256 returnPOWAAAmount
  );
  event ReduceReserve(uint256 reserveAmount, uint256 reducedETHAmount);
  event SetMigrationOption(IMigrator migrator);

  struct GovLPVaultTestState {
    GovLPVault govLPVault;
    address controller;
    address rewardDistributor;
    MockGovLPMigrator fakeMigrator;
    MockERC20 fakeRewardToken;
    MockERC20 fakeStakingToken;
    MockETHLpToken fakeGovLpToken;
  }

  function _setupFakeERC20(string memory _name, string memory _symbol)
    internal
    returns (MockERC20)
  {
    MockERC20 _impl = new MockERC20();
    TransparentUpgradeableProxy _proxy = new TransparentUpgradeableProxy(
      address(_impl),
      address(proxyAdmin),
      abi.encodeWithSelector(
        bytes4(keccak256("initialize(string,string)")),
        _name,
        _symbol
      )
    );
    return MockERC20(payable(_proxy));
  }

  function _setupGovLPVault(
    address _rewardsDistribution,
    address _rewardsToken,
    address _stakingToken,
    address _controller
  ) internal returns (GovLPVault) {
    GovLPVault _impl = new GovLPVault();

    _impl.initialize(
      _rewardsDistribution,
      _rewardsToken,
      _stakingToken,
      _controller
    );

    return _impl;
  }

  function _scaffoldGovLPVaultLPTestState()
    internal
    returns (GovLPVaultTestState memory)
  {
    GovLPVaultTestState memory _state;
    _state.controller = address(123451234);
    _state.rewardDistributor = address(123456789);
    _state.fakeMigrator = new MockGovLPMigrator();
    _state.fakeRewardToken = _setupFakeERC20("Reward Token", "RT");
    _state.fakeGovLpToken = new MockETHLpToken(
      IERC20(address(_state.fakeRewardToken))
    );
    _state.fakeStakingToken = MockERC20(payable(_state.fakeGovLpToken));

    _state.fakeGovLpToken.initialize("Gov LP Token", "G-LP");

    _state.govLPVault = _setupGovLPVault(
      address(_state.rewardDistributor),
      address(_state.fakeRewardToken),
      address(_state.fakeGovLpToken),
      address(_state.controller)
    );

    return _state;
  }
}
