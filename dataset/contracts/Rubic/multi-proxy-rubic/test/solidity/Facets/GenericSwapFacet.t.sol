// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import { DSTest } from "ds-test/test.sol";
import { console } from "../utils/Console.sol";
import { TestBase, RubicMultiProxy } from "../utils/TestBase.sol";
import { Vm } from "forge-std/Vm.sol";
import { GenericSwapFacet } from "rubic/Facets/GenericSwapFacet.sol";
import { LibSwap } from "rubic/Libraries/LibSwap.sol";
import { LibAllowList } from "rubic/Libraries/LibAllowList.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { UniswapV2Router02 } from "../utils/Interfaces.sol";
import { IFeesFacet } from "rubic/Interfaces/IFeesFacet.sol";

// Stub GenericSwapFacet Contract
contract TestGenericSwapFacet is GenericSwapFacet {
    function addDex(address _dex) external {
        LibAllowList.addAllowedContract(_dex);
    }

    function setFunctionApprovalBySignature(bytes4 _signature) external {
        LibAllowList.addAllowedSelector(_signature);
    }
}

contract GenericSwapFacetTest is DSTest, TestBase {
    // These values are for Mainnet
    address internal constant USDC_HOLDER =
        0xee5B5B923fFcE93A870B3104b7CA09c3db80047A;
    uint256 internal defaultAmountOut;

    // -----

    TestGenericSwapFacet internal genericSwapFacet;

    function fork() internal override {
        string memory rpcUrl = vm.envString("ETH_NODE_URI_MAINNET");
        uint256 blockNumber = 15588208;
        vm.createSelectFork(rpcUrl, blockNumber);
    }

    function setUp() public {
        initTestBase();

        defaultAmountOut = 10 * 10 ** dai.decimals();

        genericSwapFacet = new TestGenericSwapFacet();

        bytes4[] memory functionSelectors = new bytes4[](3);
        functionSelectors[0] = genericSwapFacet.swapTokensGeneric.selector;
        functionSelectors[1] = genericSwapFacet.addDex.selector;
        functionSelectors[2] = genericSwapFacet
            .setFunctionApprovalBySignature
            .selector;

        addFacet(diamond, address(genericSwapFacet), functionSelectors);

        genericSwapFacet = TestGenericSwapFacet(address(diamond));
        genericSwapFacet.addDex(address(uniswap));
        genericSwapFacet.setFunctionApprovalBySignature(
            uniswap.swapExactTokensForTokens.selector
        );
        genericSwapFacet.setFunctionApprovalBySignature(
            uniswap.swapExactETHForTokens.selector
        );
        genericSwapFacet.setFunctionApprovalBySignature(
            uniswap.swapExactTokensForETH.selector
        );
    }

    modifier setFees() {
        IFeesFacet(address(diamond)).setIntegratorInfo(
            INTEGRATOR,
            IFeesFacet.IntegratorFeeInfo({
                isIntegrator: true,
                tokenFee: TOKEN_FEE,
                RubicTokenShare: 0,
                RubicFixedCryptoShare: 1000000,
                fixedFeeAmount: uint128(FIXED_NATIVE_FEE)
            })
        );
        _;
    }

    modifier assertBalanceChangeGreaterThan(
        address token,
        address user,
        int256 minChangeAmount
    ) {
        // store initial balance
        if (token == address(0)) {
            initialBalances[token][user] = user.balance;
        } else {
            initialBalances[token][user] = ERC20(token).balanceOf(user);
        }

        //execute function
        _;

        //check post-execution balances
        uint256 currentBalance;
        if (token == address(0)) {
            currentBalance = user.balance;
        } else {
            currentBalance = ERC20(token).balanceOf(user);
        }
        uint256 minExpectedBalance = uint256(
            int256(initialBalances[token][user]) + minChangeAmount
        );
        assertGe(currentBalance, minExpectedBalance);
    }

    function testCanSwapERC20()
        public
        assertBalanceChangeGreaterThan(
            ADDRESS_DAI,
            USDC_HOLDER,
            int(defaultAmountOut)
        )
    {
        vm.startPrank(USDC_HOLDER);
        usdc.approve(erc20proxy, 10_000 * 10 ** usdc.decimals());

        // Swap USDC to DAI
        address[] memory path = new address[](2);
        path[0] = ADDRESS_USDC;
        path[1] = ADDRESS_DAI;

        uint initUserBalace = usdc.balanceOf(USDC_HOLDER);

        // Calculate USDC amount
        uint256[] memory amounts = uniswap.getAmountsIn(
            defaultAmountOut,
            path
        );
        uint256 amountIn = amounts[0];
        LibSwap.SwapData[] memory swapData = new LibSwap.SwapData[](1);
        swapData[0] = LibSwap.SwapData(
            address(uniswap),
            address(uniswap),
            ADDRESS_USDC,
            ADDRESS_DAI,
            amountIn,
            abi.encodeWithSelector(
                uniswap.swapExactTokensForTokens.selector,
                amountIn,
                defaultAmountOut,
                path,
                address(genericSwapFacet),
                block.timestamp + 20 minutes
            ),
            true
        );

        genericSwapFacet.swapTokensGeneric(
            "",
            address(0),
            address(0),
            payable(USDC_HOLDER),
            defaultAmountOut,
            swapData
        );

        uint256 expectedBalance = initUserBalace - amountIn;
        assertEq(usdc.balanceOf(USDC_HOLDER), expectedBalance);

        vm.stopPrank();
    }

    function testCanSwapNativeToERC20()
        public
        assertBalanceChangeGreaterThan(
            ADDRESS_DAI,
            USDC_HOLDER,
            int(defaultAmountOut)
        )
    {
        vm.startPrank(USDC_HOLDER);
        // Swap ETH to DAI
        address[] memory path = new address[](2);
        path[0] = ADDRESS_WETH;
        path[1] = ADDRESS_DAI;

        uint initUserBalace = USDC_HOLDER.balance;

        // Calculate ETH amount
        uint256[] memory amounts = uniswap.getAmountsIn(
            defaultAmountOut,
            path
        );
        uint256 amountIn = amounts[0];
        LibSwap.SwapData[] memory swapData = new LibSwap.SwapData[](1);
        swapData[0] = LibSwap.SwapData(
            address(uniswap),
            address(uniswap),
            address(0),
            ADDRESS_DAI,
            amountIn,
            abi.encodeWithSelector(
                uniswap.swapExactETHForTokens.selector,
                defaultAmountOut,
                path,
                address(genericSwapFacet),
                block.timestamp + 20 minutes
            ),
            true
        );

        genericSwapFacet.swapTokensGeneric{ value: amountIn }(
            "",
            address(0),
            address(0),
            payable(USDC_HOLDER),
            defaultAmountOut,
            swapData
        );

        uint256 expectedBalance = initUserBalace - amountIn;
        assertEq(USDC_HOLDER.balance, expectedBalance);

        vm.stopPrank();
    }

    function testCanSwapERC20ToNative()
        public
        assertBalanceChangeGreaterThan(
            address(0),
            USDC_HOLDER,
            int(defaultAmountOut)
        )
    {
        vm.startPrank(USDC_HOLDER);
        usdc.approve(erc20proxy, 13_000 * 10 ** usdc.decimals());

        // Swap USDC to DAI
        address[] memory path = new address[](2);
        path[0] = ADDRESS_USDC;
        path[1] = ADDRESS_WETH;

        uint initUserBalace = usdc.balanceOf(USDC_HOLDER);

        // Calculate USDC amount
        uint256[] memory amounts = uniswap.getAmountsIn(
            defaultAmountOut,
            path
        );
        uint256 amountIn = amounts[0];
        LibSwap.SwapData[] memory swapData = new LibSwap.SwapData[](1);
        swapData[0] = LibSwap.SwapData(
            address(uniswap),
            address(uniswap),
            ADDRESS_USDC,
            address(0),
            amountIn,
            abi.encodeWithSelector(
                uniswap.swapExactTokensForETH.selector,
                amountIn,
                defaultAmountOut,
                path,
                address(genericSwapFacet),
                block.timestamp + 20 minutes
            ),
            true
        );

        genericSwapFacet.swapTokensGeneric(
            "",
            address(0),
            address(0),
            payable(USDC_HOLDER),
            defaultAmountOut,
            swapData
        );

        uint256 expectedBalance = initUserBalace - amountIn;
        assertEq(usdc.balanceOf(USDC_HOLDER), expectedBalance);

        vm.stopPrank();
    }

    function testCanSwapERC20WithFees()
        public
        setFees
        assertBalanceChangeGreaterThan(
            ADDRESS_DAI,
            USDC_HOLDER,
            int(defaultAmountOut)
        )
    {
        vm.startPrank(USDC_HOLDER);

        usdc.approve(erc20proxy, 10_000 * 10 ** usdc.decimals());

        // Swap USDC to DAI
        address[] memory path = new address[](2);
        path[0] = ADDRESS_USDC;
        path[1] = ADDRESS_DAI;

        // Calculate USDC amount
        uint256[] memory amounts = uniswap.getAmountsIn(
            defaultAmountOut,
            path
        );
        uint256 amountIn = amounts[0];
        uint256 amountInWithFee = (amountIn * DENOMINATOR) /
            (DENOMINATOR - TOKEN_FEE);
        LibSwap.SwapData[] memory swapData = new LibSwap.SwapData[](1);
        swapData[0] = LibSwap.SwapData(
            address(uniswap),
            address(uniswap),
            ADDRESS_USDC,
            ADDRESS_DAI,
            amountInWithFee,
            abi.encodeWithSelector(
                uniswap.swapExactTokensForTokens.selector,
                amountIn,
                defaultAmountOut,
                path,
                address(genericSwapFacet),
                block.timestamp + 20 minutes
            ),
            true
        );

        genericSwapFacet.swapTokensGeneric{ value: FIXED_NATIVE_FEE }(
            "",
            INTEGRATOR,
            address(0),
            payable(USDC_HOLDER),
            defaultAmountOut,
            swapData
        );

        assertEq(FEE_TREASURY.balance, FIXED_NATIVE_FEE);
        assertEq(usdc.balanceOf(INTEGRATOR), amountInWithFee - amountIn);

        vm.stopPrank();
    }

    function testCanSwapNativeToERC20WithFees() public setFees {
        vm.startPrank(USDC_HOLDER);
        // Swap ETH to DAI
        address[] memory path = new address[](2);
        path[0] = ADDRESS_WETH;
        path[1] = ADDRESS_DAI;

        uint256 amountOut = 10 * 10 ** dai.decimals();

        // Calculate DAI amount
        uint256[] memory amounts = uniswap.getAmountsIn(amountOut, path);
        uint256 amountIn = amounts[0];
        uint256 amountInWithFee = (amountIn * (DENOMINATOR + TOKEN_FEE)) /
            DENOMINATOR;
        LibSwap.SwapData[] memory swapData = new LibSwap.SwapData[](1);
        swapData[0] = LibSwap.SwapData(
            address(uniswap),
            address(uniswap),
            address(0),
            ADDRESS_DAI,
            amountInWithFee,
            abi.encodeWithSelector(
                uniswap.swapExactETHForTokens.selector,
                amountOut,
                path,
                address(genericSwapFacet),
                block.timestamp + 20 minutes
            ),
            true
        );

        genericSwapFacet.swapTokensGeneric{
            value: amountInWithFee + FIXED_NATIVE_FEE
        }(
            "",
            address(0),
            address(0),
            payable(USDC_HOLDER),
            amountOut,
            swapData
        );
        vm.stopPrank();
    }

    function testCanSwapERC20ToNativeWithFees() public setFees {
        vm.startPrank(USDC_HOLDER);
        usdc.approve(erc20proxy, 30_000 * 10 ** usdc.decimals());

        // Swap USDC to DAI
        address[] memory path = new address[](2);
        path[0] = ADDRESS_USDC;
        path[1] = ADDRESS_WETH;

        uint256 amountOut = 10 * 10 ** weth.decimals();

        // Calculate DAI amount
        uint256[] memory amounts = uniswap.getAmountsIn(amountOut, path);
        uint256 amountIn = amounts[0];
        uint256 amountInWithFee = (amountIn * (DENOMINATOR + TOKEN_FEE)) /
            DENOMINATOR;

        LibSwap.SwapData[] memory swapData = new LibSwap.SwapData[](1);
        swapData[0] = LibSwap.SwapData(
            address(uniswap),
            address(uniswap),
            ADDRESS_USDC,
            address(0),
            amountInWithFee,
            abi.encodeWithSelector(
                uniswap.swapExactTokensForETH.selector,
                amountIn,
                amountOut,
                path,
                address(genericSwapFacet),
                block.timestamp + 20 minutes
            ),
            true
        );

        genericSwapFacet.swapTokensGeneric{ value: FIXED_NATIVE_FEE }(
            "",
            address(0),
            address(0),
            payable(USDC_HOLDER),
            amountOut,
            swapData
        );
        vm.stopPrank();
    }
}
