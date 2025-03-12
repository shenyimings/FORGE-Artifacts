// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../../contracts/strategies/lbl/dforce/DForceStatistics.sol";
import "../../../contracts/SwapGateway.sol";

contract DForceStatisticsPolygonTest is Test {
    address controller = 0x52eaCd19E38D501D006D2023C813d7E37F025f37;
    address uniswapV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    uint256 private mainnetFork;

    DForceStatistics public analytics;
    SwapGateway public swapGateway;

    uint256 private constant BLOCK_NUMBER = 40_367_055;
    uint256 private constant BLOCK_NUMBER2 = 43_402_723;

    function setUp() public {
        mainnetFork = vm.createSelectFork(vm.rpcUrl("polygon"), BLOCK_NUMBER);

        // SwapGateway
        swapGateway = new SwapGateway();
        swapGateway.__SwapGateway_init();
        swapGateway.addSwapRouter(uniswapV3Router, 3);

        // Statistics
        analytics = new DForceStatistics();
        analytics.__StrategyStatistics_init();
        analytics.setSwapGateway(address(swapGateway));
        analytics.setRewardsXToken(0xcB5D9b6A9BA8eA6FA82660fAA9cC130586F939B2);

        analytics.setBLID(0x4b27Cd6E6a5E83d236eAD376D256Fe2F9e9f0d2E);

        address[] memory pathBLIDtoUSDT = new address[](2);
        pathBLIDtoUSDT[0] = 0x4b27Cd6E6a5E83d236eAD376D256Fe2F9e9f0d2E;
        pathBLIDtoUSDT[1] = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
        analytics.setBLIDSwap(uniswapV3Router, pathBLIDtoUSDT);

        analytics.setPriceOracle(
            0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174,
            0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7
        ); // USDC
        analytics.setPriceOracle(
            0xc2132D05D31c914a87C6611C10748AEb04B58e8F,
            0x0A6513e40db6EB1b165753AD52E80663aeA50545
        ); // USDT
        analytics.setPriceOracle(
            0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D
        ); // DAI
        analytics.setPriceOracle(
            0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6,
            0xc907E116054Ad103354f2D350FD2514433D57F6f
        ); // WBTC
        analytics.setPriceOracle(
            0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619,
            0xF9680D99D6C9589e2a93a78A04A279e509205945
        ); // WETH
        analytics.setPriceOracle(
            0xD6DF932A45C0f255f85145f286eA0b292B21C90B,
            0x72484B12719E23115761D5DA1646945632979bB6
        ); // AAVE
        analytics.setPriceOracle(
            0x0000000000000000000000000000000000000000,
            0xAB594600376Ec9fD91F8e885dADF0CE036862dE0
        ); // MATIC

        vm.makePersistent(address(swapGateway));
        vm.makePersistent(address(analytics));
    }

    function testGetXTokensInfo() public {
        XTokenAnalytics[] memory xTokensInfo = analytics.getXTokensInfo(
            controller
        );

        assertEq(xTokensInfo.length, 11);
    }

    function testGetXTokenInfo() public {
        address iUSDT = 0xb3ab7148cCCAf66686AD6C1bE24D83e58E6a504e;

        XTokenAnalytics memory xTokenInfo = analytics.getXTokenInfo(
            iUSDT,
            controller
        );

        assertEq(block.number, BLOCK_NUMBER);

        assertEq(xTokenInfo.platformAddress, iUSDT);
        assertEq(xTokenInfo.symbol, "iUSDT");
        assertEq(
            xTokenInfo.underlyingAddress,
            0xc2132D05D31c914a87C6611C10748AEb04B58e8F
        );
        assertEq(xTokenInfo.underlyingSymbol, "USDT");
        assertEq(xTokenInfo.totalSupply, 1371476766384);
        assertEq(xTokenInfo.totalBorrows, 759582022670);
        assertEq(xTokenInfo.collateralFactor, 850000000000000000);
        assertEq(xTokenInfo.borrowApy, 31245945444911099);
        assertEq(xTokenInfo.supplyApy, 15454961035687756);
        assertEq(xTokenInfo.underlyingPrice, 1004023560000000000);
        assertEq(xTokenInfo.liquidity, 614834935823391683400000);
        assertEq(xTokenInfo.totalSupplyUSD, 1376994985442152007040000);
        assertEq(xTokenInfo.totalBorrowsUSD, 762638246513134105200000);
        assertEq(xTokenInfo.borrowRewardsApy, 24853867820763101);
        assertEq(xTokenInfo.supplyRewardsApy, 32234296819399581);
    }

    function testGetStrategyAnalytics() public {
        address logic = 0xb0FE862B68032a51622a8CcEFa636656e2a6106F;

        vm.mockCall(
            address(logic),
            abi.encodeWithSelector(ILendingLogic.comptroller.selector),
            abi.encode(controller)
        );

        vm.mockCall(
            address(logic),
            abi.encodeWithSelector(ILendingLogic.isXTokenUsed.selector),
            abi.encode(true)
        );

        StrategyStatistics memory res = analytics.getStrategyStatistics(logic);

        assertEq(res.totalSupplyUSD, 9293242071360000);
        assertEq(res.totalBorrowUSD, 6291211626960000);
        assertEq(res.lendingEarnedUSD, 30345295548448);
        assertEq(res.totalAmountUSD, 20305059948448);
        assertEq(res.borrowRate, 796491674081606711);
    }

    function testGetStrategyAnalyticsProduction() public {
        vm.rollFork(BLOCK_NUMBER2);

        address logic = 0xc704ed95Da3e554A8C6b243290dfcC2B8B5BE4Ed;

        vm.mockCall(
            address(logic),
            abi.encodeWithSelector(ILendingLogic.comptroller.selector),
            abi.encode(controller)
        );

        vm.mockCall(
            address(logic),
            abi.encodeWithSelector(ILendingLogic.isXTokenUsed.selector),
            abi.encode(true)
        );

        StrategyStatistics memory res = analytics.getStrategyStatistics(logic);

        assertEq(res.totalSupplyUSD, 186625470163052320000000);
        assertEq(res.totalBorrowUSD, 144670577493465680000000);
        assertEq(res.lendingEarnedUSD, 1324236629570973107);
        assertEq(res.totalAmountUSD, 877758277930973107);
    }
}
