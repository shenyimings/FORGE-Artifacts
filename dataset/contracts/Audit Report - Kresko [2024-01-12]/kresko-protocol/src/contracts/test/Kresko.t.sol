// solhint-disable state-visibility, max-states-count, var-name-mixedcase, no-global-import, const-name-snakecase, no-empty-blocks, no-console
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {TestBase} from "kresko-lib/utils/TestBase.t.sol";
import {ShortAssert} from "kresko-lib/utils/ShortAssert.sol";
import {Strings} from "libs/Strings.sol";
import {PercentageMath} from "libs/PercentageMath.sol";
import {KreskoForgeUtils} from "scripts/utils/KreskoForgeUtils.s.sol";
import {Asset} from "common/Types.sol";
import {console2} from "forge-std/Console2.sol";

// solhint-disable
contract KreskoTest is TestBase("MNEMONIC_TESTNET"), KreskoForgeUtils {
    using ShortAssert for *;
    using Strings for uint256;
    using PercentageMath for uint256;

    MockTokenInfo internal usdc;
    KrAssetInfo internal krETH;
    KrAssetInfo internal krJPY;
    KrAssetInfo internal KISS;

    string internal usdcPrice = "USDC:1:8";
    string internal ethPrice = "ETH:2000:8";
    string internal jpyPrice = "JPY:1:8";
    string internal kissPrice = "KISS:1:8";
    string internal initialPrices = "USDC:1:8,ETH:2000:8,JPY:1:8,KISS:1:8";

    function setUp() public users(address(111), address(222), address(333)) {
        deployCfg = CoreConfig({
            admin: TEST_ADMIN,
            seqFeed: getMockSeqFeed(),
            minterMcr: 150e2,
            minterLt: 140e2,
            scdpMcr: 200e2,
            scdpLt: 150e2,
            sdiPrecision: 8,
            oraclePrecision: 8,
            staleTime: 86401,
            council: getMockSafe(TEST_ADMIN),
            treasury: TEST_TREASURY
        });
        vm.startPrank(deployCfg.admin);
        factory = deployDeploymentFactory(TEST_ADMIN);
        kresko = deployDiamond(deployCfg);
        vm.warp(3601);

        usdc = mockCollateral(
            bytes32("USDC"),
            MockConfig({symbol: "USDC", price: 1e8, setFeeds: true, dec: 18, feedDec: 8}),
            kr_full
        );

        krETH = mockKrAsset(
            bytes32("ETH"),
            address(0),
            MockConfig({symbol: "krETH", price: 2000e8, setFeeds: true, dec: 18, feedDec: 8}),
            kr_default,
            deployCfg
        );

        KISS = mockKrAsset(
            bytes32("KISS"),
            address(0),
            MockConfig({symbol: "KISS", price: 1e8, setFeeds: true, dec: 18, feedDec: 8}),
            kiss_default,
            deployCfg
        );
        krJPY = mockKrAsset(
            bytes32("JPY"),
            address(0),
            MockConfig({symbol: "krJPY", price: 1e8, setFeeds: true, dec: 18, feedDec: 8}),
            kr_default,
            deployCfg
        );

        enableSwapBothWays(usdc.addr, krETH.addr, true);
        enableSwapSingleWay(krJPY.addr, krETH.addr, true);

        vm.stopPrank();
    }

    function testSetup() public {
        kresko.owner().eq(deployCfg.admin);
        Asset memory usdcConfig = kresko.getAsset(usdc.addr);
        Asset memory krETHConfig = kresko.getAsset(krETH.addr);
        kresko.getMinCollateralRatioMinter().eq(150e2);
        kresko.getParametersSCDP().minCollateralRatio.eq(200e2);
        kresko.getParametersSCDP().liquidationThreshold.eq(150e2);
        usdcConfig.isSharedOrSwappedCollateral.eq(true);
        usdcConfig.isSharedCollateral.eq(true);

        usdcConfig.decimals.eq(usdc.mock.decimals());
        usdcConfig.depositLimitSCDP.eq(type(uint128).max);
        usdcConfig.liquidityIndexSCDP.eq(1e27);

        krETHConfig.isMinterMintable.eq(true);
        krETHConfig.isSwapMintable.eq(true);
        krETHConfig.liqIncentiveSCDP.eq(110e2);
        krETHConfig.openFee.eq(2e2);
        krETHConfig.closeFee.eq(2e2);
        krETHConfig.maxDebtMinter.eq(type(uint128).max);
        krETHConfig.protocolFeeShareSCDP.eq(25e2);

        kresko.getSwapEnabledSCDP(usdc.addr, krETH.addr).eq(true);
        kresko.getSwapEnabledSCDP(krETH.addr, usdc.addr).eq(true);
        kresko.getSwapEnabledSCDP(krJPY.addr, krETH.addr).eq(true);

        kresko.getSwapEnabledSCDP(krETH.addr, krJPY.addr).eq(false);
        kresko.getSwapEnabledSCDP(krJPY.addr, usdc.addr).eq(false);
        kresko.getSwapEnabledSCDP(usdc.addr, krJPY.addr).eq(false);
    }

    function testDeposit() public prankedAddr(user0) {
        uint256 depositAmount = 100e18;

        usdc.mock.mint(user0, depositAmount);
        usdc.mock.approve(address(kresko), depositAmount);

        kresko.depositCollateral(user0, usdc.addr, depositAmount);
        kresko.getAccountCollateralAmount(user0, usdc.addr).eq(depositAmount);

        staticCall(kresko.getAccountTotalCollateralValue.selector, user0, usdcPrice).eq(100e8);
    }

    function testMint() public prankedAddr(user0) {
        uint256 depositAmount = 1000e18;
        uint256 mintAmount = 100e18;

        usdc.mock.mint(user0, depositAmount);
        usdc.mock.approve(address(kresko), depositAmount);

        kresko.depositCollateral(user0, usdc.addr, depositAmount);
        kresko.getAccountCollateralAmount(user0, usdc.addr).eq(depositAmount);

        call(kresko.mintKreskoAsset.selector, user0, krJPY.addr, mintAmount, initialPrices);
        staticCall(kresko.getAccountTotalCollateralValue.selector, user0, usdcPrice).eq(998e8);
        staticCall(kresko.getAccountTotalDebtValue.selector, user0, initialPrices).eq(120e8);
    }

    function testBurn() public prankedAddr(user0) {
        uint256 depositAmount = 1000e18;
        uint256 mintAmount = 100e18;

        usdc.mock.mint(user0, depositAmount);
        usdc.mock.approve(address(kresko), depositAmount);

        kresko.depositCollateral(user0, usdc.addr, depositAmount);
        kresko.getAccountCollateralAmount(user0, usdc.addr).eq(depositAmount);

        call(kresko.mintKreskoAsset.selector, user0, krJPY.addr, mintAmount, initialPrices);
        call(kresko.burnKreskoAsset.selector, user0, krJPY.addr, mintAmount, 0, initialPrices);
        staticCall(kresko.getAccountTotalCollateralValue.selector, user0, usdcPrice).eq(996e8);
        staticCall(kresko.getAccountTotalDebtValue.selector, user0, initialPrices).eq(0);
    }

    function testWithdraw() public prankedAddr(user0) {
        uint256 depositAmount = 1000e18;
        uint256 mintAmount = 100e18;

        usdc.mock.mint(user0, depositAmount);
        usdc.mock.approve(address(kresko), depositAmount);

        kresko.depositCollateral(user0, usdc.addr, depositAmount);
        kresko.getAccountCollateralAmount(user0, usdc.addr).eq(depositAmount);

        call(kresko.mintKreskoAsset.selector, user0, krJPY.addr, mintAmount, initialPrices);
        call(kresko.burnKreskoAsset.selector, user0, krJPY.addr, mintAmount, 0, initialPrices);
        call(kresko.withdrawCollateral.selector, user0, usdc.addr, 998e18, 0, initialPrices);

        staticCall(kresko.getAccountTotalCollateralValue.selector, user0, usdcPrice).eq(0);
        staticCall(kresko.getAccountTotalDebtValue.selector, user0, initialPrices).eq(0);
    }

    function testGas() public prankedAddr(user0) {
        uint256 depositAmount = 1000e18;
        uint256 mintAmount = 100e18;
        bytes memory redstonePayload = getRedstonePayload(initialPrices);
        bool success;

        usdc.mock.mint(user0, depositAmount);
        usdc.mock.approve(address(kresko), depositAmount);

        uint256 gasDeposit = gasleft();
        kresko.depositCollateral(user0, usdc.addr, depositAmount);
        console2.log("gasDepositCollateral", gasDeposit - gasleft());

        bytes memory mintData = abi.encodePacked(
            abi.encodeWithSelector(kresko.mintKreskoAsset.selector, user0, krJPY.addr, mintAmount),
            redstonePayload
        );
        uint256 gasMint = gasleft();
        (success, ) = address(kresko).call(mintData);
        console2.log("gasMintKreskoAsset", gasMint - gasleft());
        require(success, "!success");

        bytes memory burnData = abi.encodePacked(
            abi.encodeWithSelector(kresko.burnKreskoAsset.selector, user0, krJPY.addr, mintAmount, 0),
            redstonePayload
        );
        uint256 gasBurn = gasleft();
        (success, ) = address(kresko).call(burnData);
        console2.log("gasBurnKreskoAsset", gasBurn - gasleft());
        require(success, "!success");

        bytes memory withdrawData = abi.encodePacked(
            abi.encodeWithSelector(kresko.withdrawCollateral.selector, user0, usdc.addr, 998e18, 0),
            redstonePayload
        );
        uint256 gasWithdraw = gasleft();
        (success, ) = address(kresko).call(withdrawData);
        console2.log("gasWithdrawCollateral", gasWithdraw - gasleft());
        require(success, "!success");
    }
}
