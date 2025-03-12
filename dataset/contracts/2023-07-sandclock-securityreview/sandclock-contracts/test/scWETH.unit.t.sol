// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import "forge-std/console2.sol";
import "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {IPool} from "aave-v3/interfaces/IPool.sol";
import {IAToken} from "aave-v3/interfaces/IAToken.sol";

import {Constants as C} from "../src/lib/Constants.sol";
import {scWETH} from "../src/steth/scWETH.sol";
import {AggregatorV3Interface} from "../src/interfaces/chainlink/AggregatorV3Interface.sol";
import {IVault} from "../src/interfaces/balancer/IVault.sol";
import {ICurvePool} from "../src/interfaces/curve/ICurvePool.sol";
import {ILido} from "../src/interfaces/lido/ILido.sol";
import {IwstETH} from "../src/interfaces/lido/IwstETH.sol";

import {MockWETH} from "./mocks/MockWETH.sol";
import {MockAavePool} from "./mocks/aave-v3/MockAavePool.sol";
import {MockVarDebtWETH} from "./mocks/aave-v3/MockVarDebtWETH.sol";
import {MockAwstETH} from "./mocks/aave-v3/MockAwstETH.sol";
import {MockStETH} from "./mocks/lido/MockStETH.sol";
import {MockWstETH} from "./mocks/lido/MockWstETH.sol";
import {MockChainlinkPriceFeed} from "./mocks/chainlink/MockChainlinkPriceFeed.sol";
import {MockCurvePool} from "./mocks/curve/MockCurvePool.sol";
import {MockBalancerVault} from "./mocks/balancer/MockBalancerVault.sol";

contract scWETHUnitTest is Test {
    using FixedPointMathLib for uint256;

    address constant keeper = address(0x05);
    address constant alice = address(0x06);

    scWETH vault;

    MockWETH weth;

    MockAavePool aavePool;
    MockVarDebtWETH aaveVarDWeth;
    MockStETH stEth;
    MockWstETH wstEth;
    MockAwstETH aaveAWstEth;

    MockCurvePool curveEthStEthPool;
    MockChainlinkPriceFeed stEthToEthPriceFeed;
    MockBalancerVault balancerVault;

    function setUp() public {
        weth = new MockWETH();
        stEth = new MockStETH();
        wstEth = new MockWstETH(stEth);
        stEthToEthPriceFeed = new MockChainlinkPriceFeed(address(stEth), address(weth), 1e18);
        aavePool = new MockAavePool();
        aavePool.setStEthToEthPriceFeed(stEthToEthPriceFeed, wstEth, weth);
        aaveVarDWeth = new MockVarDebtWETH(aavePool, weth);
        aaveAWstEth = new MockAwstETH(aavePool, wstEth);

        curveEthStEthPool = new MockCurvePool(stEth);
        balancerVault = new MockBalancerVault(weth);

        scWETH.ConstructorParams memory scWethParams = scWETH.ConstructorParams({
            admin: address(this),
            keeper: keeper,
            targetLtv: 0.7e18,
            slippageTolerance: 0.99e18,
            aavePool: aavePool,
            aaveAwstEth: IAToken(address(aaveAWstEth)),
            aaveVarDWeth: ERC20(address(aaveVarDWeth)),
            curveEthStEthPool: curveEthStEthPool,
            stEth: ILido(address(stEth)),
            wstEth: IwstETH(address(wstEth)),
            weth: WETH(payable(weth)),
            stEthToEthPriceFeed: stEthToEthPriceFeed,
            balancerVault: balancerVault
        });

        vault = new scWETH(scWethParams);

        vm.deal(address(weth), 100e18);
        vm.deal(address(curveEthStEthPool), 100e18);
        weth.mint(address(balancerVault), 100e18);
        weth.mint(address(aavePool), 100e18);
    }

    function test_harvest() public {
        uint256 depositAmount = 10e18;
        deal(address(weth), alice, depositAmount);

        vm.startPrank(alice);
        weth.approve(address(vault), type(uint256).max);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        vm.prank(keeper);
        vault.harvest();

        uint256 aliceShares = vault.balanceOf(alice);
        assertEq(vault.convertToAssets(aliceShares), depositAmount, "alice's assets");
        assertEq(vault.totalAssets(), depositAmount, "total assets");
        assertEq(vault.getCollateral(), depositAmount.divWadDown(1e18 - vault.targetLtv()), "collateral");
        assertEq(vault.getDebt(), vault.getCollateral().mulWadDown(vault.targetLtv()), "debt");
    }

    function test_redeem() public {
        uint256 depositAmount = 10e18;
        deal(address(weth), alice, depositAmount);

        vm.startPrank(alice);
        weth.approve(address(vault), type(uint256).max);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        vm.prank(keeper);
        vault.harvest();

        uint256 stEthToEthSlippage = 0.99e18;
        curveEthStEthPool.setSlippage(stEthToEthSlippage);

        uint256 withdrawAmount = 1e18;
        uint256 sharesToReddem = vault.convertToShares(withdrawAmount);
        vm.prank(alice);
        vault.redeem(sharesToReddem, alice, alice);

        uint256 aliceShares = vault.balanceOf(alice);
        assertEq(vault.convertToAssets(aliceShares), depositAmount - withdrawAmount, "alice's assets");
        uint256 totalAssets = vault.totalAssets();
        assertEq(totalAssets, depositAmount - withdrawAmount, "total assets");
        assertEq(vault.getCollateral(), totalAssets.divWadDown(1e18 - vault.targetLtv()), "collateral");
        assertEq(vault.getDebt(), vault.getCollateral().mulWadDown(vault.targetLtv()), "debt");

        uint256 leverage = uint256(1e18).divWadDown(1e18 - vault.targetLtv());
        uint256 expectedPctDiff = uint256(1e18 - stEthToEthSlippage).mulWadDown(leverage);
        assertApproxEqAbs(weth.balanceOf(alice), withdrawAmount.mulWadDown(1e18 - expectedPctDiff), 1, "alice's weth");
    }

    function test_getLtv() public {
        uint256 amount = 10e18;
        deal(address(weth), alice, amount);

        vm.startPrank(alice);
        weth.approve(address(vault), type(uint256).max);
        vault.deposit(amount, alice);
        vm.stopPrank();

        vm.prank(keeper);
        vault.harvest();

        aavePool.setStEthToEthPriceFeed(stEthToEthPriceFeed, wstEth, weth);

        assertEq(vault.getLtv(), vault.targetLtv(), "ltv");
    }
}
