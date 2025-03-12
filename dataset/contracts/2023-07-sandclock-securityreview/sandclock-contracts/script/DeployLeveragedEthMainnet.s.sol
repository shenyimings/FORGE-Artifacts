// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {CREATE3Script} from "./base/CREATE3Script.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {IPool} from "aave-v3/interfaces/IPool.sol";
import {IAToken} from "aave-v3/interfaces/IAToken.sol";
import {IPoolDataProvider} from "aave-v3/interfaces/IPoolDataProvider.sol";

import {Constants as C} from "../src/lib/Constants.sol";
import {ICurvePool} from "../src/interfaces/curve/ICurvePool.sol";
import {ILido} from "../src/interfaces/lido/ILido.sol";
import {IwstETH} from "../src/interfaces/lido/IwstETH.sol";
import {AggregatorV3Interface} from "../src/interfaces/chainlink/AggregatorV3Interface.sol";
import {IVault} from "../src/interfaces/balancer/IVault.sol";
import {ISwapRouter} from "../src/interfaces/uniswap/ISwapRouter.sol";
import {scWETH} from "../src/steth/scWETH.sol";
import {scUSDC} from "../src/steth/scUSDC.sol";
import {sc4626} from "../src/sc4626.sol";

contract DeployScript is CREATE3Script {
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    WETH weth = WETH(payable(C.WETH));
    ERC20 usdc = ERC20(C.USDC);
    ISwapRouter uniswapRouter = ISwapRouter(C.UNISWAP_V3_SWAP_ROUTER);
    uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
    address deployerAddress = vm.addr(deployerPrivateKey);

    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() external returns (scWETH scWeth, scUSDC scUsdc) {
        address keeper = vm.envAddress("KEEPER");

        vm.startBroadcast(deployerPrivateKey);

        scWETH.ConstructorParams memory scWethParams = scWETH.ConstructorParams({
            admin: deployerAddress,
            keeper: keeper,
            targetLtv: 0.7e18,
            slippageTolerance: 0.99e18,
            aavePool: IPool(C.AAVE_POOL),
            aaveAwstEth: IAToken(C.AAVE_AWSTETH_TOKEN),
            aaveVarDWeth: ERC20(C.AAVAAVE_VAR_DEBT_WETH_TOKEN),
            curveEthStEthPool: ICurvePool(C.CURVE_ETH_STETH_POOL),
            stEth: ILido(C.STETH),
            wstEth: IwstETH(C.WSTETH),
            weth: WETH(payable(C.WETH)),
            stEthToEthPriceFeed: AggregatorV3Interface(C.CHAINLINK_STETH_ETH_PRICE_FEED),
            balancerVault: IVault(C.BALANCER_VAULT)
        });

        scWeth = new scWETH(scWethParams);

        weth.deposit{value: 0.01 ether}(); // wrap 0.01 ETH into WETH
        deposit(scWeth, 0.01 ether); // 0.01 WETH

        // transfer DEFAULT_ADMIN_ROLE to multisig
        scWeth.grantRole(DEFAULT_ADMIN_ROLE, C.MULTISIG);
        scWeth.revokeRole(DEFAULT_ADMIN_ROLE, deployerAddress);

        scUSDC.ConstructorParams memory scUsdcParams = scUSDC.ConstructorParams({
            admin: deployerAddress,
            keeper: keeper,
            scWETH: scWeth,
            usdc: usdc,
            weth: WETH(payable(C.WETH)),
            aavePool: IPool(C.AAVE_POOL),
            aavePoolDataProvider: IPoolDataProvider(C.AAVE_POOL_DATA_PROVIDER),
            aaveAUsdc: IAToken(C.AAVE_AUSDC_TOKEN),
            aaveVarDWeth: ERC20(C.AAVAAVE_VAR_DEBT_WETH_TOKEN),
            uniswapSwapRouter: uniswapRouter,
            chainlinkUsdcToEthPriceFeed: AggregatorV3Interface(C.CHAINLINK_USDC_ETH_PRICE_FEED),
            balancerVault: IVault(C.BALANCER_VAULT)
        });

        scUsdc = new scUSDC(scUsdcParams);

        swapETHForUSDC(0.01 ether);
        deposit(scUsdc, usdc.balanceOf(address(deployerAddress))); // 0.01 ether worth of USDC

        // transfer DEFAULT_ADMIN_ROLE to multisig
        scUsdc.grantRole(DEFAULT_ADMIN_ROLE, C.MULTISIG);
        scUsdc.revokeRole(DEFAULT_ADMIN_ROLE, deployerAddress);

        vm.stopBroadcast();
    }

    function deposit(sc4626 vault, uint256 amount) internal {
        vault.asset().approve(address(vault), amount);
        vault.deposit(amount, deployerAddress);
    }

    function swapETHForUSDC(uint256 amount) internal {
        weth.deposit{value: amount}();

        weth.approve(address(uniswapRouter), amount);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(weth),
            tokenOut: address(usdc),
            fee: 500, // 0.05%
            recipient: deployerAddress,
            deadline: block.timestamp + 1000,
            amountIn: amount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        uniswapRouter.exactInputSingle(params);
    }
}
