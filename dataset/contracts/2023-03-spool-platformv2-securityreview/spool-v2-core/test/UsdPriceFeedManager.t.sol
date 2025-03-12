// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/external/interfaces/chainlink/AggregatorV3Interface.sol";
import "../src/access/SpoolAccessControl.sol";
import "../src/managers/UsdPriceFeedManager.sol";
import "./mocks/MockAggregatorV3.sol";

contract UsdPriceFeedManagerTest is Test {
    address daiAddress = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address usdcAddress = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address amplAddress = address(0xD46bA6D942050d489DBd938a2C909A5d5039A161);

    MockAggregatorV3 daiUsdPriceAggregator;
    MockAggregatorV3 usdcUsdPriceAggregator;
    MockAggregatorV3 amplUsdPriceAggregator;

    UsdPriceFeedManager usdPriceFeedManager;

    function setUp() public {
        SpoolAccessControl accessControl = new SpoolAccessControl();
        accessControl.initialize();

        usdPriceFeedManager = new UsdPriceFeedManager(accessControl);

        daiUsdPriceAggregator = new MockAggregatorV3(8, "Dai-Usd", 1);
        usdcUsdPriceAggregator = new MockAggregatorV3(8, "Usdc-Usd", 1);
        amplUsdPriceAggregator = new MockAggregatorV3(18, "Ampl-Usd", 1);
    }

    function _setAssets() public {
        usdPriceFeedManager.setAsset(daiAddress, 18, daiUsdPriceAggregator, true);
        daiUsdPriceAggregator.pushAnswer(1_00007408);

        usdPriceFeedManager.setAsset(usdcAddress, 6, usdcUsdPriceAggregator, true);
        usdcUsdPriceAggregator.pushAnswer(1_00012625);

        usdPriceFeedManager.setAsset(amplAddress, 9, amplUsdPriceAggregator, true);
        amplUsdPriceAggregator.pushAnswer(1_369957781322723900);
    }

    function test_usdDecimals_shouldReturnDecimals() public {
        assertEq(usdPriceFeedManager.usdDecimals(), 18);
    }

    function test_setAsset_shouldSetAsset() public {
        _setAssets();

        assertEq(usdPriceFeedManager.assetDecimals(daiAddress), 18);
        assertEq(usdPriceFeedManager.assetMultiplier(daiAddress), 10 ** 18);
        assertEq(address(usdPriceFeedManager.assetPriceAggregator(daiAddress)), address(daiUsdPriceAggregator));
        assertEq(usdPriceFeedManager.assetPriceAggregatorMultiplier(daiAddress), 10 ** 10);
        assertEq(usdPriceFeedManager.assetValidity(daiAddress), true);

        assertEq(usdPriceFeedManager.assetDecimals(usdcAddress), 6);
        assertEq(usdPriceFeedManager.assetMultiplier(usdcAddress), 10 ** 6);
        assertEq(address(usdPriceFeedManager.assetPriceAggregator(usdcAddress)), address(usdcUsdPriceAggregator));
        assertEq(usdPriceFeedManager.assetPriceAggregatorMultiplier(usdcAddress), 10 ** 10);
        assertEq(usdPriceFeedManager.assetValidity(usdcAddress), true);

        assertEq(usdPriceFeedManager.assetDecimals(amplAddress), 9);
        assertEq(usdPriceFeedManager.assetMultiplier(amplAddress), 10 ** 9);
        assertEq(address(usdPriceFeedManager.assetPriceAggregator(amplAddress)), address(amplUsdPriceAggregator));
        assertEq(usdPriceFeedManager.assetPriceAggregatorMultiplier(amplAddress), 1);
        assertEq(usdPriceFeedManager.assetValidity(amplAddress), true);
    }

    function test_setAsset_shouldRevertWhenNotCalledByAdmin() public {
        vm.prank(address(0x123));
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_SPOOL_ADMIN, address(0x123)));
        usdPriceFeedManager.setAsset(daiAddress, 18, daiUsdPriceAggregator, true);
    }

    function test_assetToUsd_shouldConvert() public {
        _setAssets();

        assertEq(usdPriceFeedManager.assetToUsd(daiAddress, 1_854895125485269876), 1_855032536116165824);

        assertEq(usdPriceFeedManager.assetToUsd(usdcAddress, 1_854895), 1_855129180493750000);

        assertEq(usdPriceFeedManager.assetToUsd(amplAddress, 1_854895125), 2_541128010031336613);
    }

    function test_assetToUsd_shouldRevertWhenAssetIsNotValid() public {
        vm.expectRevert(abi.encodeWithSelector(InvalidAsset.selector, daiAddress));
        usdPriceFeedManager.assetToUsd(daiAddress, 1);
    }

    function test_assetToUsd_shouldRevertWhenPriceIsZero() public {
        _setAssets();
        daiUsdPriceAggregator.pushAnswer(0);

        vm.expectRevert(abi.encodeWithSelector(NonPositivePrice.selector, 0));
        usdPriceFeedManager.assetToUsd(daiAddress, 1);
    }

    function test_assetToUsd_shouldRevertWhenPriceIsNegative() public {
        _setAssets();
        daiUsdPriceAggregator.pushAnswer(-1);

        vm.expectRevert(abi.encodeWithSelector(NonPositivePrice.selector, -1));
        usdPriceFeedManager.assetToUsd(daiAddress, 1);
    }

    function test_usdToAsset_shouldConvert() public {
        _setAssets();

        assertEq(usdPriceFeedManager.usdToAsset(daiAddress, 1_855032536116165824), 1_854895125485269875);
        // losing 1 unit on round conversion

        assertEq(usdPriceFeedManager.usdToAsset(usdcAddress, 1_855129180493750000), 1_854895);

        assertEq(usdPriceFeedManager.usdToAsset(amplAddress, 2_541128010031336613), 1_854895124);
        // losing 1 unit on round conversion
    }

    function test_usdToAsset_shouldRevertWhenAssetIsNotValid() public {
        vm.expectRevert(abi.encodeWithSelector(InvalidAsset.selector, daiAddress));
        usdPriceFeedManager.usdToAsset(daiAddress, 1);
    }

    function test_usdToAsset_shouldRevertWhenPriceIsZero() public {
        _setAssets();
        daiUsdPriceAggregator.pushAnswer(0);

        vm.expectRevert(abi.encodeWithSelector(NonPositivePrice.selector, 0));
        usdPriceFeedManager.usdToAsset(daiAddress, 1);
    }

    function test_usdToAsset_shouldRevertWhenPriceIsNegative() public {
        _setAssets();
        daiUsdPriceAggregator.pushAnswer(-1);

        vm.expectRevert(abi.encodeWithSelector(NonPositivePrice.selector, -1));
        usdPriceFeedManager.usdToAsset(daiAddress, 1);
    }

    function test_assetToUsdCustomPrice_shouldConvert() public {
        _setAssets();

        uint256 daiPrice =
            usdPriceFeedManager.assetToUsd(daiAddress, 10 ** usdPriceFeedManager.assetDecimals(daiAddress));
        assertEq(
            usdPriceFeedManager.assetToUsdCustomPrice(daiAddress, 1_854895125485269876, daiPrice), 1_855032536116165824
        );

        uint256 usdcPrice =
            usdPriceFeedManager.assetToUsd(usdcAddress, 10 ** usdPriceFeedManager.assetDecimals(usdcAddress));
        assertEq(usdPriceFeedManager.assetToUsdCustomPrice(usdcAddress, 1_854895, usdcPrice), 1_855129180493750000);

        uint256 amplPrice =
            usdPriceFeedManager.assetToUsd(amplAddress, 10 ** usdPriceFeedManager.assetDecimals(amplAddress));
        assertEq(usdPriceFeedManager.assetToUsdCustomPrice(amplAddress, 1_854895125, amplPrice), 2_541128010031336613);
    }

    function test_assetToUsdCustomPrice_shouldRevertWhenAssetIsNotValid() public {
        vm.expectRevert(abi.encodeWithSelector(InvalidAsset.selector, daiAddress));
        usdPriceFeedManager.assetToUsdCustomPrice(daiAddress, 1, 1);
    }

    function test_usdToAssetCustomPrice_shouldConvert() public {
        _setAssets();

        uint256 daiPrice =
            usdPriceFeedManager.assetToUsd(daiAddress, 10 ** usdPriceFeedManager.assetDecimals(daiAddress));
        assertEq(
            usdPriceFeedManager.usdToAssetCustomPrice(daiAddress, 1_855032536116165824, daiPrice), 1_854895125485269875
        );
        // losing 1 unit on round conversion

        uint256 usdcPrice =
            usdPriceFeedManager.assetToUsd(usdcAddress, 10 ** usdPriceFeedManager.assetDecimals(usdcAddress));
        assertEq(usdPriceFeedManager.usdToAssetCustomPrice(usdcAddress, 1_855129180493750000, usdcPrice), 1_854895);

        uint256 amplPrice =
            usdPriceFeedManager.assetToUsd(amplAddress, 10 ** usdPriceFeedManager.assetDecimals(amplAddress));
        assertEq(usdPriceFeedManager.usdToAssetCustomPrice(amplAddress, 2_541128010031336613, amplPrice), 1_854895124);
        // losing 1 unit on round conversion
    }

    function test_usdToAssetCustomPrice_shouldRevertWhenAssetIsNotValid() public {
        vm.expectRevert(abi.encodeWithSelector(InvalidAsset.selector, daiAddress));
        usdPriceFeedManager.usdToAssetCustomPrice(daiAddress, 1, 1);
    }

    function test_roundConversionError() public {
        uint256 initialAmount;
        uint256 usdAmount;
        uint256 finalAmount;

        // token A
        address tokenA = address(0xa);
        MockAggregatorV3 aUsdPriceAggregator = new MockAggregatorV3(8, "A-Usd", 1);
        usdPriceFeedManager.setAsset(tokenA, 8, aUsdPriceAggregator, true);
        initialAmount = 1_11111111;

        aUsdPriceAggregator.pushAnswer(11111_11111111);
        usdAmount = usdPriceFeedManager.assetToUsd(tokenA, initialAmount);
        finalAmount = usdPriceFeedManager.usdToAsset(tokenA, usdAmount);
        assertEq(finalAmount, initialAmount);

        aUsdPriceAggregator.pushAnswer(1_11111111);
        usdAmount = usdPriceFeedManager.assetToUsd(tokenA, initialAmount);
        finalAmount = usdPriceFeedManager.usdToAsset(tokenA, usdAmount);
        assertEq(finalAmount, initialAmount);

        aUsdPriceAggregator.pushAnswer(111111);
        usdAmount = usdPriceFeedManager.assetToUsd(tokenA, initialAmount);
        finalAmount = usdPriceFeedManager.usdToAsset(tokenA, usdAmount);
        assertEq(finalAmount, initialAmount);

        // token B
        address tokenB = address(0xb);
        MockAggregatorV3 bUsdPriceAggregator = new MockAggregatorV3(8, "B-Usd", 1);
        usdPriceFeedManager.setAsset(tokenB, 18, bUsdPriceAggregator, true);
        initialAmount = 1_111111111111111111;

        bUsdPriceAggregator.pushAnswer(11111_11111111);
        usdAmount = usdPriceFeedManager.assetToUsd(tokenB, initialAmount);
        finalAmount = usdPriceFeedManager.usdToAsset(tokenB, usdAmount);
        assertEq(finalAmount, initialAmount - 1);

        bUsdPriceAggregator.pushAnswer(1_11111111);
        usdAmount = usdPriceFeedManager.assetToUsd(tokenB, initialAmount);
        finalAmount = usdPriceFeedManager.usdToAsset(tokenB, usdAmount);
        assertEq(finalAmount, initialAmount - 1);

        bUsdPriceAggregator.pushAnswer(111111); // $0.001 / token
        usdAmount = usdPriceFeedManager.assetToUsd(tokenB, initialAmount);
        finalAmount = usdPriceFeedManager.usdToAsset(tokenB, usdAmount);
        assertEq(finalAmount, initialAmount - 600);

        // token C
        address tokenC = address(0xc);
        MockAggregatorV3 cUsdPriceAggregator = new MockAggregatorV3(18, "C-Usd", 1);
        usdPriceFeedManager.setAsset(tokenC, 8, cUsdPriceAggregator, true);
        initialAmount = 1_11111111;

        cUsdPriceAggregator.pushAnswer(11111_111111111111111111);
        usdAmount = usdPriceFeedManager.assetToUsd(tokenC, initialAmount);
        finalAmount = usdPriceFeedManager.usdToAsset(tokenC, usdAmount);
        assertEq(finalAmount, initialAmount - 1);

        cUsdPriceAggregator.pushAnswer(1_111111111111111111);
        usdAmount = usdPriceFeedManager.assetToUsd(tokenC, initialAmount);
        finalAmount = usdPriceFeedManager.usdToAsset(tokenC, usdAmount);
        assertEq(finalAmount, initialAmount - 1);

        cUsdPriceAggregator.pushAnswer(1111111111111111); // $0.001 / token
        usdAmount = usdPriceFeedManager.assetToUsd(tokenC, initialAmount);
        finalAmount = usdPriceFeedManager.usdToAsset(tokenC, usdAmount);
        assertEq(finalAmount, initialAmount - 1);

        // token D
        address tokenD = address(0xc);
        MockAggregatorV3 dUsdPriceAggregator = new MockAggregatorV3(18, "D-Usd", 1);
        usdPriceFeedManager.setAsset(tokenD, 18, dUsdPriceAggregator, true);
        initialAmount = 1_111111111111111111;

        dUsdPriceAggregator.pushAnswer(11111_111111111111111111);
        usdAmount = usdPriceFeedManager.assetToUsd(tokenD, initialAmount);
        finalAmount = usdPriceFeedManager.usdToAsset(tokenD, usdAmount);
        assertEq(finalAmount, initialAmount - 1);

        dUsdPriceAggregator.pushAnswer(1_111111111111111111);
        usdAmount = usdPriceFeedManager.assetToUsd(tokenD, initialAmount);
        finalAmount = usdPriceFeedManager.usdToAsset(tokenD, usdAmount);
        assertEq(finalAmount, initialAmount - 1);

        dUsdPriceAggregator.pushAnswer(1111111111111111); // $0.001 / token
        usdAmount = usdPriceFeedManager.assetToUsd(tokenD, initialAmount);
        finalAmount = usdPriceFeedManager.usdToAsset(tokenD, usdAmount);
        assertEq(finalAmount, initialAmount - 700);
    }
}
