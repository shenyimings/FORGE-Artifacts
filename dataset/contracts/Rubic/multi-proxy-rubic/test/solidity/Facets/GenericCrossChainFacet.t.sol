// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import { LibAllowList, TestBaseFacet, console } from "../utils/TestBaseFacet.sol";
import { TestToken } from "../utils/TestToken.sol";
import { TestFacet } from "../utils/TestBase.sol";
import { IXSwapper } from "rubic/Interfaces/IXSwapper.sol";
import { console } from "forge-std/console.sol";
import { GenericCrossChainFacet } from "rubic/Facets/GenericCrossChainFacet.sol";
import { UnAuthorized } from "src/Errors/GenericErrors.sol";

// Stub GenericCrossChainFacet Contract
contract TestGenericCrossChainFacet is GenericCrossChainFacet, TestFacet {
    constructor() {}
}

contract GenericCrossChainFacetTest is TestBaseFacet {
    address internal constant XSWAPPER =
        0x4315f344a905dC21a08189A117eFd6E1fcA37D57;
    address internal constant xyNativeAddress =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    TestGenericCrossChainFacet internal genericCrossChainFacet;
    TestToken internal testToken;
    GenericCrossChainFacet.GenericCrossChainData
        internal genericCrossChainData;

    function initiateBridgeTxWithFacet(bool isNative) internal override {
        if (isNative) {
            genericCrossChainFacet.startBridgeTokensViaGenericCrossChain{
                value: bridgeData.minAmount + addToMessageValue
            }(bridgeData, genericCrossChainData);
        } else {
            genericCrossChainFacet.startBridgeTokensViaGenericCrossChain{
                value: addToMessageValue
            }(bridgeData, genericCrossChainData);
        }
    }

    function initiateSwapAndBridgeTxWithFacet(
        bool isNative
    ) internal override {
        if (isNative) {
            genericCrossChainFacet
                .swapAndStartBridgeTokensViaGenericCrossChain{
                value: swapData[0].fromAmount + addToMessageValue
            }(bridgeData, swapData, genericCrossChainData);
        } else {
            genericCrossChainFacet
                .swapAndStartBridgeTokensViaGenericCrossChain{
                value: addToMessageValue
            }(bridgeData, swapData, genericCrossChainData);
        }
    }

    function setUp() public {
        initTestBase();

        genericCrossChainFacet = new TestGenericCrossChainFacet();
        testToken = new TestToken("Test", "TST", 18);

        testToken.mint(USER_SENDER, 10_000 ether);

        bytes4[] memory functionSelectors = new bytes4[](6);
        functionSelectors[0] = genericCrossChainFacet
            .startBridgeTokensViaGenericCrossChain
            .selector;
        functionSelectors[1] = genericCrossChainFacet
            .swapAndStartBridgeTokensViaGenericCrossChain
            .selector;
        functionSelectors[2] = genericCrossChainFacet.addDex.selector;
        functionSelectors[3] = genericCrossChainFacet
            .setFunctionApprovalBySignature
            .selector;
        functionSelectors[4] = genericCrossChainFacet
            .updateProviderFunctionAmountOffset
            .selector;
        functionSelectors[5] = genericCrossChainFacet
            .getProviderFunctionAmountOffset
            .selector;

        addFacet(diamond, address(genericCrossChainFacet), functionSelectors);

        genericCrossChainFacet = TestGenericCrossChainFacet(address(diamond));

        genericCrossChainFacet.addDex(address(uniswap));
        genericCrossChainFacet.setFunctionApprovalBySignature(
            uniswap.swapExactTokensForTokens.selector
        );
        genericCrossChainFacet.setFunctionApprovalBySignature(
            uniswap.swapExactTokensForETH.selector
        );
        genericCrossChainFacet.setFunctionApprovalBySignature(
            uniswap.swapETHForExactTokens.selector
        );
        genericCrossChainFacet.setFunctionApprovalBySignature(
            uniswap.swapTokensForExactETH.selector
        );

        setFacetAddressInTestBase(
            address(genericCrossChainFacet),
            "GenericCrossChainFacet"
        );

        bridgeData.bridge = "generic_testProvider";
        bridgeData.minAmount = defaultUSDCAmount;

        genericCrossChainData = GenericCrossChainFacet.GenericCrossChainData(
            payable(XSWAPPER),
            abi.encodeWithSelector(
                IXSwapper.swap.selector,
                address(0),
                IXSwapper.SwapDescription(
                    ADDRESS_USDC,
                    ADDRESS_USDC,
                    USER_SENDER,
                    228,
                    228
                ),
                "",
                IXSwapper.ToChainDescription(
                    56,
                    0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, // BUSD
                    1000,
                    100
                )
            )
        );

        address[] memory _routers = new address[](1);
        bytes4[] memory _selectors = new bytes4[](1);
        uint256[] memory _offsets = new uint256[](1);

        //        0x4039c8d0 // 4
        //        0000000000000000000000000000000000000000000000000000000000000000 // 32
        //        000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48 // 32
        //        000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48 // 32
        //        0000000000000000000000000000000000000000000000000000000abc123456 // 32
        //        00000000000000000000000000000000000000000000000000000000000000e4 // <-
        //        00000000000000000000000000000000000000000000000000000000000000e4
        //        0000000000000000000000000000000000000000000000000000000000000160
        //        0000000000000000000000000000000000000000000000000000000000000038
        //        000000000000000000000000e9e7cea3dedca5984780bafc599bd69add087d56
        //        00000000000000000000000000000000000000000000000000000000000003e8
        //        0000000000000000000000000000000000000000000000000000000000000064
        //        0000000000000000000000000000000000000000000000000000000000000000

        _routers[0] = XSWAPPER;
        _selectors[0] = IXSwapper.swap.selector;
        _offsets[0] = 32 * 4 + 4;

        genericCrossChainFacet.updateProviderFunctionAmountOffset(
            _routers,
            _selectors,
            _offsets
        );
    }

    function testGetProviderFunctionAmountOffset() public {
        assertEq(
            genericCrossChainFacet.getProviderFunctionAmountOffset(
                XSWAPPER,
                IXSwapper.swap.selector
            ),
            32 * 4 + 4
        );
    }

    function test_Revert_CannotCallERC20Proxy() public {
        vm.startPrank(USER_SENDER);

        genericCrossChainData = GenericCrossChainFacet.GenericCrossChainData(
            payable(erc20proxy),
            abi.encodeWithSelector(
                IXSwapper.swap.selector,
                address(0),
                IXSwapper.SwapDescription(
                    ADDRESS_USDC,
                    ADDRESS_USDC,
                    USER_SENDER,
                    228,
                    228
                ),
                "",
                IXSwapper.ToChainDescription(
                    56,
                    0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, // BUSD
                    1000,
                    100
                )
            )
        );

        vm.expectRevert(UnAuthorized.selector);
        initiateBridgeTxWithFacet(false);

        vm.stopPrank();
    }

    function testBase_CanBridgeTokens_fuzzed(uint256 amount) public override {
        // amount should be greater than xy fee
        vm.assume(amount > 15);
        super.testBase_CanBridgeTokens_fuzzed(amount);
    }

    function testBase_CanBridgeNativeTokens() public override {
        genericCrossChainData = GenericCrossChainFacet.GenericCrossChainData(
            payable(XSWAPPER),
            abi.encodeWithSelector(
                IXSwapper.swap.selector,
                address(0),
                IXSwapper.SwapDescription(
                    xyNativeAddress,
                    xyNativeAddress,
                    USER_SENDER,
                    228,
                    228
                ),
                "",
                IXSwapper.ToChainDescription(
                    56,
                    0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, // BUSD
                    1000,
                    100
                )
            )
        );

        super.testBase_CanBridgeNativeTokens();
    }

    function testBase_CanBridgeNativeTokensWithFees() public override {
        genericCrossChainData = GenericCrossChainFacet.GenericCrossChainData(
            payable(XSWAPPER),
            abi.encodeWithSelector(
                IXSwapper.swap.selector,
                address(0),
                IXSwapper.SwapDescription(
                    xyNativeAddress,
                    xyNativeAddress,
                    USER_SENDER,
                    228,
                    228
                ),
                "",
                IXSwapper.ToChainDescription(
                    56,
                    0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, // BUSD
                    1000,
                    100
                )
            )
        );

        super.testBase_CanBridgeNativeTokensWithFees();
    }

    function testBase_CanSwapAndBridgeNativeTokens() public override {
        genericCrossChainData = GenericCrossChainFacet.GenericCrossChainData(
            payable(XSWAPPER),
            abi.encodeWithSelector(
                IXSwapper.swap.selector,
                address(0),
                IXSwapper.SwapDescription(
                    xyNativeAddress,
                    xyNativeAddress,
                    USER_SENDER,
                    228,
                    228
                ),
                "",
                IXSwapper.ToChainDescription(
                    56,
                    0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, // BUSD
                    1000,
                    100
                )
            )
        );

        super.testBase_CanSwapAndBridgeNativeTokens();
    }
}
