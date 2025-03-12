// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";

import "../../../_base/BaseTest.sol";
import "../../../_mock/MockTokenVault.sol";
import "../../../_mock/MockUniswapV2Router01.sol";
import "../../../_mock/MockV3SwapRouter.sol";
import "../../../_mock/MockETHLpToken.sol";
import "../../../_mock/MockWETH9.sol";
import "../../../../../../contracts/v0.8.16/migrators/token-vaults/SushiSwapLPVaultMigrator.sol";
import "../../../../../../contracts/v0.8.16/interfaces/apis/IUniswapV2Router02.sol";

/// @title An abstraction of the SushiSwapLPVaultMigrator Testing contract, containing a scaffolding method for creating the fixture
abstract contract SushiSwapLPVaultMigratorBaseTest is BaseTest {
  SushiSwapLPVaultMigrator internal migrator;

  MockUniswapV2Router01 internal fakeSushiSwapRouter;
  MockV3SwapRouter internal fakeUniswapRouter;

  MockERC20 internal mockBaseToken;
  MockETHLpToken internal mockLpToken;

  address internal constant treasury = address(12345);
  address internal constant govLPTokenVault = address(54321);
  address internal constant controller = address(65432);

  address public constant WETH9 =
    address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

  event Execute(uint256 vaultReward);

  /// @dev Foundry's setUp method
  function setUp() public virtual {
    fakeSushiSwapRouter = new MockUniswapV2Router01();
    fakeUniswapRouter = new MockV3SwapRouter();

    migrator = _setupMigrator(0.1 ether, 0.5 ether, 0.1 ether);

    mockBaseToken = _setupFakeERC20("BASE ERC20 TOKEN", "BT");
    mockLpToken = new MockETHLpToken(IERC20(address(mockBaseToken)));
    mockLpToken.initialize("BT-WETH LP", "BWELP");

    fakeSushiSwapRouter.mockMapBaseTokenWithLPToken(
      address(mockBaseToken),
      address(mockLpToken)
    );
    fakeSushiSwapRouter.mockSetLpRemoveLiquidityRate(
      address(mockLpToken),
      uint256(0.5 ether),
      uint256(0.5 ether)
    );

    fakeUniswapRouter.mockSetSwapRate(address(mockBaseToken), 1 ether);
  }

  function _setupMigrator(
    uint256 _treasuryFeeRate,
    uint256 _controllerFeeRate,
    uint256 _govLPTokenVaultFeeRate
  ) internal returns (SushiSwapLPVaultMigrator) {
    SushiSwapLPVaultMigrator _migrator = new SushiSwapLPVaultMigrator(
      treasury,
      controller,
      govLPTokenVault,
      _treasuryFeeRate,
      _controllerFeeRate,
      _govLPTokenVaultFeeRate,
      IUniswapV2Router02(address(fakeSushiSwapRouter)),
      IV3SwapRouter(address(fakeUniswapRouter))
    );

    return _migrator;
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

  function _setupMockWETH9(uint256 initialAmount) internal {
    MockWETH9 mockWETH9 = new MockWETH9();
    bytes memory wrappedETH9Code = address(mockWETH9).code;

    vm.etch(WETH9, wrappedETH9Code);
    MockWETH9(payable(WETH9)).initialize("Wrapped Ether", "WETH");

    // pre-minted token for mocking purposes
    vm.deal(WETH9, initialAmount);
  }

  receive() external payable {}
}
