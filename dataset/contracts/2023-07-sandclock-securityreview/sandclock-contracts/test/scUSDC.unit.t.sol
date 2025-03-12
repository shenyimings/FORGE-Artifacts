// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import "forge-std/console2.sol";
import "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {MockERC4626} from "solmate/test/utils/mocks/MockERC4626.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {IPool} from "aave-v3/interfaces/IPool.sol";
import {IAToken} from "aave-v3/interfaces/IAToken.sol";
import {IPoolDataProvider} from "aave-v3/interfaces/IPoolDataProvider.sol";

import {scUSDC} from "../src/steth/scUSDC.sol";
import {ISwapRouter} from "../src/interfaces/uniswap/ISwapRouter.sol";
import {AggregatorV3Interface} from "../src/interfaces/chainlink/AggregatorV3Interface.sol";
import {IVault} from "../src/interfaces/balancer/IVault.sol";

import {MockWETH} from "./mocks/MockWETH.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {MockAavePool} from "./mocks/aave-v3/MockAavePool.sol";
import {MockAavePoolDataProvider} from "./mocks/aave-v3/MockAavePoolDataProvider.sol";
import {MockAUsdc} from "./mocks/aave-v3/MockAUsdc.sol";
import {MockVarDebtWETH} from "./mocks/aave-v3/MockVarDebtWETH.sol";
import {MockChainlinkPriceFeed} from "./mocks/chainlink/MockChainlinkPriceFeed.sol";
import {MockBalancerVault} from "./mocks/balancer/MockBalancerVault.sol";
import {MockSwapRouter} from "./mocks/uniswap/MockSwapRouter.sol";

contract scUSDCUnitTest is Test {
    using FixedPointMathLib for uint256;

    address constant keeper = address(0x05);
    address constant alice = address(0x06);

    scUSDC vault;
    ERC4626 wethVault;

    MockUSDC usdc;
    MockWETH weth;

    IPoolDataProvider aavePoolDataProvider;
    MockAavePool aavePool;
    MockAUsdc aaveAUsdc;
    MockVarDebtWETH aaveVarDWeth;

    MockChainlinkPriceFeed usdcToEthPriceFeed;
    MockBalancerVault balancerVault;
    MockSwapRouter uniswapRouter;

    function setUp() public {
        usdc = new MockUSDC();
        weth = new MockWETH();

        wethVault = new MockERC4626(weth, "Mock WETH Vault", "mWETH");

        aavePoolDataProvider = new MockAavePoolDataProvider(address(usdc), address(weth));
        usdcToEthPriceFeed = new MockChainlinkPriceFeed(address(usdc), address(weth), 0.001e18);
        aavePool = new MockAavePool();
        aavePool.setUsdcWethPriceFeed(usdcToEthPriceFeed, usdc, weth);
        aaveAUsdc = new MockAUsdc(aavePool, usdc);
        aaveVarDWeth = new MockVarDebtWETH(aavePool, weth);

        balancerVault = new MockBalancerVault(weth);
        uniswapRouter = new MockSwapRouter();

        scUSDC.ConstructorParams memory scUsdcParams = scUSDC.ConstructorParams({
            admin: address(this),
            keeper: keeper,
            scWETH: wethVault,
            usdc: usdc,
            weth: WETH(payable(weth)),
            aavePool: aavePool,
            aavePoolDataProvider: aavePoolDataProvider,
            aaveAUsdc: IAToken(address(aaveAUsdc)),
            aaveVarDWeth: ERC20(address(aaveVarDWeth)),
            uniswapSwapRouter: uniswapRouter,
            chainlinkUsdcToEthPriceFeed: usdcToEthPriceFeed,
            balancerVault: balancerVault
        });

        vault = new scUSDC(scUsdcParams);

        weth.mint(address(aavePool), 100e18);
    }

    function test_rebalance() public {
        uint256 amount = 10000e6;
        deal(address(usdc), address(alice), amount);

        vm.startPrank(alice);
        usdc.approve(address(vault), type(uint256).max);
        vault.deposit(amount, alice);
        vm.stopPrank();

        vm.prank(keeper);
        vault.rebalance();

        assertApproxEqAbs(vault.getCollateral(), amount.mulWadDown(0.99e18), 1, "collateral");
        assertEq(vault.getDebt(), 6.435e18, "debt");
        assertEq(vault.getUsdcBalance(), amount.mulWadUp(vault.floatPercentage()), "float");
        assertApproxEqAbs(vault.totalAssets(), amount, 1, "total assets");
    }

    function test_withdraw() public {
        uint256 depositAmount = 10000e6;
        deal(address(usdc), address(alice), depositAmount);

        vm.startPrank(alice);
        usdc.approve(address(vault), type(uint256).max);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        vm.prank(keeper);
        vault.rebalance();

        vm.startPrank(alice);
        uint256 withdrawAmount = 1000e6;
        vault.withdraw(1000e6, alice, alice);
        vm.stopPrank();

        assertEq(usdc.balanceOf(alice), withdrawAmount, "alice usdc balance");
        assertApproxEqAbs(vault.getCollateral(), (depositAmount - withdrawAmount).mulWadDown(0.99e18), 1, "collateral"); // - float
        assertEq(vault.getDebt(), uint256(6.435e18).mulWadDown(0.9e18), "debt");
        assertEq(vault.getUsdcBalance(), (depositAmount - withdrawAmount).mulWadUp(vault.floatPercentage()), "float");
        assertApproxEqAbs(vault.totalAssets(), (depositAmount - withdrawAmount), 1, "total assets");
    }

    function test_getCollateral_AccountsForInterestOnSuppliedUsdc() public {
        uint256 amount = 10000e6;
        deal(address(usdc), address(alice), amount);

        vm.startPrank(alice);
        usdc.approve(address(vault), type(uint256).max);
        vault.deposit(amount, alice);
        vm.stopPrank();

        vm.prank(keeper);
        vault.rebalance();

        usdc.mint(address(this), 1_000_000e6);
        usdc.approve(address(aavePool), type(uint256).max);
        uint256 collateralBefore = vault.getCollateral();
        uint256 interest = 0.05e18;
        aavePool.addInterestOnSupply(address(vault), address(usdc), collateralBefore.mulWadDown(interest));

        assertEq(vault.getCollateral(), collateralBefore.mulWadDown(1e18 + interest), "collateral with interest");
    }

    function test_getDebt_AccountsForInterestOnBorrowedWeth() public {
        uint256 amount = 10000e6;
        deal(address(usdc), address(alice), amount);

        vm.startPrank(alice);
        usdc.approve(address(vault), type(uint256).max);
        vault.deposit(amount, alice);
        vm.stopPrank();

        vm.prank(keeper);
        vault.rebalance();

        uint256 debtBefore = vault.getDebt();
        uint256 interest = 0.05e18;
        aavePool.addInterestOnDebt(address(vault), address(weth), debtBefore.mulWadDown(interest));

        assertEq(vault.getDebt(), debtBefore.mulWadDown(1e18 + interest), "debt with interest");
    }

    function test_getLtv() public {
        uint256 amount = 10000e6;
        deal(address(usdc), alice, amount);

        vm.startPrank(alice);
        usdc.approve(address(vault), type(uint256).max);
        vault.deposit(amount, alice);
        vm.stopPrank();

        vm.prank(keeper);
        vault.rebalance();

        aavePool.setUsdcWethPriceFeed(usdcToEthPriceFeed, usdc, weth);

        assertEq(vault.getLtv(), vault.targetLtv(), "ltv");
    }

    function test_getUsdcFromWeth_precisionLoss() public {
        uint256 wethAmount = 1e13;
        uint256 wethAmountPlusSome = wethAmount + 1e10; // a bit more
        usdcToEthPriceFeed.setLatestAnswer(512640446503388);

        assertTrue(vault.getUsdcFromWeth(wethAmount) < vault.getUsdcFromWeth(wethAmountPlusSome), "precision loss");
    }
}
