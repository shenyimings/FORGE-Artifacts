// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import { LibAllowList, TestBaseFacet, console } from "../utils/TestBaseFacet.sol";
import { TestFacet } from "../utils/TestBase.sol";
import { SymbiosisFacet } from "rubic/Facets/SymbiosisFacet.sol";
import { ISymbiosisMetaRouter } from "rubic/Interfaces/ISymbiosisMetaRouter.sol";

// Stub SymbiosisFacet Contract
contract TestSymbiosisFacet is SymbiosisFacet, TestFacet {
    constructor(
        ISymbiosisMetaRouter _symbiosisMetaRouter,
        address _symbiosisGateway
    ) SymbiosisFacet(_symbiosisMetaRouter, _symbiosisGateway) {}
}

contract SymbiosisFacetTest is TestBaseFacet {
    // These values are for Mainnet
    address internal constant SYMBIOSIS_METAROUTER =
        0xB9E13785127BFfCc3dc970A55F6c7bF0844a3C15;
    address internal constant SYMBIOSIS_GATEWAY =
        0x03B7551EB0162c838a10c2437b60D1f5455b9554;
    address internal constant RELAY_RECIPIENT =
        0xb80fDAA74dDA763a8A158ba85798d373A5E84d84;

    TestSymbiosisFacet internal symbiosisFacet;
    SymbiosisFacet.SymbiosisData internal symbiosisData;

    function initiateBridgeTxWithFacet(bool isNative) internal override {
        if (isNative) {
            symbiosisFacet.startBridgeTokensViaSymbiosis{
                value: bridgeData.minAmount + addToMessageValue
            }(bridgeData, symbiosisData);
        } else {
            symbiosisFacet.startBridgeTokensViaSymbiosis{
                value: addToMessageValue
            }(bridgeData, symbiosisData);
        }
    }

    function initiateSwapAndBridgeTxWithFacet(
        bool isNative
    ) internal override {
        if (isNative) {
            symbiosisFacet.swapAndStartBridgeTokensViaSymbiosis{
                value: swapData[0].fromAmount + addToMessageValue
            }(bridgeData, swapData, symbiosisData);
        } else {
            symbiosisFacet.swapAndStartBridgeTokensViaSymbiosis{
                value: addToMessageValue
            }(bridgeData, swapData, symbiosisData);
        }
    }

    function setUp() public {
        initTestBase();

        symbiosisFacet = new TestSymbiosisFacet(
            ISymbiosisMetaRouter(SYMBIOSIS_METAROUTER),
            SYMBIOSIS_GATEWAY
        );

        bytes4[] memory functionSelectors = new bytes4[](4);
        functionSelectors[0] = symbiosisFacet
            .startBridgeTokensViaSymbiosis
            .selector;
        functionSelectors[1] = symbiosisFacet
            .swapAndStartBridgeTokensViaSymbiosis
            .selector;
        functionSelectors[2] = symbiosisFacet.addDex.selector;
        functionSelectors[3] = symbiosisFacet
            .setFunctionApprovalBySignature
            .selector;

        addFacet(diamond, address(symbiosisFacet), functionSelectors);

        symbiosisFacet = TestSymbiosisFacet(address(diamond));

        symbiosisFacet.addDex(address(uniswap));
        symbiosisFacet.setFunctionApprovalBySignature(
            uniswap.swapExactTokensForTokens.selector
        );
        symbiosisFacet.setFunctionApprovalBySignature(
            uniswap.swapExactTokensForETH.selector
        );
        symbiosisFacet.setFunctionApprovalBySignature(
            uniswap.swapETHForExactTokens.selector
        );
        symbiosisFacet.setFunctionApprovalBySignature(
            uniswap.swapTokensForExactETH.selector
        );

        setFacetAddressInTestBase(address(symbiosisFacet), "SymbiosisFacet");

        bridgeData.bridge = "symbiosis";
        bridgeData.minAmount = defaultUSDCAmount;

        bytes
            memory _otherSideCalldata = hex"ce654c17000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000186a0000000000000000000000000000000000000000000000000000000003a169f84000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000be67bfcb48ea57fe2814e4440dc0e9b91129ff69000000000000000000000000b80fdaa74dda763a8a158ba85798d373a5e84d84000000000000000000000000d5f0f8db993d26f5df89e70a83d32b369dccdaa0000000000000000000000000be67bfcb48ea57fe2814e4440dc0e9b91129ff6900000000000000000000000000000000000000000000000000000000000000890000000000000000000000000000000000000000000000000000000000000200000000000000000000000000ab0738320a21741f12797ee921461c691673e2760000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000be67bfcb48ea57fe2814e4440dc0e9b91129ff69727562696300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000002f28add68e59733d23d5f57d94c31fb965f835d00000000000000000000000002791bca1f2de4661ed88a30c99a7a9449aa8417400000000000000000000000000000000000000000000000000000000000000a49169558600000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003a1518e40000000000000000000000000000000000000000000000000000000039d046d60000000000000000000000000000000000000000000000000000000063c6fa68000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        symbiosisData = SymbiosisFacet.SymbiosisData(
            "",
            "",
            address(0),
            ADDRESS_USDC,
            address(0),
            address(0),
            RELAY_RECIPIENT,
            //some data
            _otherSideCalldata
        );
    }

    function testBase_CanBridgeTokens_fuzzed(uint256 amount) public override {
        // amount should be greater than execution fee
        vm.assume(amount > 10);
        super.testBase_CanBridgeTokens_fuzzed(amount);
    }

    function testBase_CanBridgeNativeTokens() public override {
        address[] memory path = new address[](2);
        path[0] = ADDRESS_WETH;
        path[1] = ADDRESS_USDC;

        symbiosisData.intermediateToken = ADDRESS_USDC;
        symbiosisData.firstDexRouter = address(ADDRESS_UNISWAP);
        symbiosisData.firstSwapCalldata = abi.encodeWithSelector(
            uniswap.swapExactETHForTokens.selector,
            0,
            path,
            SYMBIOSIS_METAROUTER,
            block.timestamp + 20 minutes
        );

        super.testBase_CanBridgeNativeTokens();
    }

    function testBase_CanBridgeNativeTokensWithFees() public override {
        address[] memory path = new address[](2);
        path[0] = ADDRESS_WETH;
        path[1] = ADDRESS_USDC;

        symbiosisData.intermediateToken = ADDRESS_USDC;
        symbiosisData.firstDexRouter = address(ADDRESS_UNISWAP);
        symbiosisData.firstSwapCalldata = abi.encodeWithSelector(
            uniswap.swapExactETHForTokens.selector,
            0,
            path,
            SYMBIOSIS_METAROUTER,
            block.timestamp + 20 minutes
        );

        super.testBase_CanBridgeNativeTokensWithFees();
    }

    function testBase_CanSwapAndBridgeNativeTokens() public override {
        address[] memory path = new address[](2);
        path[0] = ADDRESS_WETH;
        path[1] = ADDRESS_USDC;

        symbiosisData.intermediateToken = ADDRESS_USDC;
        symbiosisData.firstDexRouter = address(ADDRESS_UNISWAP);
        symbiosisData.firstSwapCalldata = abi.encodeWithSelector(
            uniswap.swapExactETHForTokens.selector,
            0,
            path,
            SYMBIOSIS_METAROUTER,
            block.timestamp + 20 minutes
        );

        super.testBase_CanSwapAndBridgeNativeTokens();
    }
}
