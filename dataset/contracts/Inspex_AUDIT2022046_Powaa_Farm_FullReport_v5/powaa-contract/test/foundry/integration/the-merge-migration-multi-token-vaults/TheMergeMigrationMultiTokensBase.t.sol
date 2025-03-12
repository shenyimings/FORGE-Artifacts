// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

import "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IPeripheryPayments.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "../../../../contracts/v0.8.16/interfaces/apis/IUniswapV2Router02.sol";
import "../../../../contracts/v0.8.16/interfaces/apis/IUniswapV2Factory.sol";
import "../../../../contracts/v0.8.16/Controller.sol";
import "../../../../contracts/v0.8.16/TokenVault.sol";
import "../../../../contracts/v0.8.16/GovLPVault.sol";
import "../../../../contracts/v0.8.16/fee-model/LinearFeeModel.sol";
import "../../../../contracts/v0.8.16/migrators/gov-lp-vaults/UniswapV2GovLPVaultMigrator.sol";
import "../../../../contracts/v0.8.16/migrators/token-vaults/UniswapV3TokenVaultMigrator.sol";
import "../../../../contracts/v0.8.16/migrators/token-vaults/SushiSwapLPVaultMigrator.sol";
import "../_base/BaseTest.sol";

/// @title An abstraction of the The merge migration scenario Testing contract, containing a scaffolding method for creating the fixture
abstract contract TheMergeMigrationMultiTokensBase is BaseTest {
  using Strings for uint256;
  using SafeERC20 for IERC20;

  address public constant TREASURY = address(115);
  address public constant WITHDRAWAL_TREASURY = address(116);
  address public constant EXECUTOR = address(117);
  uint256 public constant WITHDRAWAL_TREASURY_FEE_RATE = 0.5 ether;
  uint256 public constant THE_MERGE_BLOCK = 15500000; // Assume that the merge block takes place in this block number
  uint24 public constant USDC_ETH_V3_FEE = 3000;
  uint24 public constant USDT_ETH_V3_FEE = 3000;

  // UniswapV3TokenVaultMigrator Params
  uint256 public constant TREASURY_FEE_RATE = 0.05 ether; // 5%
  uint256 public constant GOV_LP_VAULT_FEE_RATE = 0.05 ether; // 5%
  uint256 public constant CONTROLLER_FEE_RATE = 0.02 ether; // 2%

  // LinearFeeModel Params
  uint256 public constant BASE_RATE = 0;
  uint256 public constant MULTIPLIER_RATE = 0.02 ether; // 2% at 100% utilization

  // GovLPToken Params
  uint256 public constant POWAA_ETH_LIQUIDITY = 100000 ether;

  IUniswapV2Factory public uniswapV2Factory;
  IUniswapV3Factory public uniswapV3Factory;
  IUniswapV3Pool public uniswapV3USDCETHPool;

  /* ========== Migrators ========== */
  IV3SwapRouter public uniswapV3Router02;
  IUniswapV2Router02 public uniswapV2Router02;
  IUniswapV2Router02 public sushiswapRouter;
  IMigrator public govLPVaultMigrator;
  IMigrator public govLPVaultReserveMigrator;
  IMigrator public tokenVaultMigrator;
  IMigrator public tokenVaultReserveMigrator;
  IMigrator public sushiLPTokenVaultMigrator;
  IMigrator public sushiLPTokenVaultReserveMigrator;

  /* ========== Fee Model ========== */
  IFeeModel public linearFeeModel;

  /* ========== Controller ========== */
  Controller public controller;

  /* ========== TokenVault ========== */
  TokenVault public usdcTokenVault;
  TokenVault public usdcEthSushiLpVault;
  TokenVault public usdtEthSushiLpVault;
  GovLPVault public govLPVault;

  /* ========== POWAA-ETH Uniswap V2 token ========== */
  ERC20 public powaaETHUniswapV2LP;

  constructor() {
    proxyAdmin = _setupProxyAdmin();
    mathMock = _setupMathMock();
  }

  /// @dev Foundry's setUp method
  function setUp() public virtual override {
    super.setUp();
    // Setup wrap addresses to entities
    uniswapV3Router02 = IV3SwapRouter(UNISWAP_V3_SWAP_ROUTER_02);
    uniswapV2Router02 = IUniswapV2Router02(UNISWAP_V2_ROUTER_02);
    uniswapV2Factory = IUniswapV2Factory(UNISWAP_V2_FACTORY);
    uniswapV3Factory = IUniswapV3Factory(UNISWAP_V3_FACTORY_ADDRESS);
    uniswapV3USDCETHPool = IUniswapV3Pool(
      uniswapV3Factory.getPool(address(USDC), address(WETH9), USDC_ETH_V3_FEE)
    );
    sushiswapRouter = IUniswapV2Router02(SUSHI_SWAP_ROUTER);

    // Setup FeeModel
    linearFeeModel = _setupLinearFeeModel(BASE_RATE, MULTIPLIER_RATE);
    // Setup Controller
    controller = _setupController();

    // Setup TokenVault Implementation Contract
    TokenVault tokenVaultImpl = _setupTokenVaultImpl();
    // Setup GovLPVault Implementation Contract
    GovLPVault govLPVaultImpl = _setupGovLPVaultImpl();

    // Setup POWAA-ETH Uniswap V2 token
    // current liquidity = sqrt(100000e18 * 100000e18) - 10**3 = 99999999999999999999000 ~~99999.999999999999999 LP
    address[] memory addresses = new address[](1);
    addresses[0] = address(this);
    powaaETHUniswapV2LP = _setupGovLPToken(
      addresses,
      POWAA_ETH_LIQUIDITY,
      POWAA_ETH_LIQUIDITY
    );

    //  - Create GovLPVault's Clone
    controller.deployDeterministicVault(
      address(govLPVaultImpl),
      address(this),
      address(POWAAToken),
      address(powaaETHUniswapV2LP)
    );
    // Setup GovLP related Vault and Migrator
    govLPVaultMigrator = _setupUniswapV2GovLPVaultMigrator(uniswapV2Router02);
    govLPVault = GovLPVault(
      payable(
        controller.getDeterministicVault(
          address(govLPVaultImpl),
          address(powaaETHUniswapV2LP)
        )
      )
    );

    assertEq(govLPVault.getMasterContractOwner(), address(this));
    // Storage of a cloned instance should be correctly updated
    assertEq(address(govLPVault.masterContract()), address(govLPVaultImpl));
    assertEq(govLPVault.masterContractOwner(), address(this));
    assertEq(govLPVault.rewardsDistribution(), address(this));
    assertEq(govLPVault.rewardsToken(), address(POWAAToken));
    assertEq(address(govLPVault.stakingToken()), address(powaaETHUniswapV2LP));
    assertEq(govLPVault.controller(), address(controller));
    assertEq(govLPVault.isGovLpVault(), true);

    //  - Set Migration Option for govLPVault
    govLPVault.setMigrationOption(govLPVaultMigrator);

    assertEq(address(govLPVault.migrator()), address(govLPVaultMigrator));

    //  - Whitelist the vault in the migrators
    govLPVaultMigrator.whitelistTokenVault(address(govLPVault), true);
    //  - Start a reward distribution process
    POWAAToken.transfer(address(govLPVault), 6048000 ether); // 10 POWAA / sec
    govLPVault.notifyRewardAmount(6048000 ether);
    // Setup USDCToken related Vault and Migrator
    tokenVaultMigrator = _setupUniswapV3TokenVaultMigrator(
      uniswapV3Router02,
      address(govLPVault),
      GOV_LP_VAULT_FEE_RATE,
      TREASURY_FEE_RATE,
      address(controller),
      CONTROLLER_FEE_RATE
    );
    tokenVaultReserveMigrator = _setupUniswapV3TokenVaultMigrator(
      uniswapV3Router02,
      address(govLPVault),
      0,
      0,
      address(controller),
      0
    );

    usdcTokenVault = _setupTokenVault(
      address(USDC),
      address(tokenVaultImpl),
      tokenVaultMigrator,
      tokenVaultReserveMigrator,
      USDC_ETH_V3_FEE
    );

    // Setup USDC-ETH Sushiswap LP related Vault and Migrator
    sushiLPTokenVaultMigrator = _setupSushiSwapLPTokenVaultMigrator(
      sushiswapRouter,
      uniswapV3Router02,
      address(govLPVault),
      GOV_LP_VAULT_FEE_RATE,
      TREASURY_FEE_RATE,
      address(controller),
      CONTROLLER_FEE_RATE
    );
    sushiLPTokenVaultReserveMigrator = _setupSushiSwapLPTokenVaultMigrator(
      sushiswapRouter,
      uniswapV3Router02,
      address(govLPVault),
      0,
      0,
      address(controller),
      0
    );

    usdcEthSushiLpVault = _setupTokenVault(
      address(USDC_ETH_SUSHI_LP),
      address(tokenVaultImpl),
      sushiLPTokenVaultMigrator,
      sushiLPTokenVaultReserveMigrator,
      USDC_ETH_V3_FEE
    );

    usdtEthSushiLpVault = _setupTokenVault(
      address(USDT_ETH_SUSHI_LP),
      address(tokenVaultImpl),
      sushiLPTokenVaultMigrator,
      sushiLPTokenVaultReserveMigrator,
      USDT_ETH_V3_FEE
    );
  }

  function _setupTokenVault(
    address _stakingToken,
    address _impl,
    IMigrator _migrator,
    IMigrator _reserveMigrator,
    uint24 _fee
  ) internal returns (TokenVault) {
    //  - Create TokenVault's Clone
    controller.deployDeterministicVault(
      _impl,
      address(this),
      address(POWAAToken),
      address(_stakingToken)
    );
    TokenVault vault = TokenVault(
      payable(controller.getDeterministicVault(_impl, address(_stakingToken)))
    );

    assertEq(vault.getMasterContractOwner(), address(this));
    assertEq(address(vault.masterContract()), _impl);
    assertEq(vault.masterContractOwner(), address(this));
    assertEq(vault.rewardsDistribution(), address(this));
    assertEq(vault.rewardsToken(), address(POWAAToken));
    assertEq(address(vault.stakingToken()), address(_stakingToken));
    assertEq(vault.controller(), address(controller));
    assertEq(vault.isGovLpVault(), false);

    //  - Set Migration Option for vault
    vault.setMigrationOption(
      _migrator,
      _reserveMigrator,
      THE_MERGE_BLOCK,
      address(linearFeeModel),
      _fee,
      WITHDRAWAL_TREASURY,
      WITHDRAWAL_TREASURY_FEE_RATE
    );

    assertEq(address(vault.migrator()), address(_migrator));
    assertEq(address(vault.reserveMigrator()), address(_reserveMigrator));
    assertEq(address(vault.withdrawalFeeModel()), address(linearFeeModel));
    assertEq(vault.feePool(), USDC_ETH_V3_FEE);
    assertEq(vault.treasury(), WITHDRAWAL_TREASURY);
    assertEq(vault.treasuryFeeRate(), WITHDRAWAL_TREASURY_FEE_RATE);
    assertEq(vault.campaignEndBlock(), THE_MERGE_BLOCK);

    //  - Whitelist the vault in the migrators
    _migrator.whitelistTokenVault(address(vault), true);
    _reserveMigrator.whitelistTokenVault(address(vault), true);
    //  - Start a reward distribution process
    POWAAToken.transfer(address(vault), 6048000 ether); // 10 POWAA / sec
    vault.notifyRewardAmount(6048000 ether);

    return vault;
  }

  function _distributeUSDC(address[] memory addresses, uint256 _amount)
    internal
  {
    vm.startPrank(USDC_PHILANTHROPIST);
    for (uint256 i = 0; i < addresses.length; i++) {
      USDC.transfer(addresses[i], _amount);
    }
    vm.stopPrank();
  }

  function _setupUniswapV2GovLPVaultMigrator(IUniswapV2Router02 _router)
    internal
    returns (UniswapV2GovLPVaultMigrator)
  {
    return new UniswapV2GovLPVaultMigrator(_router);
  }

  function _setupUniswapV3TokenVaultMigrator(
    IV3SwapRouter _router,
    address _govLPVault,
    uint256 _govLPVaultFeeRate,
    uint256 _treasuryFeeRate,
    address _controller,
    uint256 _controllerFeeRate
  ) internal returns (UniswapV3TokenVaultMigrator) {
    return
      new UniswapV3TokenVaultMigrator(
        TREASURY,
        _controller,
        _govLPVault,
        _treasuryFeeRate,
        _controllerFeeRate,
        _govLPVaultFeeRate,
        _router
      );
  }

  function _setupSushiSwapLPTokenVaultMigrator(
    IUniswapV2Router02 _sushiRouter,
    IV3SwapRouter _uniV3Router,
    address _govLPVault,
    uint256 _govLPVaultFeeRate,
    uint256 _treasuryFeeRate,
    address _controller,
    uint256 _controllerFeeRate
  ) internal returns (SushiSwapLPVaultMigrator) {
    return
      new SushiSwapLPVaultMigrator(
        TREASURY,
        _controller,
        _govLPVault,
        _treasuryFeeRate,
        _controllerFeeRate,
        _govLPVaultFeeRate,
        _sushiRouter,
        _uniV3Router
      );
  }

  function _setupSushiswapLPTokenVaultMigrator(
    IV3SwapRouter _uniV3Router,
    IUniswapV2Router02 _sushiRouter,
    address _govLPVault,
    uint256 _govLPVaultFeeRate,
    uint256 _treasuryFeeRate,
    address _controller,
    uint256 _controllerFeeRate
  ) internal returns (SushiSwapLPVaultMigrator) {
    return
      new SushiSwapLPVaultMigrator(
        TREASURY,
        _controller,
        _govLPVault,
        _treasuryFeeRate,
        _controllerFeeRate,
        _govLPVaultFeeRate,
        _sushiRouter,
        _uniV3Router
      );
  }

  function _setupLinearFeeModel(uint256 _baseRate, uint256 _multiplierRate)
    internal
    returns (LinearFeeModel)
  {
    return new LinearFeeModel(_baseRate, _multiplierRate);
  }

  function _setupController() internal returns (Controller) {
    return new Controller();
  }

  function _setupGovLPToken(
    address[] memory _recipients,
    uint256 _powaaSupply,
    uint256 _ethSupply
  ) internal returns (ERC20) {
    for (uint256 i = 0; i < _recipients.length; i++) {
      // Increase ETH supply to the owner, so that LP can be created
      vm.deal(address(this), _ethSupply);
      // Approve router to seize some POWAA from the owner, so that LP can be created
      POWAAToken.approve(address(uniswapV2Router02), _powaaSupply);
      // Add Liquidity + Create LP
      uniswapV2Router02.addLiquidityETH{ value: _ethSupply }(
        address(POWAAToken),
        _powaaSupply,
        0,
        0,
        _recipients[i],
        block.timestamp
      );
    }
    return ERC20(uniswapV2Factory.getPair(address(POWAAToken), address(WETH9)));
  }

  function _setupLPToken(
    address[] memory _recipients,
    address _router,
    address _donor,
    address _baseToken,
    uint256 _baseTokenSupply,
    uint256 _ethSupply
  ) internal returns (uint256 amountToken, uint256 amountETH) {
    IERC20(_baseToken).safeApprove(address(_router), type(uint256).max);
    for (uint256 i = 0; i < _recipients.length; i++) {
      vm.deal(_donor, 1 ether);
      vm.prank(_donor);
      IERC20(_baseToken).safeTransfer(address(this), _baseTokenSupply);
      // Increase ETH supply to the owner, so that LP can be created
      vm.deal(address(this), _ethSupply);
      // Add Liquidity + Create LP
      (amountToken, amountETH, ) = IUniswapV2Router02(_router).addLiquidityETH{
        value: _ethSupply
      }(
        address(_baseToken),
        _baseTokenSupply,
        0,
        0,
        _recipients[i],
        block.timestamp
      );
    }
    return (amountToken, amountETH);
  }

  function _setupTokenVaultImpl() internal returns (TokenVault) {
    return new TokenVault();
  }

  function _setupGovLPVaultImpl() internal returns (GovLPVault) {
    return new GovLPVault();
  }
}
