// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../../contracts/strategies/lbl/ola/OlaStatistics.sol";
import "../../../contracts/SwapGateway.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

contract OlaStatisticsBNBTest is Test {
    address controller = 0xAD48B2C9DC6709a560018c678e918253a65df86e;
    address pancakeRouter = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address BLID = 0x32Ee7c89D689CE87cB3419fD0F184dc6881Ab3C7;
    address USDT = 0x55d398326f99059fF775485246999027B3197955;
    address oUSDT = 0xdBFd516D42743CA3f1C555311F7846095D85F6Fd;
    address oBNB = 0x34878F6a484005AA90E7188a546Ea9E52b538F6f;

    uint256 private mainnetFork;

    OlaStatistics public analytics;
    SwapGateway public swapGateway;

    uint256 private constant BLOCK_NUMBER = 27_050_910;

    function setUp() public {
        mainnetFork = vm.createSelectFork(vm.rpcUrl("bsc"), BLOCK_NUMBER);

        swapGateway = new SwapGateway();
        swapGateway.__SwapGateway_init();
        swapGateway.addSwapRouter(pancakeRouter, 2);

        analytics = new OlaStatistics();
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

        assertEq(xTokensInfo.length, 10);
    }

    function testGetXTokenInfo() public view {
        XTokenAnalytics memory xTokenInfo = analytics.getXTokenInfo(
            oBNB,
            controller
        );
    }
}
