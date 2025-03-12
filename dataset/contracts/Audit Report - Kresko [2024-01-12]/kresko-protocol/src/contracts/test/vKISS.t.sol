// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IAggregatorV3} from "kresko-lib/vendor/IAggregatorV3.sol";
import {ERC20} from "kresko-lib/token/ERC20.sol";
import {Test} from "forge-std/Test.sol";
import {MockOracle} from "mocks/MockOracle.sol";
import {MockERC20, USDC, USDT, DAI} from "mocks/MockERC20.sol";
import {MockSequencerUptimeFeed} from "mocks/MockSequencerUptimeFeed.sol";

import {VaultAsset} from "vault/VTypes.sol";
import {Vault} from "vault/Vault.sol";

// solhint-disable private-vars-leading-underscore
// solhint-disable contract-name-camelcase
// solhint-disable max-states-count

contract vKISSTest is Test {
    Vault public vkiss;
    MockERC20 public usdc;
    MockERC20 public dai;
    MockERC20 public usdt;

    MockOracle public usdcOracle;
    MockOracle public daiOracle;
    MockOracle public usdtOracle;

    address internal user4 = address(44444);
    address internal user3 = address(33333);

    address internal user2 = 0xB48bB6b68Ab4D366B4f9A30eE6f7Ee55125c2D9d;
    address internal user1 = 0xfff57D31b6d007e2de2ef602F66Bc2C2B757bB42;
    address internal user0 = 0xfffff4Fc02030b28d5CdD7F9073307B2bd7c436F;
    address internal liquidator = 0x361Bae08CDd251b022889d8eA9fb8ddb84012516;
    address internal feeRecipient = address(0xFEE);

    address internal usdcAddr;
    address internal daiAddr;
    address internal usdtAddr;

    modifier with(address user) {
        vm.startPrank(user);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        vm.startPrank(user0);

        // Create a vault
        vkiss = new Vault("vKISS", "vKISS", 18, 8, feeRecipient, address(new MockSequencerUptimeFeed()));
        vm.warp(3602);

        // tokens
        usdc = new USDC();
        dai = new DAI();
        usdt = new USDT();
        usdcAddr = address(usdc);
        daiAddr = address(dai);
        usdtAddr = address(usdt);

        // oracles
        usdcOracle = new MockOracle("USDC/USD", 1e8, 8);
        daiOracle = new MockOracle("DAI/USD", 1e8, 8);
        usdtOracle = new MockOracle("USDT/USD", 1e8, 8);

        // add assets
        vkiss.addAsset(
            VaultAsset(ERC20(usdcAddr), IAggregatorV3(address(usdcOracle)), 80000, 0, 0, 0, type(uint248).max, true)
        );
        vkiss.addAsset(VaultAsset(ERC20(daiAddr), IAggregatorV3(address(daiOracle)), 80000, 0, 0, 0, type(uint248).max, true));
        vkiss.addAsset(
            VaultAsset(ERC20(usdtAddr), IAggregatorV3(address(usdtOracle)), 80000, 0, 0, 0, type(uint248).max, true)
        );
        vm.stopPrank();

        // approvals
        init();
    }

    function testDepositsSingleToken() public {
        deposit(user1, usdc, 1e18);
        assertEq(usdc.balanceOf(address(vkiss)), 1e18);
        assertEq(vkiss.balanceOf(user1), 1e18);
    }

    function testDepositsMultiToken() public {
        deposit(user1, usdc, 1e18);
        deposit(user1, usdt, 1e6);
        deposit(user1, dai, 1e18);
        assertEq(usdc.balanceOf(address(vkiss)), 1e18);
        assertEq(usdt.balanceOf(address(vkiss)), 1e6);
        assertEq(dai.balanceOf(address(vkiss)), 1e18);
        assertEq(vkiss.balanceOf(user1), 3e18);
    }

    function testRedeemSingleToken() public {
        assertEq(deposit(user1, usdc, 1e18), 1e18);
        assertEq(maxRedeem(user1, usdc), 1e18);
        assertEq(usdc.balanceOf(user1), 1e18);
        assertEq(vkiss.balanceOf(address(vkiss)), 0);
        assertEq(vkiss.balanceOf(user1), 0);
    }

    function testRedeemMultiToken() public {
        deposit(user1, usdc, 1e18);
        deposit(user1, usdt, 1e6);
        deposit(user1, dai, 1e18);

        assertEq(redeem(user1, usdc, 1e18), 1e18);
        assertEq(redeem(user1, usdt, 1e18), 1e6);
        assertEq(redeem(user1, dai, 1e18), 1e18);

        assertEq(usdc.balanceOf(user1), 1e18);
        assertEq(usdt.balanceOf(user1), 1e6);
        assertEq(dai.balanceOf(user1), 1e18);
        assertEq(vkiss.balanceOf(user1), 0);
        assertEq(vkiss.totalSupply(), 0);
        assertEq(vkiss.totalAssets(), 0);
    }

    function testMaxRedeem() public {
        deposit(user1, usdc, 1e18);
        deposit(user1, usdt, 1e6);
        deposit(user1, dai, 1e18);

        assertEq(maxRedeem(user1, usdc), 1e18);
        assertEq(maxRedeem(user1, usdt), 1e6);
        assertEq(maxRedeem(user1, dai), 1e18);

        assertEq(usdc.balanceOf(user1), 1e18);
        assertEq(usdt.balanceOf(user1), 1e6);
        assertEq(dai.balanceOf(user1), 1e18);

        assertEq(vkiss.balanceOf(user1), 0);
        assertEq(vkiss.totalSupply(), 0);
        assertEq(vkiss.totalAssets(), 0);
    }

    function testMaxWithdraw() public {
        deposit(user1, usdc, 1e18);
        deposit(user1, usdt, 1e6);
        deposit(user1, dai, 1e18);

        assertEq(maxWithdraw(user1, usdc), 1e18);
        assertEq(maxWithdraw(user1, usdt), 1e18); // shares in, not token amount
        assertEq(maxWithdraw(user1, dai), 1e18);

        assertEq(usdc.balanceOf(user1), 1e18);
        assertEq(usdt.balanceOf(user1), 1e6);
        assertEq(dai.balanceOf(user1), 1e18);

        assertEq(vkiss.balanceOf(user1), 0);
        assertEq(vkiss.totalSupply(), 0);
        assertEq(vkiss.totalAssets(), 0);
    }

    function testDepositFeePreview() public {
        vm.startPrank(user0);
        vkiss.setDepositFee(address(usdc), 0.25e4);
        vm.stopPrank();

        (uint256 kissOut, uint256 fee) = vkiss.previewDeposit(address(usdc), 1e18);
        assertEq(fee, 0.25e18, "fee should be 50%");
        assertEq(kissOut, 0.75e18, "kiss should be 50%");
    }

    function testDepositFee() public {
        vm.startPrank(user0);
        vkiss.setDepositFee(address(usdc), 0.25e4);
        vm.stopPrank();

        usdc.mint(user1, 1e18);

        vm.startPrank(user1);
        (uint256 kissOut, uint256 fee) = vkiss.deposit(address(usdc), 1e18, user1);
        vm.stopPrank();

        assertEq(fee, 0.25e18, "fee should be equal to percentage");
        assertEq(kissOut, 0.75e18, "kiss out should be reduced according to fees");
        assertEq(vkiss.balanceOf(user1), 0.75e18, "kiss balance should equal kissOut");
        assertEq(vkiss.exchangeRate(), 1e18, "kiss price should be 1 regardless of fees");
        assertEq(usdc.balanceOf(feeRecipient), 0.25e18, "fee recipient should have some");
    }

    function testMintFeePreview() public {
        vm.startPrank(user0);
        vkiss.setDepositFee(address(usdc), 0.25e4);
        vm.stopPrank();

        (uint256 assetsIn, uint256 fee) = vkiss.previewMint(address(usdc), 1e18);
        assertEq(fee, 0.333333333333333333e18, "fee should match fee percentage");
        assertEq(assetsIn, 1.333333333333333333e18, "assets in should be mint requested times fee");
    }

    function testMintFee() public {
        vm.startPrank(user0);
        vkiss.setDepositFee(address(usdc), 0.25e4);
        vm.stopPrank();

        usdc.mint(user1, 1.333333333333333333e18);

        vm.startPrank(user1);
        (uint256 assetsIn, uint256 fee) = vkiss.mint(address(usdc), 1e18, user1);
        vm.stopPrank();

        assertEq(fee, 0.333333333333333333e18, "fee should be equal to percentage");
        assertEq(assetsIn, 1.333333333333333333e18, "kiss out should be greater than mint requested times fee");
        assertEq(vkiss.exchangeRate(), 1e18, "kiss price should be 1 regardless of fees");
        assertEq(usdc.balanceOf(feeRecipient), 0.333333333333333333e18, "fee recipient should have some USDC");
        assertEq(usdc.balanceOf(address(vkiss)), 1e18, "vkiss should have 1 USDC");
    }

    function testWithdrawFeePreview() public {
        deposit(user1, usdc, 2e18);
        vm.startPrank(user0);
        vkiss.setWithdrawFee(address(usdc), 0.25e4);
        vm.stopPrank();
        uint256 expectedFee = 0.333333333333333333e18;
        (uint256 sharesIn, uint256 fee) = vkiss.previewWithdraw(address(usdc), 1e18);
        assertEq(fee, expectedFee, "fee should be equal to percentage");
        assertEq(sharesIn, 1e18 + expectedFee, "assets in should be adjusted by fees");
    }

    function testCannotDeposit0() public {
        vm.startPrank(user1);
        vm.expectRevert();
        vkiss.deposit(address(usdc), 0, user1);
        vm.stopPrank();
    }

    function testCannotMint0() public {
        vm.startPrank(user1);
        vm.expectRevert();
        vkiss.mint(address(usdc), 0, user1);
        vm.stopPrank();
    }

    function testCannotWithdraw0() public {
        deposit(user1, usdc, 1e18);
        vm.startPrank(user1);
        vm.expectRevert();
        vkiss.withdraw(address(usdc), 0, user1, user1);
        vm.stopPrank();
    }

    function testCannotRedeem() public {
        deposit(user1, usdc, 1e18);
        vm.startPrank(user1);
        vm.expectRevert();
        vkiss.redeem(address(usdc), 0, user1, user1);
        vm.stopPrank();
    }

    function testCanWithdrawRounding() public {
        vm.startPrank(user0);
        vkiss.setWithdrawFee(address(usdc), 0.25e4);
        vm.stopPrank();
        uint256 expectedFee = 0.333333333333333333e18;
        deposit(user1, usdc, 1e18 + expectedFee);

        vm.startPrank(user1);
        (uint256 sharesIn, uint256 fee) = vkiss.withdraw(address(usdc), 1e18, user1, user1);
        vm.stopPrank();
        assertEq(sharesIn, 1e18 + expectedFee, "assets in should equal full amount");
        assertEq(fee, expectedFee, "fee should be equal to percentage");
    }

    function testCanRedeemRounding() public {
        vm.startPrank(user0);
        vkiss.setWithdrawFee(address(usdc), 0.25e4);
        vm.stopPrank();
        uint256 expectedFee = 0.333333333333333333e18;
        deposit(user1, usdc, 1e18 + expectedFee);

        vm.startPrank(user1);
        (uint256 assetsOut, uint256 fee) = vkiss.redeem(address(usdc), 1e18 + expectedFee, user1, user1);
        vm.stopPrank();
        assertEq(fee, expectedFee, "fee should be equal to percentage");
        assertEq(assetsOut, 1e18, "assets in should be adjusted by fees");
    }

    function testWithdrawFee() public {
        uint256 expectedFee = 0.5e18;
        deposit(user1, usdc, 2e18);

        vm.startPrank(user0);
        vkiss.setWithdrawFee(address(usdc), 0.25e4);
        vm.stopPrank();

        vm.startPrank(user1);
        (uint256 sharesIn, uint256 fee) = vkiss.withdraw(address(usdc), 1.5e18, user1, user1);
        vm.stopPrank();

        assertEq(fee, expectedFee, "fee should be equal to percentage");

        assertEq(sharesIn, 2e18, "kiss required should be greater than withdrawal amount requested times fee");
        assertEq(vkiss.exchangeRate(), 1e18, "kiss price should be 1 regardless of fees");
        assertEq(usdc.balanceOf(user1), 1.5e18, "user should have some USDC");
        assertEq(usdc.balanceOf(feeRecipient), expectedFee, "fee recipient should have some USDC");
        assertEq(usdc.balanceOf(address(vkiss)), 0, "vkiss should have 0 USDC");
        assertEq(vkiss.totalSupply(), 0, "vkiss should have 0 USDC");
    }

    function testRedeemFeePreview() public {
        vm.startPrank(user0);
        vkiss.setWithdrawFee(address(usdc), 0.25e4);
        vm.stopPrank();

        (uint256 assetsOut, uint256 fee) = vkiss.previewRedeem(address(usdc), 1e18);
        assertEq(fee, 0.25e18, "fee should be equal to percentage");
        assertEq(assetsOut, 0.75e18, "assets out should be less than shares requested");
    }

    function testRedeemFee() public {
        deposit(user1, usdc, 1e18);

        vm.startPrank(user0);
        vkiss.setWithdrawFee(address(usdc), 0.25e4);
        vm.stopPrank();

        vm.startPrank(user1);
        (uint256 assetsOut, uint256 fee) = vkiss.redeem(address(usdc), 1e18, user1, user1);
        vm.stopPrank();

        assertEq(fee, 0.25e18, "fee should be equal to percentage");
        assertEq(assetsOut, 0.75e18, "assetsOut should be less than shares burned");
        assertEq(usdc.balanceOf(user1), 0.75e18, "usdc balance should be equal to assetsOut");
        assertEq(vkiss.exchangeRate(), 1e18, "kiss price should be 1 regardless of fees");
        assertEq(usdc.balanceOf(feeRecipient), 0.25e18, "fee recipient should have some USDC");
        assertEq(usdc.balanceOf(address(vkiss)), 0, "vkiss should have 0 USDC");
        assertEq(vkiss.totalSupply(), 0, "vkiss should have 0 USDC");
    }

    function testDepositWithdrawFee() public {
        vm.startPrank(user0);
        vkiss.setWithdrawFee(address(usdc), 0.25e4);
        vkiss.setDepositFee(address(usdc), 0.25e4);
        vm.stopPrank();

        uint256 kissOut = deposit(user1, usdc, 1e18);

        assertEq(kissOut, 0.75e18);

        vm.startPrank(user1);
        (uint256 assetsOut, ) = vkiss.redeem(address(usdc), kissOut, user1, user1);
        vm.stopPrank();
        uint256 expectedAssetsOut = 0.5625e18;
        assertEq(assetsOut, expectedAssetsOut, "assetsOut should be reduced by both fees");

        // assertEq(fee, 0.25e18, "fee should be equal to percentage");
        assertEq(usdc.balanceOf(user1), assetsOut, "usdc balance should be equal to assetsOut");
        assertEq(vkiss.exchangeRate(), 1e18, "kiss price should be 1 regardless of fees");
        assertEq(usdc.balanceOf(feeRecipient), 1e18 - expectedAssetsOut, "fee recipient should have some USDC");
        assertEq(usdc.balanceOf(address(vkiss)), 0, "vkiss should have 0 USDC");
        assertEq(vkiss.totalSupply(), 0, "vkiss should have 0 USDC");
    }

    function testMintRedeemFee() public {
        vm.startPrank(user0);
        vkiss.setWithdrawFee(address(usdc), 0.25e4);
        vkiss.setDepositFee(address(usdc), 0.25e4);
        usdc.mint(user1, 1.333333333333333333e18);
        vm.stopPrank();

        vm.startPrank(user1);

        uint256 expectedMintFee = 0.333333333333333333e18;
        uint256 expectedRedeemFee = 0.25e18;
        (uint256 assetsIn, uint256 feeMint) = vkiss.mint(address(usdc), 1e18, user1);
        assertEq(assetsIn, 1e18 + expectedMintFee);

        assertEq(feeMint, expectedMintFee, "mintFee should be equal to percentage");

        (uint256 assetsOut, uint256 feeRedeem) = vkiss.redeem(address(usdc), 1e18, user1, user1);
        vm.stopPrank();

        uint256 expectedAssetsOut = 1e18 - expectedRedeemFee;
        assertEq(assetsOut, expectedAssetsOut, "assetsOut should be reduced by both fees");

        assertEq(feeRedeem, expectedRedeemFee, "redeemFee should be equal to percentage");
        assertEq(usdc.balanceOf(user1), assetsOut, "usdc balance should be equal to assetsOut");
        assertEq(vkiss.exchangeRate(), 1e18, "kiss price should be 1 regardless of fees");
        assertEq(usdc.balanceOf(feeRecipient), feeRedeem + expectedMintFee, "fee recipient should have some USDC");
        assertEq(usdc.balanceOf(address(vkiss)), 0, "vkiss should have 0 USDC");
        assertEq(vkiss.totalSupply(), 0, "vkiss should have 0 USDC");
    }

    function testDepositMintPreviewFee() public {
        vm.startPrank(user0);
        vkiss.setWithdrawFee(address(usdc), 0.25e4);
        vkiss.setDepositFee(address(usdc), 0.25e4);
        vm.stopPrank();
        uint256 kissOut = 1e18;
        (uint256 assetsIn, uint256 mintFee) = vkiss.previewMint(address(usdc), kissOut);

        (uint256 sharesOut, uint256 depositFee) = vkiss.previewDeposit(address(usdc), assetsIn);
        assertEq(sharesOut, kissOut, "kissOut should be same as sharesOut");
        assertEq(depositFee, mintFee, "depositFee should be same as mintFee");
        assertEq(assetsIn, sharesOut + depositFee, "depositFee should be same as mintFee");
    }

    function testDepositRedeemFee() public {
        vm.startPrank(user0);
        vkiss.setWithdrawFee(address(usdc), 0.25e4);
        vkiss.setDepositFee(address(usdc), 0.25e4);
        usdc.mint(user1, 1.333333333333333333e18);
        vm.stopPrank();

        vm.startPrank(user1);

        uint256 expectedDepositFee = 0.333333333333333333e18;
        uint256 expectedRedeemFee = 0.25e18;

        uint256 depositAmount = 1e18 + expectedDepositFee;

        (uint256 sharesOut, uint256 feeDeposit) = vkiss.deposit(address(usdc), depositAmount, user1);
        assertEq(sharesOut, 1 ether, "sharesOut should be 1 ether");
        assertEq(feeDeposit, expectedDepositFee, "feeDeposit should equal expected");
        (uint256 assetsOut, uint256 feeRedeem) = vkiss.redeem(address(usdc), sharesOut, user1, user1);

        vm.stopPrank();
        assertEq(feeRedeem, expectedRedeemFee, "redeem fee not correct");
        uint256 expectedAssetsOut = depositAmount - feeDeposit - feeRedeem;
        assertEq(assetsOut, expectedAssetsOut, "assetsOut should be reduced by both fees");

        assertEq(usdc.balanceOf(user1), assetsOut, "usdc balance should be equal to assetsOut");
        assertEq(vkiss.exchangeRate(), 1e18, "kiss price should be 1 regardless of fees");
        assertEq(usdc.balanceOf(feeRecipient), feeDeposit + feeRedeem, "fee recipient should have some USDC");
        assertEq(usdc.balanceOf(address(vkiss)), 0, "vkiss should have 0 USDC");
        assertEq(vkiss.totalSupply(), 0, "vkiss should have 0 USDC");
    }

    function testWithdrawMultiToken() public {
        deposit(user1, usdc, 1e18);
        deposit(user1, usdt, 1e6);
        deposit(user1, dai, 1e18);

        assertEq(withdraw(user1, usdc, 1e18), 1e18);
        assertEq(withdraw(user1, usdt, 1e6), 1e18);
        assertEq(withdraw(user1, dai, 1e18), 1e18);

        assertEq(usdc.balanceOf(user1), 1e18);
        assertEq(usdt.balanceOf(user1), 1e6);
        assertEq(dai.balanceOf(user1), 1e18);
        assertEq(vkiss.balanceOf(user1), 0);
    }

    function testDepositAfterPriceDownSameToken() public {
        deposit(user1, usdc, 1e18);
        usdcOracle.setPrice(0.5e8);
        deposit(user2, usdc, 1e18);

        assertEq(vkiss.balanceOf(user1), 1e18);
        assertEq(vkiss.balanceOf(user2), 1e18);
    }

    function testMintAfterPriceDownSameToken() public {
        mint(user1, usdc, 1e18);
        usdcOracle.setPrice(0.5e8);
        mint(user2, usdc, 1e18);

        assertEq(vkiss.balanceOf(user1), 1e18);
        assertEq(vkiss.balanceOf(user2), 1e18);
    }

    function testDepositAfterPriceDownDifferentToken() public {
        deposit(user1, usdc, 1e18);
        usdcOracle.setPrice(0.5e8);
        deposit(user2, usdt, 1e6);

        assertEq(vkiss.balanceOf(user1), 1e18);
        assertEq(vkiss.balanceOf(user2), 2e18);
    }

    function testMintAfterPriceDownDifferentToken() public {
        mint(user1, usdc, 1e18);
        usdcOracle.setPrice(0.5e8);

        mint(user2, usdt, 1e18);

        assertEq(vkiss.balanceOf(user1), 1e18);
        assertEq(vkiss.balanceOf(user2), 1e18);

        assertEq(usdt.balanceOf(user2), 0);
        assertEq(usdt.balanceOf(address(vkiss)), 0.5e6);
    }

    function testRedeemAfterPriceDownSameToken() public {
        deposit(user1, usdc, 1e18);
        usdcOracle.setPrice(0.5e8);
        deposit(user2, usdc, 1e18);

        redeem(user1, usdc, 1e18);
        maxRedeem(user2, usdc);

        assertEq(vkiss.balanceOf(user1), 0);
        assertEq(vkiss.balanceOf(user2), 0);
        assertEq(usdc.balanceOf(user1), 1e18);
        assertEq(usdc.balanceOf(user2), 1e18);
    }

    function testRedeemAfterPriceDownDifferentToken() public {
        deposit(user1, usdc, 1e18);
        usdcOracle.setPrice(0.5e8);
        deposit(user2, usdt, 1e6);
        maxRedeem(user1, usdc);
        maxRedeem(user2, usdt);
        assertEq(vkiss.balanceOf(user1), 0);
        assertEq(vkiss.balanceOf(user2), 0);
        assertEq(usdc.balanceOf(user1), 1e18);
        assertEq(usdt.balanceOf(user2), 1e6);
    }

    function testWithdrawAfterPriceDownDifferentToken() public {
        deposit(user1, usdc, 1e18);
        usdcOracle.setPrice(0.5e8);
        deposit(user2, usdt, 1e6);
        withdraw(user1, usdc, 1e18);
        withdraw(user2, usdt, 1e6);
        assertEq(vkiss.balanceOf(user1), 0);
        assertEq(vkiss.balanceOf(user2), 0);
        assertEq(usdc.balanceOf(user1), 1e18);
        assertEq(usdt.balanceOf(user2), 1e6);
    }

    function testMaxDeposit() public {
        deposit(user1, usdc, 1e18);
        deposit(user1, usdt, 1e6);
        deposit(user1, dai, 1e18);

        assertEq(vkiss.maxDeposit(address(usdc)), type(uint248).max - 1e18);
        assertEq(vkiss.maxDeposit(address(usdt)), type(uint248).max - 1e6);
        assertEq(vkiss.maxDeposit(address(dai)), type(uint248).max - 1e18);
    }

    function testMaxMint() public {
        usdc.mint(user1, 1e18);
        usdt.mint(user1, 2e6);
        dai.mint(user1, 1e18);
        deposit(user1, usdc, 1e18);
        deposit(user1, usdt, 1e6);
        deposit(user1, dai, 1e18);

        assertEq(vkiss.maxMint(address(usdc), user1), 1e18);
        assertEq(vkiss.maxMint(address(usdt), user1), 2e18);
        assertEq(vkiss.maxMint(address(dai), user1), 1e18);
    }

    function testCantDepositOverMaxDeposit() public {
        vm.startPrank(user0);
        uint248 maxDeposits = 1 ether;
        vkiss.setMaxDeposits(address(usdc), maxDeposits);
        uint256 depositAmount = maxDeposits + 1;
        usdc.mint(user1, depositAmount);
        vm.stopPrank();

        vm.startPrank(user1);

        vm.expectRevert();
        vkiss.deposit(address(usdc), depositAmount, user1);

        vm.expectRevert();
        vkiss.mint(address(usdc), depositAmount, user1);
        vm.stopPrank();
    }

    // function testRandom() public {
    //   vm.startPrank(user0);
    //   usdc.mint(user1, 100 ether);
    //   usdt.mint(user2, 100e6);
    //   vm.stopPrank();
    //   deposit(user1, usdc, 100 ether);
    //   deposit(user2, usdt, 100e6);
    //   usdcOracle.setPrice(1.05e8);
    // }

    /* -------------------------------------------------------------------------- */
    /*                                   Helpers                                  */
    /* -------------------------------------------------------------------------- */

    function deposit(address user, MockERC20 asset, uint256 assetsIn) internal with(user) returns (uint256 kissOut) {
        asset.mint(user, assetsIn);
        (kissOut, ) = vkiss.deposit(address(asset), assetsIn, user);
    }

    function mint(address user, MockERC20 asset, uint256 shares) internal with(user) returns (uint256 tokensIn) {
        (uint256 amount, ) = vkiss.previewMint(address(asset), shares);
        asset.mint(user, amount);
        (tokensIn, ) = vkiss.mint(address(asset), shares, user);
    }

    function redeem(address user, MockERC20 asset, uint256 shares) internal with(user) returns (uint256 assetsOut) {
        (assetsOut, ) = vkiss.redeem(address(asset), shares, user, user);
    }

    function maxRedeem(address user, MockERC20 asset) internal with(user) returns (uint256 assetsOut) {
        (assetsOut, ) = vkiss.redeem(address(asset), vkiss.maxRedeem(address(asset), user), user, user);
    }

    function maxWithdraw(address user, MockERC20 asset) internal with(user) returns (uint256 assetsOut) {
        (assetsOut, ) = vkiss.withdraw(address(asset), vkiss.maxWithdraw(address(asset), user), user, user);
    }

    function withdraw(address user, MockERC20 asset, uint256 amount) internal with(user) returns (uint256 kissIn) {
        (kissIn, ) = vkiss.withdraw(address(asset), amount, user, user);
    }

    function init() internal {
        vm.startPrank(user0);
        usdc.approve(address(vkiss), type(uint256).max);
        dai.approve(address(vkiss), type(uint256).max);
        usdt.approve(address(vkiss), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user1);
        usdc.approve(address(vkiss), type(uint256).max);
        dai.approve(address(vkiss), type(uint256).max);
        usdt.approve(address(vkiss), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        usdc.approve(address(vkiss), type(uint256).max);
        dai.approve(address(vkiss), type(uint256).max);
        usdt.approve(address(vkiss), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user3);
        usdc.approve(address(vkiss), type(uint256).max);
        dai.approve(address(vkiss), type(uint256).max);
        usdt.approve(address(vkiss), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user4);
        usdc.approve(address(vkiss), type(uint256).max);
        dai.approve(address(vkiss), type(uint256).max);
        usdt.approve(address(vkiss), type(uint256).max);
        vm.stopPrank();
    }

    function logRatios() internal {
        emit log_named_decimal_uint("exchangeRate", vkiss.exchangeRate(), 18);
        emit log_named_decimal_uint("totalAssets", vkiss.totalAssets(), 18);
        emit log_named_decimal_uint("totalSupply", vkiss.totalSupply(), 18);
    }

    function logBalances(MockERC20 asset, string memory assetName) internal {
        uint256 balUser0 = asset.balanceOf(user0);
        uint256 decimals = ERC20(address(asset)).decimals();
        emit log_named_decimal_uint(string.concat(assetName, "balanceOf(user0)"), balUser0, decimals);

        uint256 balUser1 = asset.balanceOf(user1);
        emit log_named_decimal_uint(string.concat(assetName, "balanceOf(user1)"), balUser1, decimals);

        uint256 balUser2 = asset.balanceOf(user2);
        emit log_named_decimal_uint(string.concat(assetName, "balanceOf(user2)"), balUser2, decimals);
        uint256 balUser3 = asset.balanceOf(user3);
        emit log_named_decimal_uint(string.concat(assetName, "balanceOf(user3)"), balUser3, decimals);
        uint256 balUser4 = asset.balanceOf(user4);
        emit log_named_decimal_uint(string.concat(assetName, "balanceOf(user4)"), balUser4, decimals);
        uint256 balContract = asset.balanceOf(address(vkiss));
        emit log_named_decimal_uint(string.concat(assetName, "balanceOf(vKISS)"), balContract, decimals);
        emit log_named_decimal_uint(
            string.concat(assetName, "balance combined"),
            balContract + balUser0 + balUser1 + balUser2 + balUser3 + balUser4,
            decimals
        );
    }
}
