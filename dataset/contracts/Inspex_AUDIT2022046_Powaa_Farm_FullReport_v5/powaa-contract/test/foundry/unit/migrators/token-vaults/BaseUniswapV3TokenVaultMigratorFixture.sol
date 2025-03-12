// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../../_base/BaseTest.sol";
import "../../_mock/MockERC20.sol";
import "../../_mock/MockV3SwapRouter.sol";
import "../../_mock/MockTokenVault.sol";
import "../../../../../contracts/v0.8.16/migrators/token-vaults/UniswapV3TokenVaultMigrator.sol";

abstract contract BaseUniswapV3TokenVaultMigratorFixture is BaseTest {
  struct UniswapV3TokenVaultMigratorTestState {
    UniswapV3TokenVaultMigrator migrator;
    address treasury;
    address govLPTokenVault;
    address controller;
    MockV3SwapRouter fakeSwapRouter;
    MockTokenVault fakeTokenVault;
    MockERC20 fakeStakingToken;
  }

  event Execute(
    uint256 vaultReward,
    uint256 treasuryReward,
    uint256 controllerReward,
    uint256 govLPTokenVaultReward
  );
  event WhitelistTokenVault(address tokenVault, bool whitelisted);

  error UniswapV3TokenVaultMigrator_OnlyWhitelistedTokenVault();
  error UniswapV3TokenVaultMigrator_InvalidFeeRate();

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

  function _setupUniswapV3TokenVaultMigrator(
    address _treasury,
    address _controller,
    address _govLPTokenVault,
    uint256 _treasuryFeeRate,
    uint256 _controllerFeeRate,
    uint256 _govLPTokenVaultFeeRate,
    IV3SwapRouter _router
  ) internal returns (UniswapV3TokenVaultMigrator) {
    UniswapV3TokenVaultMigrator _impl = new UniswapV3TokenVaultMigrator(
      _treasury,
      _controller,
      _govLPTokenVault,
      _treasuryFeeRate,
      _controllerFeeRate,
      _govLPTokenVaultFeeRate,
      _router
    );

    return _impl;
  }

  function _scaffoldUniswapV3TokenVaultMigratorTestState(
    uint256 _treasuryFeeRate,
    uint256 _controllerFeeRate,
    uint256 _govLPTokenVaultFeeRate
  ) internal returns (UniswapV3TokenVaultMigratorTestState memory) {
    UniswapV3TokenVaultMigratorTestState memory _state;

    _state.treasury = address(1123123);
    _state.govLPTokenVault = address(3213321);
    _state.controller = address(111);
    _state.fakeSwapRouter = new MockV3SwapRouter();
    _state.fakeTokenVault = new MockTokenVault();
    _state.fakeStakingToken = _setupFakeERC20("Fake Token", "FT");

    _state.migrator = _setupUniswapV3TokenVaultMigrator(
      _state.treasury,
      _state.controller,
      _state.govLPTokenVault,
      _treasuryFeeRate,
      _controllerFeeRate,
      _govLPTokenVaultFeeRate,
      IV3SwapRouter(address(_state.fakeSwapRouter))
    );

    return _state;
  }
}
