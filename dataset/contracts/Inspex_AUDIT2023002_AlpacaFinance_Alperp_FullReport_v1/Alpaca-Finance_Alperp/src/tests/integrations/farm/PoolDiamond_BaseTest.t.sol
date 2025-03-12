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

import { BaseTest } from "../base/BaseTest.sol";
import { console } from "../../utils/console.sol";
import { PoolDiamond } from "../../../core/pool-diamond/PoolDiamond.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { PoolOracle } from "../../../core/PoolOracle.sol";
import { PoolRouter03 } from "../../../core/pool-diamond/PoolRouter03.sol";
import { DiamondLoupeFacet } from "../../../core/pool-diamond/facets/DiamondLoupeFacet.sol";
import { OwnershipFacet, OwnershipFacetInterface } from "../../../core/pool-diamond/facets/OwnershipFacet.sol";
import { GetterFacet, GetterFacetInterface } from "../../../core/pool-diamond/facets/GetterFacet.sol";
import { FundingRateFacet, FundingRateFacetInterface } from "../../../core/pool-diamond/facets/FundingRateFacet.sol";
import { LiquidityFacet, LiquidityFacetInterface } from "../../../core/pool-diamond/facets/LiquidityFacet.sol";
import { PerpTradeFacet, PerpTradeFacetInterface } from "../../../core/pool-diamond/facets/PerpTradeFacet.sol";
import { AdminFacet, AdminFacetInterface } from "../../../core/pool-diamond/facets/AdminFacet.sol";
import { FarmFacet, FarmFacetInterface } from "../../../core/pool-diamond/facets/FarmFacet.sol";
import { AccessControlFacet, AccessControlFacetInterface } from "../../../core/pool-diamond/facets/AccessControlFacet.sol";
import { DiamondInitializer } from "../../../core/pool-diamond/initializers/DiamondInitializer.sol";
import { AccessControlInitializer } from "../../../core/pool-diamond/initializers/AccessControlInitializer.sol";
import { PoolConfigInitializer } from "../../../core/pool-diamond/initializers/PoolConfigInitializer.sol";
import { PythPriceFeed } from "../../../core/PythPriceFeed.sol";

import { MockPyth as FakePyth } from "@pythnetwork/pyth-sdk-solidity/MockPyth.sol";

import { IPyth } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

import { LibAccessControl } from "../../../core/pool-diamond/libraries/LibAccessControl.sol";
import { LibPoolConfigV1 } from "../../../core/pool-diamond/libraries/LibPoolConfigV1.sol";
import { ALP } from "../../../tokens/ALP.sol";
import { IVault } from "../../../apis/alpaca/IVault.sol";
import { AlpacaVaultFarmStrategy } from "../../../core/AlpacaVaultFarmStrategy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ChainlinkPriceFeedInterface } from "../../../interfaces/ChainLinkPriceFeedInterface.sol";

import { math } from "../../utils/math.sol";

import { DiamondCutFacet, DiamondCutInterface } from "../../../core/pool-diamond/facets/DiamondCutFacet.sol";

contract PoolDiamond_BaseTest is BaseTest {
  struct PoolConfigConstructorParams {
    address treasury;
    uint64 fundingInterval;
    uint64 mintBurnFeeBps;
    uint64 taxBps;
    uint64 stableBorrowingRateFactor;
    uint64 borrowingRateFactor;
    uint64 fundingRateFactor;
    uint256 liquidationFeeUsd;
  }
  address internal constant TREASURY = address(168168168168);

  PoolRouter03 internal poolRouter;
  PoolOracle internal poolOracle;
  address internal poolDiamond;

  ProxyAdmin internal proxyAdmin;

  IVault internal alpacaBusdVault;
  IVault internal alpacaWbtcVault;
  IVault internal alpacaBnbVault;

  AlpacaVaultFarmStrategy internal busdFarmStrategy;
  AlpacaVaultFarmStrategy internal wbtcFarmStrategy;
  AlpacaVaultFarmStrategy internal bnbFarmStrategy;

  AdminFacetInterface internal poolAdminFacet;
  GetterFacetInterface internal poolGetterFacet;
  LiquidityFacetInterface internal poolLiquidityFacet;
  PerpTradeFacetInterface internal poolPerpTradeFacet;
  FarmFacetInterface internal poolFarmFacet;
  AccessControlFacetInterface internal poolAccessControlFacet;
  FundingRateFacetInterface internal poolFundingRateFacet;

  ALP internal alp;

  IERC20 internal busd;
  IERC20 internal wbtc;
  IERC20 internal bnb;

  ChainlinkPriceFeedInterface internal busdPriceFeed;
  ChainlinkPriceFeedInterface internal wbtcPriceFeed;
  ChainlinkPriceFeedInterface internal bnbPriceFeed;

  PythPriceFeed internal pythPriceFeed;
  IPyth internal pyth;

  function buildDefaultSetTokenConfigInput()
    internal
    view
    returns (address[] memory, LibPoolConfigV1.TokenConfig[] memory)
  {
    address[] memory tokens = new address[](3);
    tokens[0] = address(busd);
    tokens[1] = address(wbtc);
    tokens[2] = address(bnb);

    LibPoolConfigV1.TokenConfig[]
      memory tokenConfigs = new LibPoolConfigV1.TokenConfig[](3);
    tokenConfigs[0] = LibPoolConfigV1.TokenConfig({
      accept: true,
      isStable: true,
      isShortable: false,
      decimals: 18,
      weight: 10000,
      minProfitBps: 75,
      usdDebtCeiling: 50000000 ether,
      shortCeiling: 0,
      bufferLiquidity: 10000 ether,
      openInterestLongCeiling: 0
    });
    tokenConfigs[1] = LibPoolConfigV1.TokenConfig({
      accept: true,
      isStable: false,
      isShortable: true,
      decimals: 18,
      weight: 20000,
      minProfitBps: 75,
      usdDebtCeiling: 100000000 ether,
      shortCeiling: 100000000 * PRICE_PRECISION,
      bufferLiquidity: 10 ether,
      openInterestLongCeiling: 100000000 ether
    });
    tokenConfigs[2] = LibPoolConfigV1.TokenConfig({
      accept: true,
      isStable: false,
      isShortable: true,
      decimals: 18,
      weight: 20000,
      minProfitBps: 75,
      usdDebtCeiling: 100000000 ether,
      shortCeiling: 100000000 * PRICE_PRECISION,
      bufferLiquidity: 10 ether,
      openInterestLongCeiling: 100000000 ether
    });

    return (tokens, tokenConfigs);
  }

  function zeroBytesArr() internal pure returns (bytes[] memory) {
    bytes[] memory data = new bytes[](1);
    return data;
  }

  function buildDefaultSetPriceFeedInput()
    internal
    view
    returns (address[] memory, PoolOracle.PriceFeedInfo[] memory)
  {
    address[] memory tokens = new address[](3);
    tokens[0] = address(busd);
    tokens[1] = address(wbtc);
    tokens[2] = address(bnb);

    PoolOracle.PriceFeedInfo[]
      memory priceFeedInfo = new PoolOracle.PriceFeedInfo[](3);
    priceFeedInfo[0] = PoolOracle.PriceFeedInfo({
      priceFeed: busdPriceFeed,
      decimals: 8,
      spreadBps: 0,
      isStrictStable: false
    });
    priceFeedInfo[1] = PoolOracle.PriceFeedInfo({
      priceFeed: wbtcPriceFeed,
      decimals: 8,
      spreadBps: 0,
      isStrictStable: false
    });
    priceFeedInfo[2] = PoolOracle.PriceFeedInfo({
      priceFeed: bnbPriceFeed,
      decimals: 8,
      spreadBps: 0,
      isStrictStable: false
    });

    return (tokens, priceFeedInfo);
  }

  /// @dev Foundry's setUp method
  function setUp() public virtual override {
    super.setUp();

    busd = IERC20(BUSD_TOKEN);
    wbtc = IERC20(WBTC_TOKEN);
    bnb = IERC20(BNB_TOKEN);

    busdPriceFeed = ChainlinkPriceFeedInterface(BUSD_CHAINLINK_ORACLE);
    wbtcPriceFeed = ChainlinkPriceFeedInterface(WBTC_CHAINLINK_ORACLE);
    bnbPriceFeed = ChainlinkPriceFeedInterface(BNB_CHAINLINK_ORACLE);

    proxyAdmin = new ProxyAdmin();

    PoolConfigConstructorParams
      memory poolConfigParams = PoolConfigConstructorParams({
        treasury: TREASURY,
        fundingInterval: 1 hours,
        mintBurnFeeBps: 30,
        taxBps: 50,
        stableBorrowingRateFactor: 100,
        borrowingRateFactor: 100,
        fundingRateFactor: 25,
        liquidationFeeUsd: 5 * PRICE_PRECISION
      });

    (poolOracle, poolDiamond) = deployPoolDiamond(poolConfigParams);

    alpacaBusdVault = IVault(ALPACA_BUSD_VAULT);
    busdFarmStrategy = deployAlpacaVaultFarmStrategy(
      BUSD_TOKEN,
      address(alpacaBusdVault)
    );

    alpacaWbtcVault = IVault(ALPACA_WBTC_VAULT);
    wbtcFarmStrategy = deployAlpacaVaultFarmStrategy(
      WBTC_TOKEN,
      address(alpacaWbtcVault)
    );

    alpacaBnbVault = IVault(ALPACA_BNB_VAULT);
    bnbFarmStrategy = deployAlpacaVaultFarmStrategy(
      BNB_TOKEN,
      address(alpacaBnbVault)
    );

    poolAdminFacet = AdminFacetInterface(poolDiamond);
    poolGetterFacet = GetterFacetInterface(poolDiamond);
    poolLiquidityFacet = LiquidityFacetInterface(poolDiamond);
    poolPerpTradeFacet = PerpTradeFacetInterface(poolDiamond);
    poolFarmFacet = FarmFacetInterface(poolDiamond);
    poolAccessControlFacet = AccessControlFacetInterface(poolDiamond);
    poolFundingRateFacet = FundingRateFacetInterface(poolDiamond);

    alp = poolGetterFacet.alp();

    // Pyth PriceFeed
    pyth = deployFakePyth(1, 0.01 ether); // no older than 1 sec for getPrice, 0.01 for fee
    pythPriceFeed = deployPythPriceFeed(address(pyth));
    poolRouter = deployPoolRouter(
      address(bnb),
      poolDiamond,
      address(pythPriceFeed)
    );
    poolAdminFacet.setRouter(address(poolRouter));

    alp.setWhitelist(address(poolRouter), true);

    // for majority of orderbook test cases, can omit pyth price first
    pythPriceFeed.setFavorRefPrice(true);
    pythPriceFeed.setUpdater(address(poolRouter), true);
    pythPriceFeed.setMaxPriceAge(15);
  }

  function deployDiamondCutFacet() internal returns (DiamondCutFacet) {
    return new DiamondCutFacet();
  }

  function deployDiamondInitializer() internal returns (DiamondInitializer) {
    return new DiamondInitializer();
  }

  function _setupUpgradeable(
    bytes memory _logicBytecode,
    bytes memory _initializer
  ) internal returns (address) {
    bytes memory _proxyBytecode = abi.encodePacked(
      vm.getCode(
        "./out/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json"
      )
    );

    address _logic;
    assembly {
      _logic := create(0, add(_logicBytecode, 0x20), mload(_logicBytecode))
    }

    _proxyBytecode = abi.encodePacked(
      _proxyBytecode,
      abi.encode(_logic, address(proxyAdmin), _initializer)
    );

    address _proxy;
    assembly {
      _proxy := create(0, add(_proxyBytecode, 0x20), mload(_proxyBytecode))
      if iszero(extcodesize(_proxy)) {
        revert(0, 0)
      }
    }

    return _proxy;
  }

  function deployPoolOracle(uint80 roundDepth) internal returns (PoolOracle) {
    bytes memory _logicBytecode = abi.encodePacked(
      vm.getCode("./out/PoolOracle.sol/PoolOracle.json")
    );
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(uint80)")),
      roundDepth
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer);
    return PoolOracle(payable(_proxy));
  }

  function deployALP() internal returns (ALP) {
    bytes memory _logicBytecode = abi.encodePacked(
      vm.getCode("./out/ALP.sol/ALP.json")
    );
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(uint256)")),
      [1 days]
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer);
    return ALP(payable(_proxy));
  }

  function deployDiamondLoupeFacet(DiamondCutFacet diamondCutFacet)
    internal
    returns (DiamondLoupeFacet, bytes4[] memory)
  {
    DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();

    bytes4[] memory selectors = new bytes4[](4);
    selectors[0] = DiamondLoupeFacet.facets.selector;
    selectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
    selectors[2] = DiamondLoupeFacet.facetAddresses.selector;
    selectors[3] = DiamondLoupeFacet.facetAddress.selector;

    DiamondCutInterface.FacetCut[] memory facetCuts = buildFacetCut(
      address(diamondLoupeFacet),
      DiamondCutInterface.FacetCutAction.Add,
      selectors
    );

    diamondCutFacet.diamondCut(facetCuts, address(0), "");
    return (diamondLoupeFacet, selectors);
  }

  function deployOwnershipFacet(DiamondCutFacet diamondCutFacet)
    internal
    returns (OwnershipFacet, bytes4[] memory)
  {
    OwnershipFacet ownershipFacet = new OwnershipFacet();

    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = OwnershipFacet.transferOwnership.selector;
    selectors[1] = OwnershipFacet.owner.selector;

    DiamondCutInterface.FacetCut[] memory facetCuts = buildFacetCut(
      address(ownershipFacet),
      DiamondCutInterface.FacetCutAction.Add,
      selectors
    );

    diamondCutFacet.diamondCut(facetCuts, address(0), "");
    return (ownershipFacet, selectors);
  }

  function deployGetterFacet(DiamondCutFacet diamondCutFacet)
    internal
    returns (GetterFacet, bytes4[] memory)
  {
    GetterFacet getterFacet = new GetterFacet();

    bytes4[] memory selectors = new bytes4[](66);
    selectors[0] = GetterFacet.getAddLiquidityFeeBps.selector;
    selectors[1] = GetterFacet.getRemoveLiquidityFeeBps.selector;
    selectors[2] = GetterFacet.getSwapFeeBps.selector;
    selectors[3] = GetterFacet.getAum.selector;
    selectors[4] = GetterFacet.getAumE18.selector;
    selectors[5] = GetterFacet.getNextBorrowingRate.selector;
    selectors[6] = GetterFacet.alp.selector;
    selectors[7] = GetterFacet.totalTokenWeight.selector;
    selectors[8] = GetterFacet.totalUsdDebt.selector;
    selectors[9] = GetterFacet.liquidityOf.selector;
    selectors[10] = GetterFacet.feeReserveOf.selector;
    selectors[11] = GetterFacet.usdDebtOf.selector;
    selectors[12] = GetterFacet.getDelta.selector;
    selectors[13] = GetterFacet.getEntryBorrowingRate.selector;
    selectors[14] = GetterFacet.getBorrowingFee.selector;
    selectors[15] = GetterFacet.getNextShortAveragePrice.selector;
    selectors[16] = GetterFacet.getPositionFee.selector;
    selectors[17] = GetterFacet.getPositionNextAveragePrice.selector;
    selectors[18] = GetterFacet.getSubAccount.selector;
    selectors[19] = GetterFacet.guaranteedUsdOf.selector;
    selectors[20] = GetterFacet.reservedOf.selector;
    selectors[21] = GetterFacet.getPosition.selector;
    selectors[22] = GetterFacet.getPositionWithSubAccountId.selector;
    selectors[23] = GetterFacet.getPositionDelta.selector;
    selectors[24] = GetterFacet.getPositionLeverage.selector;
    selectors[25] = GetterFacet.getRedemptionCollateral.selector;
    selectors[26] = GetterFacet.getRedemptionCollateralUsd.selector;
    selectors[27] = GetterFacet.shortSizeOf.selector;
    selectors[28] = GetterFacet.getPoolShortDelta.selector;
    selectors[29] = GetterFacet.shortAveragePriceOf.selector;
    selectors[30] = GetterFacet.getTargetValue.selector;
    selectors[31] = GetterFacet.isAllowedLiquidators.selector;
    selectors[32] = GetterFacet.isAllowAllLiquidators.selector;
    selectors[33] = GetterFacet.fundingInterval.selector;
    selectors[34] = GetterFacet.borrowingRateFactor.selector;
    selectors[35] = GetterFacet.isDynamicFeeEnable.selector;
    selectors[36] = GetterFacet.isLeverageEnable.selector;
    selectors[37] = GetterFacet.isSwapEnable.selector;
    selectors[38] = GetterFacet.liquidationFeeUsd.selector;
    selectors[39] = GetterFacet.oracle.selector;
    selectors[40] = GetterFacet.maxLeverage.selector;
    selectors[41] = GetterFacet.minProfitDuration.selector;
    selectors[42] = GetterFacet.mintBurnFeeBps.selector;
    selectors[43] = GetterFacet.positionFeeBps.selector;
    selectors[44] = GetterFacet.router.selector;
    selectors[45] = GetterFacet.stableBorrowingRateFactor.selector;
    selectors[46] = GetterFacet.stableTaxBps.selector;
    selectors[47] = GetterFacet.stableSwapFeeBps.selector;
    selectors[48] = GetterFacet.swapFeeBps.selector;
    selectors[49] = GetterFacet.taxBps.selector;
    selectors[50] = GetterFacet.tokenMetas.selector;
    selectors[51] = GetterFacet.getEntryFundingRate.selector;
    selectors[52] = GetterFacet.openInterestLong.selector;
    selectors[53] = GetterFacet.openInterestShort.selector;
    selectors[54] = GetterFacet.getNextFundingRate.selector;
    selectors[55] = GetterFacet.pendingStrategyOf.selector;
    selectors[56] = GetterFacet.strategyOf.selector;
    selectors[57] = GetterFacet.strategyDataOf.selector;
    selectors[58] = GetterFacet.getStrategyDeltaOf.selector;
    selectors[59] = GetterFacet.totalOf.selector;
    selectors[60] = GetterFacet.getFundingFeeAccounting.selector;
    selectors[61] = GetterFacet.convertTokensToUsde30.selector;
    selectors[62] = GetterFacet.getFundingFee.selector;
    selectors[63] = GetterFacet.convertUsde30ToTokens.selector;
    selectors[64] = GetterFacet
      .getNextShortAveragePriceWithRealizedPnl
      .selector;
    selectors[65] = GetterFacet.getDeltaWithoutFundingFee.selector;

    DiamondCutInterface.FacetCut[] memory facetCuts = buildFacetCut(
      address(getterFacet),
      DiamondCutInterface.FacetCutAction.Add,
      selectors
    );

    diamondCutFacet.diamondCut(facetCuts, address(0), "");
    return (getterFacet, selectors);
  }

  function deployFundingRateFacet(DiamondCutFacet diamondCutFacet)
    internal
    returns (FundingRateFacet, bytes4[] memory)
  {
    FundingRateFacet fundingRateFacet = new FundingRateFacet();

    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = FundingRateFacet.updateFundingRate.selector;

    DiamondCutInterface.FacetCut[] memory facetCuts = buildFacetCut(
      address(fundingRateFacet),
      DiamondCutInterface.FacetCutAction.Add,
      selectors
    );

    diamondCutFacet.diamondCut(facetCuts, address(0), "");
    return (fundingRateFacet, selectors);
  }

  function deployLiquidityFacet(DiamondCutFacet diamondCutFacet)
    internal
    returns (LiquidityFacet, bytes4[] memory)
  {
    LiquidityFacet liquidityFacet = new LiquidityFacet();

    bytes4[] memory selectors = new bytes4[](4);
    selectors[0] = LiquidityFacet.addLiquidity.selector;
    selectors[1] = LiquidityFacet.removeLiquidity.selector;
    selectors[2] = LiquidityFacet.swap.selector;
    selectors[3] = LiquidityFacet.flashLoan.selector;

    DiamondCutInterface.FacetCut[] memory facetCuts = buildFacetCut(
      address(liquidityFacet),
      DiamondCutInterface.FacetCutAction.Add,
      selectors
    );

    diamondCutFacet.diamondCut(facetCuts, address(0), "");
    return (liquidityFacet, selectors);
  }

  function deployPerpTradeFacet(DiamondCutFacet diamondCutFacet)
    internal
    returns (PerpTradeFacet, bytes4[] memory functionSelectors)
  {
    PerpTradeFacet perpTradeFacet = new PerpTradeFacet();

    bytes4[] memory selectors = new bytes4[](4);
    selectors[0] = PerpTradeFacet.checkLiquidation.selector;
    selectors[1] = PerpTradeFacet.increasePosition.selector;
    selectors[2] = PerpTradeFacet.decreasePosition.selector;
    selectors[3] = PerpTradeFacet.liquidate.selector;

    DiamondCutInterface.FacetCut[] memory facetCuts = buildFacetCut(
      address(perpTradeFacet),
      DiamondCutInterface.FacetCutAction.Add,
      selectors
    );

    diamondCutFacet.diamondCut(facetCuts, address(0), "");
    return (perpTradeFacet, selectors);
  }

  function buildFacetCut(
    address facet,
    DiamondCutInterface.FacetCutAction cutAction,
    bytes4[] memory selectors
  ) internal pure returns (DiamondCutInterface.FacetCut[] memory) {
    DiamondCutInterface.FacetCut[]
      memory facetCuts = new DiamondCutInterface.FacetCut[](1);
    facetCuts[0] = DiamondCutInterface.FacetCut({
      action: cutAction,
      facetAddress: facet,
      functionSelectors: selectors
    });

    return facetCuts;
  }

  function deployAdminFacet(DiamondCutFacet diamondCutFacet)
    internal
    returns (AdminFacet, bytes4[] memory)
  {
    AdminFacet adminFacet = new AdminFacet();

    bytes4[] memory selectors = new bytes4[](20);
    selectors[0] = AdminFacet.setPoolOracle.selector;
    selectors[1] = AdminFacet.withdrawFeeReserve.selector;
    selectors[2] = AdminFacet.setAllowLiquidators.selector;
    selectors[3] = AdminFacet.setFundingRate.selector;
    selectors[4] = AdminFacet.setIsAllowAllLiquidators.selector;
    selectors[5] = AdminFacet.setIsDynamicFeeEnable.selector;
    selectors[6] = AdminFacet.setIsLeverageEnable.selector;
    selectors[7] = AdminFacet.setIsSwapEnable.selector;
    selectors[8] = AdminFacet.setLiquidationFeeUsd.selector;
    selectors[9] = AdminFacet.deleteTokenConfig.selector;
    selectors[10] = AdminFacet.setMaxLeverage.selector;
    selectors[11] = AdminFacet.setMinProfitDuration.selector;
    selectors[12] = AdminFacet.setMintBurnFeeBps.selector;
    selectors[13] = AdminFacet.setPositionFeeBps.selector;
    selectors[14] = AdminFacet.setRouter.selector;
    selectors[15] = AdminFacet.setSwapFeeBps.selector;
    selectors[16] = AdminFacet.setTaxBps.selector;
    selectors[17] = AdminFacet.setTokenConfigs.selector;
    selectors[18] = AdminFacet.setTreasury.selector;
    selectors[19] = AdminFacet.setPlugin.selector;

    DiamondCutInterface.FacetCut[] memory facetCuts = buildFacetCut(
      address(adminFacet),
      DiamondCutInterface.FacetCutAction.Add,
      selectors
    );

    diamondCutFacet.diamondCut(facetCuts, address(0), "");
    return (adminFacet, selectors);
  }

  function deployFarmFacet(DiamondCutFacet diamondCutFacet)
    internal
    returns (FarmFacet, bytes4[] memory)
  {
    FarmFacet farmFacet = new FarmFacet();

    bytes4[] memory selectors = new bytes4[](3);
    selectors[0] = FarmFacet.setStrategyOf.selector;
    selectors[1] = FarmFacet.setStrategyTargetBps.selector;
    selectors[2] = FarmFacet.farm.selector;

    DiamondCutInterface.FacetCut[] memory facetCuts = buildFacetCut(
      address(farmFacet),
      DiamondCutInterface.FacetCutAction.Add,
      selectors
    );

    diamondCutFacet.diamondCut(facetCuts, address(0), "");
    return (farmFacet, selectors);
  }

  function deployAccessControlFacet(DiamondCutFacet diamondCutFacet)
    internal
    returns (AccessControlFacet, bytes4[] memory)
  {
    AccessControlFacet accessControlFacet = new AccessControlFacet();
    AccessControlInitializer accessControlInitializer = deployAccessControlInitializer();

    bytes4[] memory selectors = new bytes4[](7);
    selectors[0] = AccessControlFacet.hasRole.selector;
    selectors[1] = AccessControlFacet.getRoleAdmin.selector;
    selectors[2] = AccessControlFacet.grantRole.selector;
    selectors[3] = AccessControlFacet.revokeRole.selector;
    selectors[4] = AccessControlFacet.renounceRole.selector;
    selectors[5] = AccessControlFacet.allowPlugin.selector;
    selectors[6] = AccessControlFacet.denyPlugin.selector;

    DiamondCutInterface.FacetCut[] memory facetCuts = buildFacetCut(
      address(accessControlFacet),
      DiamondCutInterface.FacetCutAction.Add,
      selectors
    );

    diamondCutFacet.diamondCut(
      facetCuts,
      address(accessControlInitializer),
      abi.encodeWithSelector(
        bytes4(keccak256("initialize(address)")),
        address(this)
      )
    );
    return (accessControlFacet, selectors);
  }

  function initializeDiamond(DiamondCutFacet diamondCutFacet) internal {
    // Deploy DiamondInitializer
    DiamondInitializer diamondInitializer = deployDiamondInitializer();
    DiamondCutInterface.FacetCut[]
      memory facetCuts = new DiamondCutInterface.FacetCut[](0);
    diamondCutFacet.diamondCut(
      facetCuts,
      address(diamondInitializer),
      abi.encodeWithSelector(bytes4(keccak256("initialize()")))
    );
  }

  function initializePoolConfig(
    DiamondCutFacet diamondCutFacet,
    PoolConfigConstructorParams memory params
  ) internal {
    // Deploy PoolConfigInitializer
    PoolConfigInitializer poolConfigInitializer = deployPoolConfigInitializer();
    DiamondCutInterface.FacetCut[]
      memory facetCuts = new DiamondCutInterface.FacetCut[](0);
    diamondCutFacet.diamondCut(
      facetCuts,
      address(poolConfigInitializer),
      abi.encodeWithSelector(
        bytes4(
          keccak256(
            "initialize(address,uint64,uint64,uint64,uint64,uint64,uint64,uint256)"
          )
        ),
        params.treasury,
        params.fundingInterval,
        params.mintBurnFeeBps,
        params.taxBps,
        params.stableBorrowingRateFactor,
        params.borrowingRateFactor,
        params.fundingRateFactor,
        params.liquidationFeeUsd
      )
    );
  }

  function deployPoolConfigInitializer()
    internal
    returns (PoolConfigInitializer)
  {
    return new PoolConfigInitializer();
  }

  function deployAccessControlInitializer()
    internal
    returns (AccessControlInitializer)
  {
    return new AccessControlInitializer();
  }

  function deployPoolDiamond(
    PoolConfigConstructorParams memory poolConfigConstructorParams
  ) internal returns (PoolOracle, address) {
    PoolOracle _poolOracle = deployPoolOracle(3);
    alp = deployALP();

    // Deploy DimondCutFacet
    DiamondCutFacet diamondCutFacet = deployDiamondCutFacet();

    // Deploy Pool Diamond
    PoolDiamond _poolDiamond = new PoolDiamond(
      address(diamondCutFacet),
      alp,
      _poolOracle
    );

    // Config
    alp.setMinter(address(_poolDiamond), true);

    deployDiamondLoupeFacet(DiamondCutFacet(address(_poolDiamond)));
    deployFundingRateFacet(DiamondCutFacet(address(_poolDiamond)));
    deployGetterFacet(DiamondCutFacet(address(_poolDiamond)));
    deployLiquidityFacet(DiamondCutFacet(address(_poolDiamond)));
    deployOwnershipFacet(DiamondCutFacet(address(_poolDiamond)));
    deployPerpTradeFacet(DiamondCutFacet(address(_poolDiamond)));
    deployAdminFacet(DiamondCutFacet(address(_poolDiamond)));
    deployFarmFacet(DiamondCutFacet(address(_poolDiamond)));
    deployAccessControlFacet(DiamondCutFacet(address(_poolDiamond)));

    initializeDiamond(DiamondCutFacet(address(_poolDiamond)));
    initializePoolConfig(
      DiamondCutFacet(address(_poolDiamond)),
      poolConfigConstructorParams
    );

    return (_poolOracle, address(_poolDiamond));
  }

  function deployFakePyth(
    uint256 _validTimePeriod,
    uint256 _singleUpdateFeeInWei
  ) internal returns (IPyth) {
    return
      IPyth(address(new FakePyth(_validTimePeriod, _singleUpdateFeeInWei)));
  }

  function deployPythPriceFeed(address _pyth) internal returns (PythPriceFeed) {
    bytes memory _logicBytecode = abi.encodePacked(
      vm.getCode("./out/PythPriceFeed.sol/PythPriceFeed.json")
    );
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(address)")),
      _pyth
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer);
    return PythPriceFeed(payable(_proxy));
  }

  function deployPoolRouter(
    address _wNative,
    address _pool,
    address _oraclePriceUpdater
  ) internal returns (PoolRouter03) {
    return new PoolRouter03(_wNative, _pool, _oraclePriceUpdater);
  }

  function deployAlpacaVaultFarmStrategy(address token_, address vault_)
    internal
    returns (AlpacaVaultFarmStrategy)
  {
    AlpacaVaultFarmStrategy strategy = new AlpacaVaultFarmStrategy(
      token_,
      vault_,
      poolDiamond
    );

    // TODO: make sure if the approve logic is really allowed here
    vm.prank(address(strategy));
    IERC20(token_).approve(address(vault_), type(uint256).max);

    return strategy;
  }
}
