// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../../contracts/strategies/lbf/venus/VenusStatistics.sol";
import "../../../contracts/SwapGateway.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

contract VenusStatisticsBNBTest is Test {
    address controller = 0xfD36E2c2a6789Db23113685031d7F16329158384;
    address pancakeRouter = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address BLID = 0x766AFcf83Fd5eaf884B3d529b432CA27A6d84617;
    address USDT = 0x55d398326f99059fF775485246999027B3197955;
    address vUSDT = 0xfD5840Cd36d94D7229439859C0112a4185BC0255;

    uint256 private mainnetFork;

    VenusStatistics public analytics;
    SwapGateway public swapGateway;

    uint256 private constant BLOCK_NUMBER = 29_953_850;

    function setUp() public {
        mainnetFork = vm.createSelectFork(vm.rpcUrl("bsc"), BLOCK_NUMBER);

        swapGateway = new SwapGateway();
        swapGateway.__SwapGateway_init();
        swapGateway.addSwapRouter(pancakeRouter, 2);

        analytics = new VenusStatistics();
        analytics.__StrategyStatistics_init();
        analytics.setSwapGateway(address(swapGateway));

        analytics.setBLID(BLID);

        address[] memory pathBLIDUSDT = new address[](2);
        pathBLIDUSDT[0] = BLID;
        pathBLIDUSDT[1] = USDT;
        analytics.setBLIDSwap(pancakeRouter, pathBLIDUSDT);

        analytics.setPriceOracle(
            0x55d398326f99059fF775485246999027B3197955,
            0xB97Ad0E74fa7d920791E90258A6E2085088b4320
        ); // USDT
    }

    function testGetXTokensInfo() public {
        XTokenAnalytics[] memory xTokensInfo = analytics.getXTokensInfo(
            controller
        );

        assertEq(xTokensInfo.length, 29);
    }

    function testGetXTokenInfo() public {
        XTokenAnalytics memory xTokenInfo = analytics.getXTokenInfo(
            vUSDT,
            controller
        );

        assertEq(xTokenInfo.platformAddress, vUSDT);
        assertEq(xTokenInfo.symbol, "vUSDT");
        assertEq(xTokenInfo.underlyingAddress, USDT);
        assertEq(xTokenInfo.underlyingSymbol, "USDT");
        assertEq(xTokenInfo.totalSupply, 291472961936334465453665586);
        assertEq(xTokenInfo.totalBorrows, 203778168479841544333080101);
        assertEq(xTokenInfo.collateralFactor, 800000000000000000);
        assertEq(xTokenInfo.borrowApy, 35573047147149698);
        assertEq(xTokenInfo.supplyApy, 22238374155197869);
        assertEq(xTokenInfo.underlyingPrice, 1000310000000000000);
        assertEq(xTokenInfo.liquidity, 87753385702117575811268108);
        assertEq(xTokenInfo.totalSupplyUSD, 291563318554534729137956222);
        assertEq(xTokenInfo.totalBorrowsUSD, 203841339712070295211823355);
        assertEq(xTokenInfo.borrowRewardsApy, 677447620958018);
        assertEq(xTokenInfo.supplyRewardsApy, 473577406524972);
    }
}
