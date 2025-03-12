// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";
import { TestToken } from "../utils/TestToken.sol";
import { console } from "../utils/Console.sol";
import { DiamondTest, RubicMultiProxy } from "../utils/DiamondTest.sol";
import { LibAsset } from "rubic/Libraries/LibAsset.sol";
import { Vm } from "forge-std/Vm.sol";
import { IRubic } from "rubic/Interfaces/IRubic.sol";
import { FullMath } from "rubic/Libraries/FullMath.sol";
import { FeesFacet, IFeesFacet, FeeTooHigh } from "rubic/Facets/FeesFacet.sol";
import { InvalidAmount } from "rubic/Errors/GenericErrors.sol";

contract MockFacetWithFees {
    function bridgeTokensViaMock(
        IRubic.BridgeData memory _bridgeData
    ) external payable {
        LibAsset.depositAssetAndAccrueFees(
            _bridgeData.sendingAssetId,
            _bridgeData.minAmount,
            0,
            _bridgeData.integrator
        );
    }

    function bridgeTokensViaMockWithNativeReserve(
        IRubic.BridgeData memory _bridgeData,
        uint256 _nativeReserve
    ) external payable {
        LibAsset.depositAssetAndAccrueFees(
            _bridgeData.sendingAssetId,
            _bridgeData.minAmount,
            _nativeReserve,
            _bridgeData.integrator
        );
    }
}

contract FeesFacetTest is Test, DiamondTest {
    RubicMultiProxy internal diamond;
    FeesFacet internal feesFacet;
    MockFacetWithFees internal mockFacet;
    TestToken internal token;
    address internal erc20proxy;

    IRubic.BridgeData internal defaultData;

    address internal constant USER_SENDER = address(0xabc123456);
    uint256 internal constant DEFAULT_TOKEN_AMOUNT = 100 ether;

    uint256 constant FIXED_NATIVE_FEE = 2 ether / 100;
    uint256 constant MAX_TOKEN_FEE = 250000;
    uint32 constant TOKEN_FEE = 1e4;
    uint256 constant DENOMINATOR = 1e6;

    address constant INTEGRATOR =
        address(uint160(uint256(keccak256("integrator"))));
    address constant FEE_TREASURY =
        address(uint160(uint256(keccak256("fee.treasury"))));

    function setUp() public {
        (diamond, erc20proxy) = createDiamond(FEE_TREASURY, MAX_TOKEN_FEE);
        feesFacet = new FeesFacet();
        mockFacet = new MockFacetWithFees();

        bytes4[] memory functionSelectors = new bytes4[](4);
        functionSelectors[0] = FeesFacet.setMaxRubicPlatformFee.selector;
        functionSelectors[1] = FeesFacet.RubicPlatformFee.selector;
        functionSelectors[2] = FeesFacet.maxRubicPlatformFee.selector;
        functionSelectors[3] = FeesFacet.integratorToFeeInfo.selector;

        addFacet(diamond, address(feesFacet), functionSelectors);

        functionSelectors = new bytes4[](2);
        functionSelectors[0] = MockFacetWithFees.bridgeTokensViaMock.selector;
        functionSelectors[1] = MockFacetWithFees
            .bridgeTokensViaMockWithNativeReserve
            .selector;

        addFacet(diamond, address(mockFacet), functionSelectors);

        feesFacet = FeesFacet(address(diamond));
        mockFacet = MockFacetWithFees(address(diamond));

        token = new TestToken("test", "tst", 18);
        token.mint(USER_SENDER, 10_000 ether);

        vm.deal(USER_SENDER, 1000 ether);

        defaultData = IRubic.BridgeData({
            transactionId: "",
            bridge: "MockFacetWithFees",
            integrator: address(0),
            referrer: address(0),
            sendingAssetId: address(token),
            receivingAssetId: address(0xdeadcafebabe),
            receiver: USER_SENDER,
            minAmount: DEFAULT_TOKEN_AMOUNT,
            destinationChainId: 137,
            hasSourceSwaps: false,
            hasDestinationCall: false
        });
    }

    modifier setFixedNativeFee() {
        feesFacet.setFixedNativeFee(FIXED_NATIVE_FEE);
        _;
    }

    modifier setTokenFee() {
        feesFacet.setRubicPlatformFee(TOKEN_FEE);
        _;
    }

    /// FIXED FEE TESTS ///

    function testFixedNativeFeeCollecting_SendingTokens()
        public
        setFixedNativeFee
    {
        vm.startPrank(USER_SENDER);
        token.approve(erc20proxy, type(uint256).max);

        mockFacet.bridgeTokensViaMock{ value: FIXED_NATIVE_FEE }(defaultData);

        assertEq(FEE_TREASURY.balance, FIXED_NATIVE_FEE);
        assertEq(address(diamond).balance, 0);
        vm.stopPrank();
    }

    function testFixedNativeFeeCollecting_SendingNative()
        public
        setFixedNativeFee
    {
        vm.startPrank(USER_SENDER);

        defaultData.sendingAssetId = address(0);
        defaultData.minAmount = 1 ether;

        mockFacet.bridgeTokensViaMock{ value: 1 ether + FIXED_NATIVE_FEE }(
            defaultData
        );

        assertEq(FEE_TREASURY.balance, FIXED_NATIVE_FEE);
        assertEq(address(diamond).balance, 1 ether);
        vm.stopPrank();
    }

    function test_Revert_SendingNotEnoughForNativeReserve()
        public
        setFixedNativeFee
    {
        vm.startPrank(USER_SENDER);
        token.approve(erc20proxy, type(uint256).max);

        vm.expectRevert(InvalidAmount.selector);
        mockFacet.bridgeTokensViaMockWithNativeReserve{
            value: FIXED_NATIVE_FEE + 1 ether
        }(defaultData, 2 ether);

        vm.stopPrank();
    }

    function test_Revert_SetFixedNativeFeeGeMax() public {
        vm.expectRevert(FeeTooHigh.selector);
        feesFacet.setFixedNativeFee(type(uint256).max);
    }

    /// TOKEN FEE TESTS ///

    function testCalcTokenFees_FuzzedPercent(uint256 bips) public {
        vm.assume(bips > 10 && bips <= DENOMINATOR);

        feesFacet.setMaxRubicPlatformFee(DENOMINATOR);
        feesFacet.setRubicPlatformFee(bips);
        uint256 expectedFee = (DEFAULT_TOKEN_AMOUNT * bips) / DENOMINATOR;

        (uint256 resultFee, uint256 RubicFee, ) = feesFacet.calcTokenFees(
            DEFAULT_TOKEN_AMOUNT,
            address(0)
        );

        assertEq(resultFee, RubicFee);
        assertEq(resultFee, expectedFee);
    }

    function testCalcTokenFees_FuzzedAmount(uint256 amount) public {
        feesFacet.setRubicPlatformFee(TOKEN_FEE);
        uint256 expectedFee = FullMath.mulDiv(amount, TOKEN_FEE, DENOMINATOR);

        (uint256 totalFee, uint256 RubicFee, ) = feesFacet.calcTokenFees(
            amount,
            address(0)
        );

        assertEq(totalFee, RubicFee);
        assertEq(totalFee, expectedFee);
    }

    function testCalcTokenFees_WithIntegrator_FuzzedPercent(
        uint32 bips
    ) public {
        vm.assume(bips > 10 && bips <= DENOMINATOR);

        feesFacet.setMaxRubicPlatformFee(DENOMINATOR);
        feesFacet.setIntegratorInfo(
            INTEGRATOR,
            IFeesFacet.IntegratorFeeInfo(true, bips, 500000, 0, 0)
        );
        uint256 expectedTotalFee = (DEFAULT_TOKEN_AMOUNT * bips) / DENOMINATOR;
        uint256 expectedIntegratorFee = expectedTotalFee / 2;

        (uint256 totalFee, uint256 RubicFee, uint256 integratorFee) = feesFacet
            .calcTokenFees(DEFAULT_TOKEN_AMOUNT, INTEGRATOR);

        assertEq(integratorFee, RubicFee);
        assertEq(expectedIntegratorFee, integratorFee);
        assertEq(totalFee, expectedTotalFee);
    }

    function testCalcTokenFees_WithIntegrator_FuzzedAmount(
        uint256 amount
    ) public {
        feesFacet.setMaxRubicPlatformFee(DENOMINATOR);
        feesFacet.setIntegratorInfo(
            INTEGRATOR,
            IFeesFacet.IntegratorFeeInfo(true, TOKEN_FEE, 500000, 0, 0)
        );
        uint256 expectedTotalFee = FullMath.mulDiv(
            amount,
            TOKEN_FEE,
            DENOMINATOR
        );
        uint256 expectedRubicFee = expectedTotalFee / 2;

        (uint256 totalFee, uint256 RubicFee, uint256 integratorFee) = feesFacet
            .calcTokenFees(amount, INTEGRATOR);

        assertApproxEqAbs(integratorFee, RubicFee, 1, "Integrator:Rubic");
        assertEq(
            integratorFee,
            expectedTotalFee - expectedRubicFee,
            "ExpectedIntegrator:Integrator"
        );
        assertEq(totalFee, expectedTotalFee, "Total:ExpectedTotal");
    }

    function testCalcTokenFees_WithIntegrator_FuzzedShare(
        uint32 share
    ) public {
        vm.assume(share > 10 && share <= DENOMINATOR);

        feesFacet.setMaxRubicPlatformFee(DENOMINATOR);
        feesFacet.setIntegratorInfo(
            INTEGRATOR,
            IFeesFacet.IntegratorFeeInfo(true, TOKEN_FEE, share, 0, 0)
        );
        uint256 expectedTotalFee = (DEFAULT_TOKEN_AMOUNT * TOKEN_FEE) /
            DENOMINATOR;
        uint256 expectedRubicFee = (expectedTotalFee * share) / DENOMINATOR;

        (uint256 totalFee, uint256 RubicFee, uint256 integratorFee) = feesFacet
            .calcTokenFees(DEFAULT_TOKEN_AMOUNT, INTEGRATOR);

        assertEq(integratorFee + RubicFee, totalFee);
        assertEq(RubicFee, expectedRubicFee);
        assertEq(totalFee, expectedTotalFee);
    }

    function testTokenFeeCollecting_SendingTokens() public setTokenFee {
        vm.startPrank(USER_SENDER);
        token.approve(erc20proxy, type(uint256).max);

        mockFacet.bridgeTokensViaMock(defaultData);

        (uint256 expectedFee, , ) = feesFacet.calcTokenFees(
            DEFAULT_TOKEN_AMOUNT,
            address(0)
        );

        assertEq(token.balanceOf(FEE_TREASURY), expectedFee);
        assertEq(
            token.balanceOf(address(diamond)),
            DEFAULT_TOKEN_AMOUNT - expectedFee
        );
        vm.stopPrank();
    }
}
