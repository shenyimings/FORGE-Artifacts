// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import "forge-std/console2.sol";

import {CREATE3Script} from "./CREATE3Script.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {IPool} from "aave-v3/interfaces/IPool.sol";
import {IAToken} from "aave-v3/interfaces/IAToken.sol";
import {IPoolDataProvider} from "aave-v3/interfaces/IPoolDataProvider.sol";

import {Constants as C} from "../../src/lib/Constants.sol";
import {ICurvePool} from "../../src/interfaces/curve/ICurvePool.sol";
import {ILido} from "../../src/interfaces/lido/ILido.sol";
import {IwstETH} from "../../src/interfaces/lido/IwstETH.sol";
import {AggregatorV3Interface} from "../../src/interfaces/chainlink/AggregatorV3Interface.sol";
import {IVault} from "../../src/interfaces/balancer/IVault.sol";
import {ISwapRouter} from "../../src/interfaces/uniswap/ISwapRouter.sol";
import {scWETH} from "../../src/steth/scWETH.sol";
import {scUSDC} from "../../src/steth/scUSDC.sol";

import {MockWETH} from "../../test/mocks/MockWETH.sol";
import {MockUSDC} from "../../test/mocks/MockUSDC.sol";
import {MockAavePool} from "../../test/mocks/aave-v3/MockAavePool.sol";
import {MockAavePoolDataProvider} from "../../test/mocks/aave-v3/MockAavePoolDataProvider.sol";
import {MockAUsdc} from "../../test/mocks/aave-v3/MockAUsdc.sol";
import {MockVarDebtWETH} from "../../test/mocks/aave-v3/MockVarDebtWETH.sol";
import {MockAwstETH} from "../../test/mocks/aave-v3/MockAwstETH.sol";

import {MockStETH} from "../../test/mocks/lido/MockStETH.sol";
import {MockWstETH} from "../../test/mocks/lido/MockWstETH.sol";
import {MockCurvePool} from "../../test/mocks/curve/MockCurvePool.sol";
import {MockChainlinkPriceFeed} from "../../test/mocks/chainlink/MockChainlinkPriceFeed.sol";
import {MockBalancerVault} from "../../test/mocks/balancer/MockBalancerVault.sol";
import {MockSwapRouter} from "../../test/mocks/uniswap/MockSwapRouter.sol";

abstract contract DeployLeveragedEth is CREATE3Script {
    MockWETH weth;
    MockUSDC usdc;
    MockAavePool aavePool;
    MockAavePoolDataProvider aavePoolDataProvider;
    MockAUsdc aaveAUsdc;
    MockVarDebtWETH aaveVarDWeth;
    MockStETH stEth;
    MockWstETH wstEth;
    MockAwstETH aaveAwstEth;
    MockCurvePool curveEthStEthPool;
    MockChainlinkPriceFeed stEthToEthPriceFeed;
    MockChainlinkPriceFeed usdcToEthPriceFeed;
    MockBalancerVault balancerVault;
    MockSwapRouter uniswapRouter;
    scWETH wethContract;
    scUSDC usdcContract;

    address keeper = vm.envAddress("KEEPER");

    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function deploy() internal {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        deployMockTokens();
        deployMocks();

        scWETH.ConstructorParams memory scWethParams = scWETH.ConstructorParams({
            admin: address(this),
            keeper: keeper,
            targetLtv: 0.7e18,
            slippageTolerance: 0.99e18,
            aavePool: aavePool,
            aaveAwstEth: IAToken(address(aaveAwstEth)),
            aaveVarDWeth: ERC20(address(aaveVarDWeth)),
            curveEthStEthPool: curveEthStEthPool,
            stEth: ILido(address(stEth)),
            wstEth: IwstETH(address(wstEth)),
            weth: WETH(payable(weth)),
            stEthToEthPriceFeed: stEthToEthPriceFeed,
            balancerVault: balancerVault
        });

        wethContract = new scWETH(scWethParams);

        scUSDC.ConstructorParams memory scUsdcParams = scUSDC.ConstructorParams({
            admin: address(this),
            keeper: keeper,
            scWETH: wethContract,
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

        usdcContract = new scUSDC(scUsdcParams);

        vm.stopBroadcast();
    }

    function deployMockTokens() internal virtual {}

    function deployMocks() internal {
        stEth = new MockStETH();
        wstEth = new MockWstETH(stEth);
        stEthToEthPriceFeed = new MockChainlinkPriceFeed(address(stEth), address(weth), 1e18);
        usdcToEthPriceFeed = new MockChainlinkPriceFeed(address(usdc), address(weth), 0.001e18);
        aavePool = new MockAavePool();
        aavePool.setStEthToEthPriceFeed(stEthToEthPriceFeed, wstEth, weth);
        aavePoolDataProvider = new MockAavePoolDataProvider(address(usdc), address(weth));
        aaveAUsdc = new MockAUsdc(aavePool, usdc);
        aaveVarDWeth = new MockVarDebtWETH(aavePool, weth);
        aaveAwstEth = new MockAwstETH(aavePool, wstEth);
        curveEthStEthPool = new MockCurvePool(stEth);
        balancerVault = new MockBalancerVault(weth);
        uniswapRouter = new MockSwapRouter();

        console2.log("weth: contract MockWETH", address(weth));
        console2.log("usdc: contract MockUSDC", address(usdc));
        console2.log("aavePool: contract MockAavePool", address(aavePool));
        console2.log("aavePoolDataProvider: contract MockAavePoolDataProvider", address(aavePoolDataProvider));
        console2.log("aaveAUsdc: contract MockAUsdc", address(aaveAUsdc));
        console2.log("aaveVarDWeth: contract MockVarDebtWETH", address(aaveVarDWeth));
        console2.log("stEth: contract MockStETH", address(stEth));
        console2.log("wstEth: contract MockWstETH", address(wstEth));
        console2.log("aaveAwstEth: contract MockAwstETH", address(aaveAwstEth));
        console2.log("curveEthStEthPool: contract MockCurvePool", address(curveEthStEthPool));
        console2.log("stEthToEthPriceFeed: contract MockChainlinkPriceFeed", address(stEthToEthPriceFeed));
        console2.log("usdcToEthPriceFeed: contract MockChainlinkPriceFeed", address(usdcToEthPriceFeed));
        console2.log("balancerVault: contract MockBalancerVault", address(balancerVault));
        console2.log("uniswapRouter: contract MockSwapRouter", address(uniswapRouter));
        console2.log("");

        weth.mint(address(balancerVault), 100e18);
        weth.mint(address(aavePool), 100e18);
        console2.log("weth: minted 100e18 to balancerVault", address(balancerVault));
        console2.log("weth: minted 100e18 to aavePool", address(aavePool));

        console2.log("NOTE: 1 mWETH = 1000 mUSDC");
        console2.log("NOTE: 1 mstETH = 1 ETH");
    }
}
