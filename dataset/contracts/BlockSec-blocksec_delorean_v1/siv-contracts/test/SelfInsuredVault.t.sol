// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

import { BaseTest } from "./BaseTest.sol";
import { FakeYieldSource } from "./helpers/FakeYieldSource.sol";
import { FakeYieldOracle } from "./helpers/FakeYieldOracle.sol";
import { FakeToken } from "./helpers/FakeToken.sol";

import { IWrappedETH } from "../src/interfaces/IWrappedETH.sol";
import { IRewardTracker } from "../src/interfaces/gmx/IRewardTracker.sol";
import { IInsuranceProvider } from "../src/interfaces/IInsuranceProvider.sol";
import { SelfInsuredVault } from "../src/vaults/SelfInsuredVault.sol";
import { Y2KEarthquakeV1InsuranceProvider } from "../src/providers/Y2KEarthquakeV1InsuranceProvider.sol";

// Y2K imports
import { Vault } from "y2k-earthquake/src/legacy_v1/Vault.sol";
import { VaultFactory, TimeLock} from "y2k-earthquake/src/legacy_v1/VaultFactory.sol";
import { Controller } from "y2k-earthquake/src/legacy_v1/Controller.sol"; 
import { ControllerHelper } from "y2k-earthquake/test/legacy_v1/ControllerHelper.sol";
import { FakeOracle } from "y2k-earthquake/test/oracles/FakeOracle.sol";

// Delorean imports
import { UniswapV3LiquidityPool } from "dlx/src/liquidity/UniswapV3LiquidityPool.sol";
import { IUniswapV3Pool } from "dlx/src/interfaces/uniswap/IUniswapV3Pool.sol";
import { INonfungiblePositionManager } from "dlx/src/interfaces/uniswap/INonfungiblePositionManager.sol";
import { IUniswapV3Factory } from "dlx/src/interfaces/uniswap/IUniswapV3Factory.sol";
import { NPVToken } from "dlx/src/tokens/NPVToken.sol";
import { YieldSlice } from "dlx/src/core/YieldSlice.sol";
import { NPVSwap } from  "dlx/src/core/NPVSwap.sol";
import { Discounter } from "dlx/src/data/Discounter.sol";
import { YieldData } from "dlx/src/data/YieldData.sol";

contract SelfInsuredVaultTest is BaseTest, ControllerHelper {

    // From https://docs.uniswap.org/contracts/v3/reference/deployments
    address public arbitrumUniswapV3Factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address public arbitrumNonfungiblePositionManager = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address public arbitrumSwapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public arbitrumQuoterV2 = 0x61fFE014bA17989E743c5F6cB21bF9697530B21e;
    address public arbitrumWeth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    NPVToken public npvToken;
    NPVSwap public npvSwap;
    YieldSlice public slice;
    YieldData public dataDebt;
    YieldData public dataCredit;
    Discounter public discounter;

    UniswapV3LiquidityPool public pool;
    IUniswapV3Pool public uniswapV3Pool;
    INonfungiblePositionManager public manager;

    address glpWallet = 0x3aaF2aCA2a0A6b6ec227Bbc2bF5cEE86c2dC599d;

    IRewardTracker public gmxRewardsTracker = IRewardTracker(0x4e971a87900b931fF39d1Aad67697F49835400b6);

    IERC20 gt;
    IERC20 yt;
    FakeYieldSource source;
    SelfInsuredVault vault;
    Y2KEarthquakeV1InsuranceProvider provider;

    function epochPayout(SelfInsuredVault vault_, address provider_, uint256 index) internal view returns (uint256) {
        ( , , uint256 payout, ) = vault_.providerEpochs(provider_, index);
        return payout;
    }

    function setUpVault() public {
        uint256 wethAmount = 1000000e18;
        vm.deal(address(this), wethAmount);
        IWrappedETH(WETH).deposit{value: wethAmount}();
        source = new FakeYieldSource(200, WETH);
        IERC20(WETH).transfer(address(source), wethAmount);

        gt = source.generatorToken();
        yt = source.yieldToken();

        vault = new SelfInsuredVault("Self Insured YS:G Vault",
                                     "siYS:G",
                                     address(source.yieldToken()),
                                     address(source),
                                     address(0));
        source.setOwner(address(vault));
    }

    function setUpY2K() public {
        // Set up Y2K insurance vault
        vm.startPrank(ADMIN);
        vaultFactory.createNewMarket(FEE, TOKEN_FRAX, DEPEG_AAA, beginEpoch, endEpoch, ORACLE_FRAX, "y2kFRAX_99*");

        hedge = vaultFactory.getVaults(1)[0];
        risk = vaultFactory.getVaults(1)[1];

        vHedge = Vault(hedge);
        vRisk = Vault(risk);
        vm.stopPrank();

        // Set up the insurance provider
        provider = new Y2KEarthquakeV1InsuranceProvider(address(vHedge), address(vault));

        // Set the insurance provider at 10% of expected yield
        vault.addInsuranceProvider(IInsuranceProvider(provider), 10_00);
    }

    function testYieldAccounting() public {
        setUpVault();

        uint256 before;
        address user0 = createTestUser(0);
        source.mintGenerator(user0, 10e18);

        vm.startPrank(user0);

        // Set balance to 0 WETH for user0
        IERC20(WETH).transfer(address(source), IERC20(WETH).balanceOf(user0));

        IERC20(gt).approve(address(vault), 2e18);
        assertEq(vault.previewDeposit(2e18), 2e18);
        vault.deposit(2e18, user0);
        assertEq(IERC20(gt).balanceOf(user0), 8e18);
        assertEq(IERC20(gt).balanceOf(address(vault)), 0);
        assertEq(IERC20(gt).balanceOf(address(source)), 2e18);
        assertEq(vault.balanceOf(user0), 2e18);
        vm.stopPrank();

        assertEq(vault.cumulativeYield(), 0);

        // Verify yield accounting with one user
        vm.roll(block.number + 1);
        assertEq(vault.cumulativeYield(), 400e18);
        assertEq(vault.calculatePendingYield(user0), 400e18);
        assertEq(IERC20(yt).balanceOf(address(vault)), 0);
        assertEq(IERC20(yt).balanceOf(user0), 0);

        vm.prank(user0);
        vault.claimRewards();

        assertEq(IERC20(yt).balanceOf(address(vault)), 0);
        assertEq(IERC20(yt).balanceOf(user0), 400e18);

        vm.prank(user0);
        vault.claimRewards();
        assertEq(IERC20(yt).balanceOf(address(vault)), 0);
        assertEq(IERC20(yt).balanceOf(user0), 400e18);

        // Advance multiple blocks
        vm.roll(block.number + 2);
        assertEq(vault.cumulativeYield(), 1200e18);
        assertEq(vault.calculatePendingYield(user0), 800e18);

        vm.roll(block.number + 3);
        assertEq(vault.cumulativeYield(), 2400e18);
        assertEq(vault.calculatePendingYield(user0), 2000e18);

        assertEq(IERC20(yt).balanceOf(address(vault)), 0);
        assertEq(IERC20(yt).balanceOf(user0), 400e18);

        vm.prank(user0);
        vault.claimRewards();
        assertEq(IERC20(yt).balanceOf(address(vault)), 0);
        assertEq(IERC20(yt).balanceOf(user0), 2400e18);

        // Add incentive rewards
        FakeToken it = new FakeToken("Incentives", "INC", 100e18);
        vault.addRewardToken(address(it));
        it.transfer(address(vault), 1e18);
        vm.prank(user0);
        vault.claimRewards();
        assertEq(it.balanceOf(user0), 1e18);

        // Advance multiple blocks, change yield rate, advance more blocks
        vm.roll(block.number + 2);
        assertEq(vault.cumulativeYield(), 3200e18);
        assertEq(vault.calculatePendingYield(user0), 800e18);

        before = source.amountPending();
        source.setYieldPerBlock(100);
        assertEq(source.amountPending(), before);

        vm.roll(block.number + 1);
        assertEq(vault.cumulativeYield(), 3400e18);
        assertEq(vault.calculatePendingYield(user0), 1000e18);

        vm.roll(block.number + 2);
        assertEq(vault.cumulativeYield(), 3800e18);
        assertEq(vault.calculatePendingYield(user0), 1400e18);

        vm.prank(user0);
        vault.claimRewards();
        assertEq(vault.cumulativeYield(), 3800e18);
        assertEq(vault.calculatePendingYield(user0), 0);
        assertEq(IERC20(yt).balanceOf(address(vault)), 0);
        assertEq(IERC20(yt).balanceOf(user0), 3800e18);

        // Add a second user
        address user1 = createTestUser(1);

        source.mintGenerator(user1, 20e18);
        assertEq(vault.calculatePendingYield(user0), 0);
        assertEq(vault.calculatePendingYield(user1), 0);

        vm.roll(block.number + 1);
        assertEq(vault.calculatePendingYield(user0), 200e18);
        assertEq(vault.calculatePendingYield(user1), 0);

        // Second user deposits
        vm.startPrank(user1);

        // Set balance to 0 WETH for user1
        IERC20(WETH).transfer(address(source), IERC20(WETH).balanceOf(user1));

        IERC20(gt).approve(address(vault), 4e18);
        assertEq(vault.previewDeposit(4e18), 4e18);

        before = vault.cumulativeYield();

        vault.deposit(4e18, user1);
        assertEq(vault.cumulativeYield(), before);
        assertEq(IERC20(gt).balanceOf(user0), 8e18);
        assertEq(IERC20(gt).balanceOf(user1), 16e18);
        assertEq(IERC20(gt).balanceOf(address(vault)), 0);
        assertEq(vault.balanceOf(user0), 2e18);
        assertEq(vault.balanceOf(user1), 4e18);
        assertEq(vault.totalAssets(), 6e18);
        vm.stopPrank();

        vm.roll(block.number + 1);
        assertEq(vault.calculatePendingYield(user0), 400e18);
        assertEq(vault.calculatePendingYield(user1), 400e18);

        vm.roll(block.number + 1);
        assertEq(vault.calculatePendingYield(user0), 600e18);
        assertEq(vault.calculatePendingYield(user1), 800e18);

        vm.roll(block.number + 2);
        assertEq(vault.calculatePendingYield(user0), 1000e18);
        assertEq(vault.calculatePendingYield(user1), 1600e18);

        vm.prank(user0);
        vault.claimRewards();
        assertEq(vault.calculatePendingYield(user0), 0);
        assertEq(yt.balanceOf(user0), 4800e18);

        vm.prank(user1);
        vault.claimRewards();
        assertEq(vault.calculatePendingYield(user1), 0);
        assertEq(yt.balanceOf(user1), 1600e18);
        assertEq(it.balanceOf(user0), 1e18);
        assertEq(it.balanceOf(user1), 0);

        // Third user deposits, advance some blocks, change yield rate, users claim on different blocks
        address user2 = createTestUser(2);
        source.mintGenerator(user2, 20e18);

        // Transfer 14e18 incentives, to be split 2/4/8 between user0/1/2
        it.transfer(address(vault), 14e18);

        vm.startPrank(user2);

        // Set balance to 0 WETH for user2
        IERC20(WETH).transfer(address(source), IERC20(WETH).balanceOf(user2));

        gt.approve(address(vault), 8e18);
        assertEq(vault.previewDeposit(8e18), 8e18);
        before = vault.cumulativeYield();

        vault.deposit(8e18, user2);

        assertEq(vault.cumulativeYield(), before);
        assertEq(gt.balanceOf(user0), 8e18);
        assertEq(gt.balanceOf(user1), 16e18);
        assertEq(gt.balanceOf(user2), 12e18);
        assertEq(gt.balanceOf(address(source)), 14e18);
        assertEq(vault.balanceOf(user0), 2e18);
        assertEq(vault.balanceOf(user1), 4e18);
        assertEq(vault.balanceOf(user2), 8e18);
        assertEq(vault.totalAssets(), 14e18);
        vm.stopPrank();

        vm.roll(block.number + 1);

        assertEq(vault._calculatePendingYield(user0, address(it)), 2e18);
        assertEq(vault._calculatePendingYield(user1, address(it)), 4e18);
        assertEq(vault._calculatePendingYield(user2, address(it)), 8e18);

        assertEq(vault.calculatePendingYield(user0), 200e18);
        assertEq(vault.calculatePendingYield(user1), 400e18);
        assertEq(vault.calculatePendingYield(user2), 800e18);

        vm.roll(block.number + 1);
        assertEq(vault.calculatePendingYield(user0), 400e18);
        assertEq(vault.calculatePendingYield(user1), 800e18);
        assertEq(vault.calculatePendingYield(user2), 1600e18);

        source.setYieldPerBlock(300);

        vm.roll(block.number + 1);
        assertEq(vault.calculatePendingYield(user0), 1000e18);
        assertEq(vault.calculatePendingYield(user1), 2000e18);
        assertEq(vault.calculatePendingYield(user2), 4000e18);

        vm.prank(user1);
        vault.claimRewards();

        assertEq(vault.calculatePendingYield(user0), 1000e18);
        assertEq(vault.calculatePendingYield(user1), 0);
        assertEq(vault.calculatePendingYield(user2), 4000e18);
        assertEq(yt.balanceOf(user0), 4800e18);
        assertEq(yt.balanceOf(user1), 3600e18);
        assertEq(yt.balanceOf(user2), 0);

        assertEq(it.balanceOf(user1), 4e18);

        vm.roll(block.number + 1);
        assertEq(vault.calculatePendingYield(user0), 1600e18);
        assertEq(vault.calculatePendingYield(user1), 1200e18);
        assertEq(vault.calculatePendingYield(user2), 6400e18);

        vm.prank(user2);
        vault.claimRewards();
        assertEq(vault.calculatePendingYield(user0), 1600e18);
        assertEq(vault.calculatePendingYield(user1), 1200e18);
        assertEq(vault.calculatePendingYield(user2), 0);
        assertEq(yt.balanceOf(user0), 4800e18);
        assertEq(yt.balanceOf(user1), 3600e18);
        assertEq(yt.balanceOf(user2), 6400e18);

        vm.prank(user0);
        vault.claimRewards();
        vm.prank(user1);
        vault.claimRewards();
        assertEq(vault.calculatePendingYield(user0), 0);
        assertEq(vault.calculatePendingYield(user1), 0);
        assertEq(vault.calculatePendingYield(user2), 0);
        assertEq(yt.balanceOf(user0), 6400e18);
        assertEq(yt.balanceOf(user1), 4800e18);
        assertEq(yt.balanceOf(user2), 6400e18);

        assertEq(it.balanceOf(user0), 3e18);
        assertEq(it.balanceOf(user1), 4e18);
        assertEq(it.balanceOf(user2), 8e18);
    }

    function testDepegYieldAccounting() public {
        depositDepeg();
        setUpVault();
        setUpY2K();

        // Move into the first epoch
        vm.warp(beginEpoch + 10 days);

        vault.setAdmin(ADMIN);

        // Alice deposits into self insured vault
        source.mintGenerator(ALICE, 10e18);

        vm.startPrank(ALICE);
        gt.approve(address(vault), 2e18);
        assertEq(vault.previewDeposit(2e18), 2e18);
        vault.deposit(2e18, ALICE);

        {
            (uint256 epochId0, uint256 totalShares0, , ) = vault.providerEpochs(address(provider), 0);
            assertEq(totalShares0, 0);
            ( , uint256 totalShares1, , ) = vault.providerEpochs(address(provider), 1);
            assertEq(totalShares1, 2e18);

            (uint256 startEpochId,
             uint256 shares,
             uint256 endEpochId,
             uint256 nextShares,
             uint256 accumulatedPayouts,
             uint256 claimedPayouts) = vault.userEpochTrackers(ALICE);
            assertEq(startEpochId, 0);
            assertEq(shares, 0);
            assertEq(endEpochId, epochId0);
            assertEq(nextShares, 2e18);
            assertEq(accumulatedPayouts, 0);
            assertEq(claimedPayouts, 0);
        }

        gt.approve(address(vault), 1e18);
        vault.deposit(1e18, ALICE);
        {
            (uint256 epochId0, uint256 totalShares0, , ) = vault.providerEpochs(address(provider), 0);
            assertEq(totalShares0, 0);
            (, uint256 totalShares1, , ) = vault.providerEpochs(address(provider), 1);
            assertEq(totalShares1, 3e18);

            (uint256 startEpochId,
             uint256 shares,
             uint256 endEpochId,
             uint256 nextShares,
             uint256 accumulatedPayouts,
             uint256 claimedPayouts) = vault.userEpochTrackers(ALICE);
            assertEq(startEpochId, 0);
            assertEq(shares, 0);
            assertEq(endEpochId, epochId0);
            assertEq(nextShares, 3e18);
            assertEq(accumulatedPayouts, 0);
            assertEq(claimedPayouts, 0);
        }

        vm.stopPrank();

        // End the next epoch
        vm.startPrank(vHedge.controller());
        vHedge.endEpoch(provider.currentEpoch());
        vm.stopPrank();

        // Create two more epochs
        vm.startPrank(vHedge.factory());
        vHedge.createAssets(endEpoch, endEpoch + 1 days, 5);
        vm.stopPrank();

        vm.startPrank(vHedge.factory());
        vHedge.createAssets(endEpoch + 1 days, endEpoch + 2 days, 5);
        vm.stopPrank();

        // Move into the first epoch, with one more created epoch available after it
        vm.warp(endEpoch + 10 minutes);
        vm.startPrank(vHedge.controller());
        vm.stopPrank();

        // Alice deposits more shares
        vm.startPrank(ALICE);
        gt.approve(address(vault), 3e18);
        vault.deposit(3e18, ALICE);
        vm.stopPrank();

        {
            ( , uint256 totalShares0, , ) = vault.providerEpochs(address(provider), 0);
            assertEq(totalShares0, 0);
            (uint256 epochId1, uint256 totalShares1, , ) = vault.providerEpochs(address(provider), 1);
            assertEq(totalShares1, 3e18);
            (uint256 epochId2, uint256 totalShares2, , ) = vault.providerEpochs(address(provider), 2);
            assertEq(epochId2, 0);
            assertEq(totalShares2, 6e18);

            (uint256 startEpochId,
             uint256 shares,
             uint256 endEpochId,
             uint256 nextShares,
             uint256 accumulatedPayouts,
             uint256 claimedPayouts) = vault.userEpochTrackers(ALICE);

            assertEq(startEpochId, epochId1);
            assertEq(endEpochId, epochId1);
            assertEq(shares, 3e18);
            assertEq(nextShares, 6e18);
            assertEq(accumulatedPayouts, 0);
            assertEq(claimedPayouts, 0);
        }
    }

    function testPurchaseWithDLXFutureYield() public {
        // Send lots of WETH to vault source
        uint256 wethAmount = 1000000e18;
        vm.deal(address(this), wethAmount);
        IWrappedETH(WETH).deposit{value: wethAmount}();
        source = new FakeYieldSource(200, WETH);
        IERC20(WETH).transfer(address(source), wethAmount);
        gt = IERC20(source.generatorToken());
        yt = IERC20(source.yieldToken());
        source.mintBoth(ALICE, 10e18);

        // -- Set up Delorean market --/
        dataDebt = new YieldData(20);
        dataCredit = new YieldData(20);
        discounter = new Discounter(1e13, 500 * 30, 360, 18, 30 days);

        FakeYieldSource dlxSource = source;
        slice = new YieldSlice("npvETH-FAKE",
                               address(dlxSource),
                               address(dataDebt),
                               address(dataCredit),
                               address(discounter),
                               1e18);
        slice.setDebtFee(10_0);
        slice.setCreditFee(10_0);

        dlxSource.setOwner(address(slice));
        dataDebt.setWriter(address(slice));
        dataCredit.setWriter(address(slice));

        dlxSource.mintBoth(ALICE, 1000e18);

        npvToken = slice.npvToken();

        // Uniswap V3 setup for Delorean
        manager = INonfungiblePositionManager(arbitrumNonfungiblePositionManager);
        (address token0, address token1) = address(npvToken) < address(yt)
            ? (address(npvToken), address(yt))
            : (address(yt), address(npvToken));
        uniswapV3Pool = IUniswapV3Pool(IUniswapV3Factory(arbitrumUniswapV3Factory).getPool(token0, token1, 3000));
        if (address(uniswapV3Pool) == address(0)) {
            uniswapV3Pool = IUniswapV3Pool(IUniswapV3Factory(arbitrumUniswapV3Factory).createPool(token0, token1, 3000));
            IUniswapV3Pool(uniswapV3Pool).initialize(79228162514264337593543950336);
        }
        pool = new UniswapV3LiquidityPool(address(uniswapV3Pool), arbitrumSwapRouter, arbitrumQuoterV2);
        npvSwap = new NPVSwap(address(slice), address(pool));

        // Add liquidity
        vm.startPrank(ALICE);
        gt.approve(address(npvSwap), 1000e18);
        npvSwap.lockForNPV(ALICE, ALICE, 1000e18, 10e18, new bytes(0));
        uint256 token0Amount = 1e18;
        uint256 token1Amount = 1e18;
        dlxSource.mintGenerator(ALICE, 1e18);
        dlxSource.mintYield(ALICE, 1e18);
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: uniswapV3Pool.token0(),
            token1: uniswapV3Pool.token1(),
            fee: 3000,
            tickLower: -180,
            tickUpper: 180,
            amount0Desired: token0Amount,
            amount1Desired: token1Amount,
            amount0Min: 0,
            amount1Min: 0,
            recipient: ALICE,
            deadline: block.timestamp + 1 });
        assertEq(uniswapV3Pool.liquidity(), 0);
        IERC20(params.token0).approve(address(manager), token0Amount);
        IERC20(params.token1).approve(address(manager), token1Amount);
        manager.mint(params);
        assertTrue(uniswapV3Pool.liquidity() > 0);
        vm.stopPrank();
        // -- Delorean setup complete -- //

        vm.startPrank(ADMIN);
        fakeOracle = new FakeOracle(ORACLE_FRAX, STRIKE_PRICE_FAKE_ORACLE);
        vaultFactory.createNewMarket(FEE, TOKEN_FRAX, DEPEG_AAA, beginEpoch, endEpoch, address(fakeOracle), "y2kFRAX_99*");
        vm.stopPrank();
        hedge = vaultFactory.getVaults(1)[0];
        risk = vaultFactory.getVaults(1)[1];
        vHedge = Vault(hedge);
        vRisk = Vault(risk);

        // Create another 2 epochs
        vm.startPrank(vHedge.factory());
        vHedge.createAssets(endEpoch,          endEpoch + 1 days, 5);
        vHedge.createAssets(endEpoch + 1 days, endEpoch + 2 days, 5);
        vm.stopPrank();

        vm.startPrank(vRisk.factory());
        vRisk.createAssets(endEpoch,          endEpoch + 1 days, 5);
        vRisk.createAssets(endEpoch + 1 days, endEpoch + 2 days, 5);
        vm.stopPrank();

        vm.startPrank(ADMIN);
        vault = new SelfInsuredVault("Self Insured YS:G Vault",
                                     "siYS:G",
                                     address(source.yieldToken()),
                                     address(source),
                                     address(npvSwap));
        vm.stopPrank();


        // Set up the insurance provider
        provider = new Y2KEarthquakeV1InsuranceProvider(address(vHedge), address(vault));
        provider.transferOwnership(address(vault));

        vm.warp(beginEpoch + 1);

        // Bob buys the risk
        vm.startPrank(BOB);
        vm.deal(BOB, 200 ether);
        IWrappedETH(WETH).deposit{value: 200 ether}();
        IERC20(WETH).approve(address(vRisk), 200e18);
        vRisk.deposit(endEpoch + 1 days, 200e18, BOB);
        vm.stopPrank();

        // Set the insurance provider at 10% of expected yield
        vm.startPrank(ADMIN);
        vault.addInsuranceProvider(IInsuranceProvider(provider), 0);
        vault.setWeight(0, 10_00);
        vm.stopPrank();

        // Deposit into the vault
        vm.startPrank(ALICE);
        gt.approve(address(vault), 2e18);
        vault.deposit(2e18, ALICE);
        vm.stopPrank();

        vm.prank(ADMIN);

        vault.purchaseInsuranceForNextEpoch(95_00, 484807680000);

        // Trigger a depeg
        vm.warp(endEpoch + 1 minutes);
        assertEq(epochPayout(vault, address(provider), 0), 0);
        controller.triggerDepeg(SINGLE_MARKET_INDEX, endEpoch + 1 days);

        vm.startPrank(address(controller));
        vHedge.endEpoch(endEpoch);
        vHedge.endEpoch(endEpoch + 1 days);
        vRisk.endEpoch(endEpoch);
        vRisk.endEpoch(endEpoch + 1 days);
        vm.stopPrank();

        vault.claimVaultPayouts();

        assertTrue(IERC20(WETH).balanceOf(address(vault)) > 199e18);
        assertTrue(IERC20(WETH).balanceOf(address(vault)) >= epochPayout(vault, address(provider), 1));
        assertEq(IERC20(WETH).balanceOf(address(vault)), 199000000042807782417);

        assertEq(epochPayout(vault, address(provider), 1), 199000000000023768896);

        // Redundant claim should not change it
        vault.claimVaultPayouts();
        assertEq(epochPayout(vault, address(provider), 1), 199000000000023768896);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 199000000042807782417);

        // Alice claims rewards
        {
            uint256 previewPayouts = vault.previewClaimPayouts(ALICE);
            assertEq(previewPayouts, 199000000000023768896);
            assertEq(previewPayouts, epochPayout(vault, address(provider), 1));
        }

        {
            uint256 before = IERC20(WETH).balanceOf(ALICE);
            vm.prank(ALICE);
            vault.claimPayouts();
            assertEq(IERC20(WETH).balanceOf(ALICE) - before, 199000000000023768896);
        }

        // Partial withdraw from the vault
        {
            uint256 before = IERC20(gt).balanceOf(ALICE);
            vm.prank(ALICE);
            vault.withdraw(15e17, ALICE, ALICE);
            uint256 delta = IERC20(gt).balanceOf(ALICE) - before;
            assertEq(delta, 15e17);
            assertEq(vault.balanceOf(ALICE), 5e17);
        }

        // Withdraw the rest
        {
            uint256 before = IERC20(gt).balanceOf(ALICE);
            vm.prank(ALICE);
            vault.withdraw(5e17, ALICE, ALICE);
            uint256 delta = IERC20(gt).balanceOf(ALICE) - before;
            assertEq(delta, 5e17);
            assertEq(vault.balanceOf(ALICE), 0);
        }
    }

    function testDoubleAddRewardToken() public {
        setUpVault();

        FakeToken it = new FakeToken("Incentives", "INC", 100e18);
        vault.addRewardToken(address(it));

        vm.expectRevert("SIV: duplicate reward token");
        vault.addRewardToken(address(it));
    }

    function testDoubleAddProvider() public {
        setUpVault();
        setUpY2K();

        vm.expectRevert("SIV: duplicate provider");
        vault.addInsuranceProvider(IInsuranceProvider(provider), 0);
    }
}
