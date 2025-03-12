// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { DSTest } from "./DSTest.sol";

import { VM } from "../utils/VM.sol";
import { console } from "../utils/console.sol";
import { stdError } from "../utils/stdError.sol";
import { math } from "../utils/math.sol";

import { MintableTokenInterface } from "../../interfaces/MintableTokenInterface.sol";

import { MockErc20 } from "../mocks/MockERC20.sol";
import { MockWNative } from "../mocks/MockWNative.sol";
import { MockChainlinkPriceFeed } from "../mocks/MockChainlinkPriceFeed.sol";
import { MockDonateVault } from "../mocks/MockDonateVault.sol";
import { MockFlashLoanBorrower } from "../mocks/MockFlashLoanBorrower.sol";
import { MockStrategy } from "../mocks/MockStrategy.sol";

import { PoolOracle } from "../../core/PoolOracle.sol";
import { PLP } from "../../tokens/PLP.sol";
import { P88 } from "../../tokens/P88.sol";
import { EsP88 } from "../../tokens/EsP88.sol";
import { DragonPoint } from "../../tokens/DragonPoint.sol";

import { PLPStaking } from "../../staking/PLPStaking.sol";
import { DragonStaking } from "../../staking/DragonStaking.sol";
import { FeedableRewarder } from "../../staking/FeedableRewarder.sol";
import { AdHocMintRewarder } from "../../staking/AdHocMintRewarder.sol";
import { WFeedableRewarder } from "../../staking/WFeedableRewarder.sol";
import { RewardDistributor } from "../../staking/RewardDistributor.sol";
import { Compounder } from "../../staking/Compounder.sol";
import { Vester } from "../../vesting/Vester.sol";
import { ProxyAdmin } from "../interfaces/ProxyAdmin.sol";
import { Lockdrop } from "../../lockdrop/Lockdrop.sol";
import { LockdropGateway } from "../../lockdrop/LockdropGateway.sol";
import { LockdropConfig } from "../../lockdrop/LockdropConfig.sol";
import { LockdropCompounder } from "../../lockdrop/LockdropCompounder.sol";
import { IPool } from "../../interfaces/IPool.sol";
import { IStaking } from "../../staking/interfaces/IStaking.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Diamond things
// Libs
import { LibPoolConfigV1 } from "../../core/pool-diamond/libraries/LibPoolConfigV1.sol";
// Facets
import { DiamondCutFacet, DiamondCutInterface } from "../../core/pool-diamond/facets/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "../../core/pool-diamond/facets/DiamondLoupeFacet.sol";
import { OwnershipFacet, OwnershipFacetInterface } from "../../core/pool-diamond/facets/OwnershipFacet.sol";
import { GetterFacet, GetterFacetInterface } from "../../core/pool-diamond/facets/GetterFacet.sol";
import { FundingRateFacet, FundingRateFacetInterface } from "../../core/pool-diamond/facets/FundingRateFacet.sol";
import { LiquidityFacet, LiquidityFacetInterface } from "../../core/pool-diamond/facets/LiquidityFacet.sol";
import { PerpTradeFacet, PerpTradeFacetInterface } from "../../core/pool-diamond/facets/PerpTradeFacet.sol";
import { AdminFacet, AdminFacetInterface } from "../../core/pool-diamond/facets/AdminFacet.sol";
import { FarmFacet, FarmFacetInterface } from "../../core/pool-diamond/facets/FarmFacet.sol";
import { AccessControlFacet, AccessControlFacetInterface } from "../../core/pool-diamond/facets/AccessControlFacet.sol";

import { LibAccessControl } from "../../core/pool-diamond/libraries/LibAccessControl.sol";
import { DiamondInitializer } from "../../core/pool-diamond/initializers/DiamondInitializer.sol";
import { PoolConfigInitializer } from "../../core/pool-diamond/initializers/PoolConfigInitializer.sol";
import { AccessControlInitializer } from "../../core/pool-diamond/initializers/AccessControlInitializer.sol";
import { PoolDiamond } from "../../core/pool-diamond/PoolDiamond.sol";

import { PoolRouter } from "../../core/pool-diamond/PoolRouter.sol";
import { Orderbook } from "../../core/pool-diamond/Orderbook.sol";
import { MockWNative } from "src/tests/mocks/MockWNative.sol";
import { MerkleAirdrop } from "src/airdrop/MerkleAirdrop.sol";
import { MerkleAirdropFactory } from "src/airdrop/MerkleAirdropFactory.sol";
import { MerkleAirdropGateway } from "src/airdrop/MerkleAirdropGateway.sol";

// solhint-disable const-name-snakecase
// solhint-disable no-inline-assembly
contract BaseTest is DSTest {
  uint256 internal constant PRICE_PRECISION = 10**30;
  uint256 internal constant BPS = 10000;

  struct PoolConfigConstructorParams2 {
    address treasury;
    uint64 fundingInterval;
    uint64 mintBurnFeeBps;
    uint64 taxBps;
    uint64 stableFundingRateFactor;
    uint64 fundingRateFactor;
    uint256 liquidationFeeUsd;
  }
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

  VM internal constant vm = VM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

  // Note: Avoid using address(1) as it is reserved for Ecrecover.
  // ref: https://ethereum.stackexchange.com/questions/89447/how-does-ecrecover-get-compiled
  // One pitfall is that, when transferring native token to address(1),
  // it will revert with PRECOMPILE::ecrecover.
  address internal constant ALICE = address(5);
  address internal constant BOB = address(2);
  address internal constant CAT = address(3);
  address internal constant DAVE = address(4);

  address internal constant TREASURY = address(168168168168);

  MockWNative internal matic;
  MockErc20 internal weth;
  MockErc20 internal wbtc;
  MockErc20 internal dai;
  MockErc20 internal usdc;
  MockErc20 internal randomErc20;

  MockChainlinkPriceFeed internal maticPriceFeed;
  MockChainlinkPriceFeed internal wethPriceFeed;
  MockChainlinkPriceFeed internal wbtcPriceFeed;
  MockChainlinkPriceFeed internal daiPriceFeed;
  MockChainlinkPriceFeed internal usdcPriceFeed;

  ProxyAdmin internal proxyAdmin;

  constructor() {
    matic = new MockWNative();
    weth = deployMockErc20("Wrapped Ethereum", "WETH", 18);
    wbtc = deployMockErc20("Wrapped Bitcoin", "WBTC", 8);
    dai = deployMockErc20("DAI Stablecoin", "DAI", 18);
    usdc = deployMockErc20("USD Coin", "USDC", 6);
    randomErc20 = deployMockErc20("Random ERC20", "RAND", 18);

    maticPriceFeed = deployMockChainlinkPriceFeed();
    wethPriceFeed = deployMockChainlinkPriceFeed();
    wbtcPriceFeed = deployMockChainlinkPriceFeed();
    daiPriceFeed = deployMockChainlinkPriceFeed();
    usdcPriceFeed = deployMockChainlinkPriceFeed();

    proxyAdmin = _setupProxyAdmin();
  }

  function _setupProxyAdmin() internal returns (ProxyAdmin) {
    bytes memory _bytecode = abi.encodePacked(
      vm.getCode("./out/ProxyAdmin.sol/ProxyAdmin.json")
    );
    address _address;
    assembly {
      _address := create(0, add(_bytecode, 0x20), mload(_bytecode))
    }
    return ProxyAdmin(address(_address));
  }

  function buildDefaultSetPriceFeedInput()
    internal
    view
    returns (address[] memory, PoolOracle.PriceFeedInfo[] memory)
  {
    address[] memory tokens = new address[](5);
    tokens[0] = address(matic);
    tokens[1] = address(weth);
    tokens[2] = address(wbtc);
    tokens[3] = address(dai);
    tokens[4] = address(usdc);

    PoolOracle.PriceFeedInfo[]
      memory priceFeedInfo = new PoolOracle.PriceFeedInfo[](5);
    priceFeedInfo[0] = PoolOracle.PriceFeedInfo({
      priceFeed: maticPriceFeed,
      decimals: 8,
      spreadBps: 0,
      isStrictStable: false
    });
    priceFeedInfo[1] = PoolOracle.PriceFeedInfo({
      priceFeed: wethPriceFeed,
      decimals: 8,
      spreadBps: 0,
      isStrictStable: false
    });
    priceFeedInfo[2] = PoolOracle.PriceFeedInfo({
      priceFeed: wbtcPriceFeed,
      decimals: 8,
      spreadBps: 0,
      isStrictStable: false
    });
    priceFeedInfo[3] = PoolOracle.PriceFeedInfo({
      priceFeed: daiPriceFeed,
      decimals: 8,
      spreadBps: 0,
      isStrictStable: false
    });
    priceFeedInfo[4] = PoolOracle.PriceFeedInfo({
      priceFeed: usdcPriceFeed,
      decimals: 8,
      spreadBps: 0,
      isStrictStable: true
    });

    return (tokens, priceFeedInfo);
  }

  function buildDefaultSetTokenConfigInput2()
    internal
    view
    returns (address[] memory, LibPoolConfigV1.TokenConfig[] memory)
  {
    address[] memory tokens = new address[](3);
    tokens[0] = address(dai);
    tokens[1] = address(wbtc);
    tokens[2] = address(matic);

    LibPoolConfigV1.TokenConfig[]
      memory tokenConfigs = new LibPoolConfigV1.TokenConfig[](3);
    tokenConfigs[0] = LibPoolConfigV1.TokenConfig({
      accept: true,
      isStable: true,
      isShortable: false,
      decimals: dai.decimals(),
      weight: 10000,
      minProfitBps: 75,
      usdDebtCeiling: 0,
      shortCeiling: 0,
      bufferLiquidity: 0,
      openInterestLongCeiling: 0
    });
    tokenConfigs[1] = LibPoolConfigV1.TokenConfig({
      accept: true,
      isStable: false,
      isShortable: true,
      decimals: wbtc.decimals(),
      weight: 10000,
      minProfitBps: 75,
      usdDebtCeiling: 0,
      shortCeiling: 0,
      bufferLiquidity: 0,
      openInterestLongCeiling: 0
    });
    tokenConfigs[2] = LibPoolConfigV1.TokenConfig({
      accept: true,
      isStable: false,
      isShortable: true,
      decimals: matic.decimals(),
      weight: 10000,
      minProfitBps: 75,
      usdDebtCeiling: 0,
      shortCeiling: 0,
      bufferLiquidity: 0,
      openInterestLongCeiling: 0
    });

    return (tokens, tokenConfigs);
  }

  function buildDefaultSetTokenConfigInput3()
    internal
    view
    returns (address[] memory, LibPoolConfigV1.TokenConfig[] memory)
  {
    address[] memory tokens = new address[](3);
    tokens[0] = address(dai);
    tokens[1] = address(wbtc);
    tokens[2] = address(matic);

    LibPoolConfigV1.TokenConfig[]
      memory tokenConfigs = new LibPoolConfigV1.TokenConfig[](3);
    tokenConfigs[0] = LibPoolConfigV1.TokenConfig({
      accept: true,
      isStable: true,
      isShortable: false,
      decimals: dai.decimals(),
      weight: 10000,
      minProfitBps: 0,
      usdDebtCeiling: 0,
      shortCeiling: 0,
      bufferLiquidity: 0,
      openInterestLongCeiling: 0
    });
    tokenConfigs[1] = LibPoolConfigV1.TokenConfig({
      accept: true,
      isStable: false,
      isShortable: true,
      decimals: wbtc.decimals(),
      weight: 10000,
      minProfitBps: 0,
      usdDebtCeiling: 0,
      shortCeiling: 0,
      bufferLiquidity: 0,
      openInterestLongCeiling: 0
    });
    tokenConfigs[2] = LibPoolConfigV1.TokenConfig({
      accept: true,
      isStable: false,
      isShortable: true,
      decimals: matic.decimals(),
      weight: 10000,
      minProfitBps: 0,
      usdDebtCeiling: 0,
      shortCeiling: 0,
      bufferLiquidity: 0,
      openInterestLongCeiling: 0
    });

    return (tokens, tokenConfigs);
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

  function deployDiamondCutFacet() internal returns (DiamondCutFacet) {
    return new DiamondCutFacet();
  }

  function deployDiamondInitializer() internal returns (DiamondInitializer) {
    return new DiamondInitializer();
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

    bytes4[] memory selectors = new bytes4[](63);
    selectors[0] = GetterFacet.getAddLiquidityFeeBps.selector;
    selectors[1] = GetterFacet.getRemoveLiquidityFeeBps.selector;
    selectors[2] = GetterFacet.getSwapFeeBps.selector;
    selectors[3] = GetterFacet.getAum.selector;
    selectors[4] = GetterFacet.getAumE18.selector;
    selectors[5] = GetterFacet.getNextBorrowingRate.selector;
    selectors[6] = GetterFacet.plp.selector;
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

  function deployMockWNative() internal returns (MockWNative) {
    return new MockWNative();
  }

  function deployMockErc20(
    string memory name,
    string memory symbol,
    uint8 decimals
  ) internal returns (MockErc20) {
    return new MockErc20(name, symbol, decimals);
  }

  function deployMockChainlinkPriceFeed()
    internal
    returns (MockChainlinkPriceFeed)
  {
    return new MockChainlinkPriceFeed();
  }

  function deployMockDonateVault(address token)
    internal
    returns (MockDonateVault)
  {
    return new MockDonateVault(token);
  }

  function deployMockFlashLoanBorrower()
    internal
    returns (MockFlashLoanBorrower)
  {
    return new MockFlashLoanBorrower();
  }

  function deployMockStrategy(
    address token,
    MockDonateVault vault,
    address pool
  ) internal returns (MockStrategy) {
    return new MockStrategy(token, vault, pool);
  }

  function deployPLP() internal returns (PLP) {
    bytes memory _logicBytecode = abi.encodePacked(
      vm.getCode("./out/PLP.sol/PLP.json")
    );
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(uint256)")),
      [1 days]
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer);
    return PLP(payable(_proxy));
  }

  function deployP88() internal returns (P88) {
    return new P88(true);
  }

  function deployEsP88() internal returns (EsP88) {
    return new EsP88(true);
  }

  function deployDragonPoint() internal returns (DragonPoint) {
    bytes memory _logicBytecode = abi.encodePacked(
      vm.getCode("./out/DragonPoint.sol/DragonPoint.json")
    );
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize()"))
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer);
    return DragonPoint(payable(_proxy));
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

  function deployPoolDiamond(
    PoolConfigConstructorParams memory poolConfigConstructorParams
  ) internal returns (PoolOracle, address) {
    PoolOracle poolOracle = deployPoolOracle(3);
    PLP plp = deployPLP();

    // Deploy DimondCutFacet
    DiamondCutFacet diamondCutFacet = deployDiamondCutFacet();

    // Deploy Pool Diamond
    PoolDiamond poolDiamond = new PoolDiamond(
      address(diamondCutFacet),
      plp,
      poolOracle
    );

    // Config
    plp.setMinter(address(poolDiamond), true);

    deployDiamondLoupeFacet(DiamondCutFacet(address(poolDiamond)));
    deployFundingRateFacet(DiamondCutFacet(address(poolDiamond)));
    deployGetterFacet(DiamondCutFacet(address(poolDiamond)));
    deployLiquidityFacet(DiamondCutFacet(address(poolDiamond)));
    deployOwnershipFacet(DiamondCutFacet(address(poolDiamond)));
    deployPerpTradeFacet(DiamondCutFacet(address(poolDiamond)));
    deployAdminFacet(DiamondCutFacet(address(poolDiamond)));
    deployFarmFacet(DiamondCutFacet(address(poolDiamond)));
    deployAccessControlFacet(DiamondCutFacet(address(poolDiamond)));

    initializeDiamond(DiamondCutFacet(address(poolDiamond)));
    initializePoolConfig(
      DiamondCutFacet(address(poolDiamond)),
      poolConfigConstructorParams
    );

    return (poolOracle, address(poolDiamond));
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

  function deployPoolRouter(address wNative, address plpStaking)
    internal
    returns (PoolRouter)
  {
    return new PoolRouter(wNative, plpStaking);
  }

  function deployPLPStaking() internal returns (PLPStaking) {
    bytes memory _logicBytecode = abi.encodePacked(
      vm.getCode("./out/PLPStaking.sol/PLPStaking.json")
    );
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize()"))
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer);
    return PLPStaking(payable(_proxy));
  }

  function deployDragonStaking(address dragonPointToken)
    internal
    returns (DragonStaking)
  {
    bytes memory _logicBytecode = abi.encodePacked(
      vm.getCode("./out/DragonStaking.sol/DragonStaking.json")
    );
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(address)")),
      dragonPointToken
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer);
    return DragonStaking(payable(_proxy));
  }

  function deployFeedableRewarder(
    string memory name,
    address rewardToken,
    address staking
  ) internal returns (FeedableRewarder) {
    bytes memory _logicBytecode = abi.encodePacked(
      vm.getCode("./out/FeedableRewarder.sol/FeedableRewarder.json")
    );
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(string,address,address)")),
      name,
      rewardToken,
      staking
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer);
    return FeedableRewarder(payable(_proxy));
  }

  function deployAdHocMintRewarder(
    string memory name,
    address rewardToken,
    address staking
  ) internal returns (AdHocMintRewarder) {
    bytes memory _logicBytecode = abi.encodePacked(
      vm.getCode("./out/AdHocMintRewarder.sol/AdHocMintRewarder.json")
    );
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(string,address,address)")),
      name,
      rewardToken,
      staking
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer);
    return AdHocMintRewarder(payable(_proxy));
  }

  function deployWFeedableRewarder(
    string memory name,
    address rewardToken,
    address staking
  ) internal returns (WFeedableRewarder) {
    bytes memory _logicBytecode = abi.encodePacked(
      vm.getCode("./out/WFeedableRewarder.sol/WFeedableRewarder.json")
    );
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(string,address,address)")),
      name,
      rewardToken,
      staking
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer);
    return WFeedableRewarder(payable(_proxy));
  }

  function deployCompounder(
    address dp,
    address compoundPool,
    address[] memory tokens,
    bool[] memory isCompoundTokens
  ) internal returns (Compounder) {
    bytes memory _logicBytecode = abi.encodePacked(
      vm.getCode("./out/Compounder.sol/Compounder.json")
    );
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(address,address,address[],bool[])")),
      dp,
      compoundPool,
      tokens,
      isCompoundTokens
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer);
    return Compounder(payable(_proxy));
  }

  function deployVester(
    address esP88Address,
    address p88Address,
    address vestedEsp88DestinationAddress,
    address unusedEsp88DestinationAddress
  ) internal returns (Vester) {
    bytes memory _logicBytecode = abi.encodePacked(
      vm.getCode("./out/Vester.sol/Vester.json")
    );
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(address,address,address,address)")),
      esP88Address,
      p88Address,
      vestedEsp88DestinationAddress,
      unusedEsp88DestinationAddress
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer);
    return Vester(payable(_proxy));
  }

  function deployRewardDistributor(
    address rewardToken,
    address pool,
    address poolRouter,
    address plpStakingProtocolRevenueRewarder,
    address dragonStakingProtocolRevenueRewarder,
    uint256 devFundBps,
    uint256 plpStakingBps,
    address devFundAddress
  ) internal returns (RewardDistributor) {
    bytes memory _logicBytecode = abi.encodePacked(
      vm.getCode("./out/RewardDistributor.sol/RewardDistributor.json")
    );
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(
        keccak256(
          "initialize(address,address,address,address,address,uint256,uint256,address)"
        )
      ),
      rewardToken,
      pool,
      poolRouter,
      plpStakingProtocolRevenueRewarder,
      dragonStakingProtocolRevenueRewarder,
      devFundBps,
      plpStakingBps,
      devFundAddress
    );

    address _proxy = _setupUpgradeable(_logicBytecode, _initializer);
    return RewardDistributor(payable(_proxy));
  }

  function deployLockdropConfig(
    uint256 startLockTimestamp,
    address plpStaking,
    address plpToken,
    address p88Token,
    address gatewayAddress,
    address lockdropCompounder
  ) internal returns (LockdropConfig) {
    bytes memory _logicBytecode = abi.encodePacked(
      vm.getCode("./out/LockdropConfig.sol/LockdropConfig.json")
    );
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(
        keccak256("initialize(uint256,address,address,address,address,address)")
      ),
      startLockTimestamp,
      plpStaking,
      plpToken,
      p88Token,
      gatewayAddress,
      lockdropCompounder
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer);
    return LockdropConfig(payable(_proxy));
  }

  function deployLockdrop(
    address lockdropToken_,
    address pool_,
    address poolRouter_,
    address lockdropConfig_,
    address[] memory rewardTokens_,
    address nativeTokenAddress_
  ) internal returns (Lockdrop) {
    bytes memory _logicBytecode = abi.encodePacked(
      vm.getCode("./out/Lockdrop.sol/Lockdrop.json")
    );
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(
        keccak256(
          "initialize(address,address,address,address,address[],address)"
        )
      ),
      lockdropToken_,
      pool_,
      poolRouter_,
      lockdropConfig_,
      rewardTokens_,
      nativeTokenAddress_
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer);
    return Lockdrop(payable(_proxy));
  }

  function deployLockdropGateway(
    address plpToken,
    address plpStaking,
    address dragonStaking,
    address wnative
  ) internal returns (LockdropGateway) {
    bytes memory _logicBytecode = abi.encodePacked(
      vm.getCode("./out/LockdropGateway.sol/LockdropGateway.json")
    );
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(address,address,address,address)")),
      plpToken,
      plpStaking,
      dragonStaking,
      wnative
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer);
    return LockdropGateway(payable(_proxy));
  }

  function deployLockdropCompounder(
    address esp88Token,
    address dragonStaking,
    address revenueToken
  ) internal returns (LockdropCompounder) {
    bytes memory _logicBytecode = abi.encodePacked(
      vm.getCode("./out/LockdropCompounder.sol/LockdropCompounder.json")
    );
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(address,address,address)")),
      esp88Token,
      dragonStaking,
      revenueToken
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer);
    return LockdropCompounder(payable(_proxy));
  }

  function deployOrderbook(
    address _pool,
    address _poolOracle,
    address _weth,
    uint256 _minExecutionFee,
    uint256 _minPurchaseTokenAmountUsd
  ) internal returns (Orderbook) {
    bytes memory _logicBytecode = abi.encodePacked(
      vm.getCode("./out/Orderbook.sol/Orderbook.json")
    );
    bytes memory _initializer = abi.encodeWithSelector(
      bytes4(keccak256("initialize(address,address,address,uint256,uint256)")),
      _pool,
      _poolOracle,
      _weth,
      _minExecutionFee,
      _minPurchaseTokenAmountUsd
    );
    address _proxy = _setupUpgradeable(_logicBytecode, _initializer);
    return Orderbook(payable(_proxy));
  }

  function deployMerkleAirdrop() internal returns (MerkleAirdrop) {
    return new MerkleAirdrop();
  }

  function deployMerkleAirdropFactory()
    internal
    returns (MerkleAirdropFactory)
  {
    return new MerkleAirdropFactory();
  }

  function deployMerkleAirdropGateway()
    internal
    returns (MerkleAirdropGateway)
  {
    return new MerkleAirdropGateway();
  }
}
