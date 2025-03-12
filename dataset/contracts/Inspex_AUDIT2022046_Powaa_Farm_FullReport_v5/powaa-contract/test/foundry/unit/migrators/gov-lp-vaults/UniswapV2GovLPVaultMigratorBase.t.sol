// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../../_base/BaseTest.sol";
import "../../_mock/MockERC20.sol";
import "../../_mock/MockETHLpToken.sol";
import "../../_mock/MockUniswapV2Router01.sol";
import "mock-contract/MockContract.sol";
import "../../../../../contracts/v0.8.16/interfaces/apis/IUniswapV2Router02.sol";
import "../../../../../contracts/v0.8.16/migrators/gov-lp-vaults/UniswapV2GovLPVaultMigrator.sol";
import "../../../../../lib/solmate/src/utils/SafeTransferLib.sol";

/// @title An abstraction of the UniswapV2GovLPVaultMigrator Testing contract, containing a scaffolding method for creating the fixture
abstract contract UniswapV2GovLPVaultMigratorBaseTest is BaseTest {
  using SafeTransferLib for address;

  MockUniswapV2Router01 internal mockRouter;
  MockETHLpToken internal mockLp;
  MockERC20 internal mockBaseToken;
  MockERC20 internal mockToken;

  UniswapV2GovLPVaultMigrator internal uniswapV2GovLPVaultMigrator;

  /// @dev Foundry's setUp method
  function setUp() public virtual {
    mockRouter = new MockUniswapV2Router01();

    mockToken = _setupFakeERC20("MockToken", "MT");
    mockLp = _setupMockLPToken("Gov LP Token", "G-LP");

    uniswapV2GovLPVaultMigrator = _setupUniswapV2GovLPVaultMigrator(
      IUniswapV2Router02(address(mockRouter))
    );

    mockRouter.mockMapBaseTokenWithLPToken(
      address(mockBaseToken),
      address(mockLp)
    );
    mockRouter.mockSetLpRemoveLiquidityRate(
      address(mockLp),
      uint256(0.5 ether),
      uint256(0.5 ether)
    );

    // pre-minted token for mocking purposes
    mockLp.mint(address(uniswapV2GovLPVaultMigrator), 1e18);
    MockERC20(payable(address(mockBaseToken))).mint(address(mockRouter), 1e18);
    vm.deal(address(mockRouter), 1e18);
  }

  function _setupUniswapV2GovLPVaultMigrator(IUniswapV2Router02 _router)
    internal
    returns (UniswapV2GovLPVaultMigrator)
  {
    UniswapV2GovLPVaultMigrator _uniswapV2GovLPVaultMigrator = new UniswapV2GovLPVaultMigrator(
        _router
      );

    return _uniswapV2GovLPVaultMigrator;
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

  function _setupMockLPToken(string memory _name, string memory _symbol)
    internal
    returns (MockETHLpToken)
  {
    mockBaseToken = _setupFakeERC20("Mock Base Token", "MBT");
    MockETHLpToken _impl = new MockETHLpToken(IERC20(address(mockBaseToken)));
    _impl.initialize(_name, _symbol);
    return MockETHLpToken(payable(_impl));
  }

  /// @dev Fallback function to accept ETH.
  receive() external payable {}
}
