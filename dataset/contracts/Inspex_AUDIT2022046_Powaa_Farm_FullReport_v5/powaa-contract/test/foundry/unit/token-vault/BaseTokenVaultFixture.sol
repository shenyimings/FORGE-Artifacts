// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../_base/BaseTest.sol";
import "../_mock/MockERC20.sol";
import "../_mock/MockETHLpToken.sol";
import "../_mock/MockTokenVaultMigrator.sol";
import "../_mock/MockFeeModel.sol";
import "../../../../contracts/v0.8.16/TokenVault.sol";

abstract contract BaseTokenVaultFixture is BaseTest {
  uint256 public constant STAKE_AMOUNT_1000 = 1000 * 1e18;
  uint256 public constant TREASURY_FEE_RATE = 0.5 ether;
  address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  event RewardAdded(uint256 reward);
  event Staked(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount, uint256 fee);
  event RewardPaid(address indexed user, uint256 reward);
  event RewardsDurationUpdated(uint256 newDuration);
  event Migrate(uint256 stakingTokenAmount, uint256 vaultETHAmount);
  event ClaimETH(address indexed user, uint256 ethAmount);
  event ReduceReserve(
    address to,
    uint256 reserveAmount,
    uint256 reducedETHAmount
  );
  event SetMigrationOption(
    IMigrator migrator,
    IMigrator reserveMigrator,
    uint256 campaignEndBlock,
    address feeModel,
    uint256 feePool,
    address treasury,
    uint256 treasuryFeeRate
  );

  struct TokenVaultTestState {
    TokenVault tokenVault;
    address controller;
    address rewardDistributor;
    address treasury;
    MockFeeModel fakeFeeModel;
    MockTokenVaultMigrator fakeMigrator;
    MockTokenVaultMigrator fakeReserveMigrator;
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

  function _setupTokenVault(
    address _rewardsDistribution,
    address _rewardsToken,
    address _stakingToken,
    address _controller
  ) internal returns (TokenVault) {
    TokenVault _impl = new TokenVault();

    _impl.initialize(
      _rewardsDistribution,
      _rewardsToken,
      _stakingToken,
      _controller
    );

    return _impl;
  }

  function _scaffoldTokenVaultTestState()
    internal
    returns (TokenVaultTestState memory)
  {
    TokenVaultTestState memory _state;
    _state.controller = address(123451234);
    _state.rewardDistributor = address(123456789);
    _state.fakeFeeModel = new MockFeeModel();
    _state.fakeMigrator = new MockTokenVaultMigrator();
    _state.fakeReserveMigrator = new MockTokenVaultMigrator();
    _state.fakeRewardToken = _setupFakeERC20("Reward Token", "RT");
    _state.fakeStakingToken = _setupFakeERC20("Staking Token", "ST");
    _state.treasury = address(111);

    _state.tokenVault = _setupTokenVault(
      address(_state.rewardDistributor),
      address(_state.fakeRewardToken),
      address(_state.fakeStakingToken),
      address(_state.controller)
    );

    return _state;
  }
}
