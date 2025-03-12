// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../../contracts/strategies/lbl/dforce/DForceStatistics.sol";
import "../../../contracts/SwapGateway.sol";

contract DForceStatisticsETHTest is Test {
    address controller = 0x8B53Ab2c0Df3230EA327017C91Eb909f815Ad113;
    address pancakeRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    uint256 private mainnetFork;

    DForceStatistics public analytics;
    SwapGateway public swapGateway;

    uint256 private constant BLOCK_NUMBER = 16_791_459;

    function setUp() public {
        mainnetFork = vm.createSelectFork(vm.rpcUrl("mainnet"), BLOCK_NUMBER);

        swapGateway = new SwapGateway();
        swapGateway.__SwapGateway_init();
        swapGateway.addSwapRouter(pancakeRouter, 2);

        analytics = new DForceStatistics();
        analytics.__StrategyStatistics_init();
        analytics.setSwapGateway(address(swapGateway));
        analytics.setRewardsXToken(0xb3dc7425e63E1855Eb41107134D471DD34d7b239);

        analytics.setPriceOracle(
            0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
            0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c
        ); // WBTC
        analytics.setPriceOracle(
            0x0000000000000000000000000000000000000000,
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        ); // ETH
        analytics.setPriceOracle(
            0xdAC17F958D2ee523a2206206994597C13D831ec7,
            0x3E7d1eAB13ad0104d2750B8863b489D65364e32D
        ); // USDT
        analytics.setPriceOracle(
            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6
        ); // USDC
        analytics.setPriceOracle(
            0x6B175474E89094C44Da98b954EedeAC495271d0F,
            0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9
        ); // DAI
        analytics.setPriceOracle(
            0x4Fabb145d64652a948d72533023f6E7A623C7C53,
            0x833D8Eb16D306ed1FbB5D7A2E019e106B960965A
        ); // BUSD
        analytics.setPriceOracle(
            0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984,
            0x553303d460EE0afB37EdFf9bE42922D8FF63220e
        ); // UNI
        analytics.setPriceOracle(
            0x514910771AF9Ca656af840dff83E8264EcF986CA,
            0x2c1d072e956AFFC0D435Cb7AC38EF18d24d9127c
        ); // LINK
        analytics.setPriceOracle(
            0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2,
            0xec1D1B3b0443256cc3860e24a46F108e699484Aa
        ); // MKR
        analytics.setPriceOracle(
            0x0000000000085d4780B73119b644AE5ecd22b376,
            0xec746eCF986E2927Abd291a2A1716c940100f8Ba
        ); // TUSD
        analytics.setPriceOracle(
            0x853d955aCEf822Db058eb8505911ED77F175b99e,
            0xB9E1E3A9feFf48998E45Fa90847ed4D467E8BcfD
        ); // FRAX
        analytics.setPriceOracle(
            0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9,
            0x547a514d5e3769680Ce22B2361c10Ea13619e8a9
        ); // AAVE
        analytics.setPriceOracle(
            0xD533a949740bb3306d119CC777fa900bA034cd52,
            0xCd627aA160A6fA45Eb793D19Ef54f5062F20f33f
        ); // CRV
    }

    function testGetXTokensInfo() public {
        XTokenAnalytics[] memory xTokensInfo = analytics.getXTokensInfo(
            controller
        );

        assertEq(xTokensInfo.length, 27);
    }

    function testGetXTokenInfo() public {
        address iUSDT = 0x1180c114f7fAdCB6957670432a3Cf8Ef08Ab5354;

        XTokenAnalytics memory xTokenInfo = analytics.getXTokenInfo(
            iUSDT,
            controller
        );

        assertEq(block.number, BLOCK_NUMBER);

        assertEq(xTokenInfo.platformAddress, iUSDT);
        assertEq(xTokenInfo.symbol, "iUSDT");
        assertEq(
            xTokenInfo.underlyingAddress,
            0xdAC17F958D2ee523a2206206994597C13D831ec7
        );
        assertEq(xTokenInfo.underlyingSymbol, "USDT");
        assertEq(xTokenInfo.totalSupply, 1433592937186);
        assertEq(xTokenInfo.totalBorrows, 925143912500);
        assertEq(xTokenInfo.collateralFactor, 850000000000000000);
        assertEq(xTokenInfo.borrowApy, 36500398230316274);
        assertEq(xTokenInfo.supplyApy, 21040391138588430);
        assertEq(xTokenInfo.underlyingPrice, 999900000000000000);
        assertEq(xTokenInfo.liquidity, 508594484462100300000000);
        assertEq(xTokenInfo.totalSupplyUSD, 1433449577892281400000000);
        assertEq(xTokenInfo.totalBorrowsUSD, 925051398108750000000000);
        assertEq(xTokenInfo.borrowRewardsApy, 24398129389967832);
        assertEq(xTokenInfo.supplyRewardsApy, 36963247813895115);
    }
}
