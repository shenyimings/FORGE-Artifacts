// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "./libraries/Arrays.sol";
import "./libraries/Constants.sol";
import "../src/managers/DepositManager.sol";

contract depositManager3x3Test is Test {
    // 3 assets, 3 strategies

    uint256[] exchangeRates;
    uint16a16 allocation;
    uint256[][] strategyRatios;
    DepositManager depositManager;

    function setUp() public {
        depositManager = new DepositManager(
            IStrategyRegistry(address(0)),
            IUsdPriceFeedManager(address(0)),
            IGuardManager(address(0)),
            IActionManager(address(0)),
            ISpoolAccessControl(address(0))
        );
        exchangeRates = Arrays.toArray(
            1200 * USD_DECIMALS_MULTIPLIER, 16400 * USD_DECIMALS_MULTIPLIER, 270 * USD_DECIMALS_MULTIPLIER
        );
        allocation = Arrays.toUint16a16(600, 300, 100);

        strategyRatios = new uint256[][](3);
        strategyRatios[0] = Arrays.toArray(1000, 71, 4300);
        strategyRatios[1] = Arrays.toArray(1000, 74, 4500);
        strategyRatios[2] = Arrays.toArray(1000, 76, 4600);
    }

    function test_calculateFlushFactors_shouldCalculateFlushFactors() public {
        uint256[][] memory flushFactors =
            depositManager.calculateFlushFactors(exchangeRates, allocation, strategyRatios);

        assertEq(flushFactors[0][0], 170193453225165938616894);
        assertEq(flushFactors[0][1], 12083735178986781641799);
        assertEq(flushFactors[0][2], 731831848868213536052646);

        assertEq(flushFactors[1][0], 82676514358154660199525);
        assertEq(flushFactors[1][1], 6118062062503444854764);
        assertEq(flushFactors[1][2], 372044314611695970897866);

        assertEq(flushFactors[2][0], 27112026895130679969634);
        assertEq(flushFactors[2][1], 2060514044029931677692);
        assertEq(flushFactors[2][2], 124715323717601127860318);
    }

    function test_calculateDepositRatio_shouldCalculateDepositRatio() public {
        uint256[] memory depositRatio = depositManager.calculateDepositRatio(exchangeRates, allocation, strategyRatios);

        assertEq(depositRatio[0], 279981994478451278786053);
        assertEq(depositRatio[1], 20262311285520158174255);
        assertEq(depositRatio[2], 1228591487197510634810830);
    }

    function test_checkDepositRatio_shouldPassIfDepositIsCloseEnough() public view {
        uint256[] memory deposit;

        deposit = Arrays.toArray(2799819944784511, 202623112855200, 12285914871975105);
        depositManager.checkDepositRatio(deposit, exchangeRates, allocation, strategyRatios);

        deposit = Arrays.toArray(279981994478451100, 20262311285520000, 1228591487197510500);
        depositManager.checkDepositRatio(deposit, exchangeRates, allocation, strategyRatios);

        deposit = Arrays.toArray(2799819944784, 202623112855, 12285914871975);
        depositManager.checkDepositRatio(deposit, exchangeRates, allocation, strategyRatios);

        deposit = Arrays.toArray(5599639889569022, 405246225710400, 24571829743950210);
        depositManager.checkDepositRatio(deposit, exchangeRates, allocation, strategyRatios);
    }

    function test_checkDepositRatio_shouldRevertIfDepositIsNotCloseEnough() public {
        uint256[] memory deposit;

        deposit = Arrays.toArray(1799819944784511, 202623112855200, 12285914871975105);
        vm.expectRevert(IncorrectDepositRatio.selector);
        depositManager.checkDepositRatio(deposit, exchangeRates, allocation, strategyRatios);

        deposit = Arrays.toArray(3799819944784511, 202623112855200, 12285914871975105);
        vm.expectRevert(IncorrectDepositRatio.selector);
        depositManager.checkDepositRatio(deposit, exchangeRates, allocation, strategyRatios);

        deposit = Arrays.toArray(2799819944784511, 102623112855200, 12285914871975105);
        vm.expectRevert(IncorrectDepositRatio.selector);
        depositManager.checkDepositRatio(deposit, exchangeRates, allocation, strategyRatios);

        deposit = Arrays.toArray(2799819944784511, 302623112855200, 12285914871975105);
        vm.expectRevert(IncorrectDepositRatio.selector);
        depositManager.checkDepositRatio(deposit, exchangeRates, allocation, strategyRatios);

        deposit = Arrays.toArray(2799819944784511, 202623112855200, 2285914871975105);
        vm.expectRevert(IncorrectDepositRatio.selector);
        depositManager.checkDepositRatio(deposit, exchangeRates, allocation, strategyRatios);

        deposit = Arrays.toArray(2799819944784511, 202623112855200, 32285914871975105);
        vm.expectRevert(IncorrectDepositRatio.selector);
        depositManager.checkDepositRatio(deposit, exchangeRates, allocation, strategyRatios);
    }

    function test_distributeDeposit_shouldDistributeIdealDeposit() public {
        uint256[] memory deposit = Arrays.toArray(2799819944784511, 202623112855200, 12285914871975105);

        uint256[][] memory distribution = depositManager.distributeDeposit(
            DepositQueryBag1({
                deposit: deposit,
                exchangeRates: exchangeRates,
                allocation: allocation,
                strategyRatios: strategyRatios
            })
        );

        assertEq(distribution[0][0], 1701934532251659);
        assertEq(distribution[0][1], 120837351789868);
        assertEq(distribution[0][2], 7318318488682135);

        assertEq(distribution[1][0], 826765143581546);
        assertEq(distribution[1][1], 61180620625033);
        assertEq(distribution[1][2], 3720443146116959);

        assertEq(distribution[2][0], 271120268951306);
        assertEq(distribution[2][1], 20605140440299);
        assertEq(distribution[2][2], 1247153237176011);
    }

    function test_distributeDeposit_shouldDistributeRealDeposit_1() public {
        uint256[] memory deposit = Arrays.toArray(1000 ether, 74 ether, 4300 ether);

        uint256[][] memory distribution = depositManager.distributeDeposit(
            DepositQueryBag1({
                deposit: deposit,
                exchangeRates: exchangeRates,
                allocation: allocation,
                strategyRatios: strategyRatios
            })
        );

        assertEq(distribution[0][0], 607_872851046015465177);
        assertEq(distribution[0][1], 44_131016972581602124);
        assertEq(distribution[0][2], 2561_369652097728119011);

        assertEq(distribution[1][0], 295_292254461448343841);
        assertEq(distribution[1][1], 22_343778369883661585);
        assertEq(distribution[1][2], 1302_133841476884165665);

        assertEq(distribution[2][0], 96_834894492536190982);
        assertEq(distribution[2][1], 7_525204657534736291);
        assertEq(distribution[2][2], 436_496506425387715324);
    }

    function test_distributeDeposit_shouldDistributeRealDeposit_2() public {
        uint256[] memory deposit = Arrays.toArray(100 ether, 7.237 ether, 438.8 ether);

        uint256[][] memory distribution = depositManager.distributeDeposit(
            DepositQueryBag1({
                deposit: deposit,
                exchangeRates: exchangeRates,
                allocation: allocation,
                strategyRatios: strategyRatios
            })
        );

        assertEq(distribution[0][0], 60_787285104601546518);
        assertEq(distribution[0][1], 4_315894186899635873);
        assertEq(distribution[0][2], 261_378837986158860145);

        assertEq(distribution[1][0], 29_529225446144834384);
        assertEq(distribution[1][1], 2_185161135984433228);
        assertEq(distribution[1][2], 132_878216195362039975);

        assertEq(distribution[2][0], 9_683489449253619098);
        assertEq(distribution[2][1], 735944677115930899);
        assertEq(distribution[2][2], 44_542945818479099880);
    }
}

contract depositManager2x3Test is Test {
    // 2 assets, 3 strategies

    uint256[] exchangeRates;
    uint16a16 allocation;
    uint256[][] strategyRatios;
    DepositManager depositManager;

    function setUp() public {
        depositManager = new DepositManager(
            IStrategyRegistry(address(0)),
            IUsdPriceFeedManager(address(0)),
            IGuardManager(address(0)),
            IActionManager(address(0)),
            ISpoolAccessControl(address(0))
        );
        exchangeRates = Arrays.toArray(1200 * USD_DECIMALS_MULTIPLIER, 16400 * USD_DECIMALS_MULTIPLIER);
        allocation = Arrays.toUint16a16(600, 300, 100);

        strategyRatios = new uint256[][](3);
        strategyRatios[0] = Arrays.toArray(1000, 71);
        strategyRatios[1] = Arrays.toArray(1000, 74);
        strategyRatios[2] = Arrays.toArray(1000, 76);
    }

    function test_calculateFlushFactors_shouldCalculateFlushFactors() public {
        uint256[][] memory flushFactors =
            depositManager.calculateFlushFactors(exchangeRates, allocation, strategyRatios);

        assertEq(flushFactors[0][0], 253764168499407883606834);
        assertEq(flushFactors[0][1], 18017255963457959736085);

        assertEq(flushFactors[1][0], 124295657938349353662578);
        assertEq(flushFactors[1][1], 9197878687437852171030);

        assertEq(flushFactors[2][0], 40876389797253106605624);
        assertEq(flushFactors[2][1], 3106605624591236102027);
    }

    function test_calculateDepositRatio_shouldCalculateDepositRatio() public {
        uint256[] memory depositRatio = depositManager.calculateDepositRatio(exchangeRates, allocation, strategyRatios);

        assertEq(depositRatio[0], 418936216235010343875036);
        assertEq(depositRatio[1], 30321740275487048009142);
    }

    function test_checkDepositRatio_shouldPassIfDepositIsCloseEnough() public view {
        uint256[] memory deposit;

        deposit = Arrays.toArray(41_893621, 3_032174);
        depositManager.checkDepositRatio(deposit, exchangeRates, allocation, strategyRatios);
    }

    function test_distributeDeposit_shouldDistributeIdealDeposit() public {
        uint256[] memory deposit = Arrays.toArray(41_893621, 3_032174);

        uint256[][] memory distribution = depositManager.distributeDeposit(
            DepositQueryBag1({
                deposit: deposit,
                exchangeRates: exchangeRates,
                allocation: allocation,
                strategyRatios: strategyRatios
            })
        );

        assertEq(distribution[0][0], 25_376418);
        assertEq(distribution[0][1], 1_801727);

        assertEq(distribution[1][0], 12_429565);
        assertEq(distribution[1][1], 919787);

        assertEq(distribution[2][0], 4_087638);
        assertEq(distribution[2][1], 310660);
    }
}

contract depositManager1x2Test is Test {
    // 1 asset, 2 strategies

    uint256[] exchangeRates;
    uint16a16 allocation;
    uint256[][] strategyRatios;
    DepositManager depositManager;

    function setUp() public {
        depositManager = new DepositManager(
            IStrategyRegistry(address(0)),
            IUsdPriceFeedManager(address(0)),
            IGuardManager(address(0)),
            IActionManager(address(0)),
            ISpoolAccessControl(address(0))
        );

        exchangeRates = Arrays.toArray(1200 * USD_DECIMALS_MULTIPLIER);
        allocation = Arrays.toUint16a16(600, 400);

        strategyRatios = new uint256[][](2);
        strategyRatios[0] = Arrays.toArray(100_00);
        strategyRatios[1] = Arrays.toArray(100_00);
    }

    function test_calculateDepositRatio_shouldCalculateDepositRatio() public {
        uint256[] memory depositRatio = depositManager.calculateDepositRatio(exchangeRates, allocation, strategyRatios);

        assertEq(depositRatio[0], 1);
    }

    function test_checkDepositRatio_shouldPassIfDepositIsCloseEnough() public view {
        uint256[] memory deposit;

        deposit = Arrays.toArray(1_000000);
        depositManager.checkDepositRatio(deposit, exchangeRates, allocation, strategyRatios);
    }

    function test_distributeDeposit_shouldDistributeIdealDeposit() public {
        uint256[] memory deposit = Arrays.toArray(1_000000);

        uint256[][] memory distribution = depositManager.distributeDeposit(
            DepositQueryBag1({
                deposit: deposit,
                exchangeRates: exchangeRates,
                allocation: allocation,
                strategyRatios: strategyRatios
            })
        );

        assertEq(distribution[0][0], 600000);

        assertEq(distribution[1][0], 400000);
    }
}
