// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/external/interfaces/chainlink/AggregatorV3Interface.sol";
import "../src/access/SpoolAccessControl.sol";
import "../src/libraries/SpoolUtils.sol";
import "../src/managers/DepositManager.sol";
import "../src/managers/UsdPriceFeedManager.sol";
import "./libraries/Arrays.sol";
import "./mocks/MockAggregatorV3.sol";

contract depositManagerIntegrationTest is Test {
    uint256 daiDecimals = 18;
    uint256 usdcDecimals = 6;

    address daiAddress = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address usdcAddress = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    MockAggregatorV3 daiUsdPriceAggregator;
    MockAggregatorV3 usdcUsdPriceAggregator;

    UsdPriceFeedManager usdPriceFeedManager;

    DepositManager depositManager;

    function setUp() public {
        SpoolAccessControl accessControl = new SpoolAccessControl();
        accessControl.initialize();

        depositManager = new DepositManager(
            IStrategyRegistry(address(0)),
            IUsdPriceFeedManager(address(0)),
            IGuardManager(address(0)),
            IActionManager(address(0)),
            accessControl
        );

        usdPriceFeedManager = new UsdPriceFeedManager(accessControl);

        daiUsdPriceAggregator = new MockAggregatorV3(8, "Dai-Usd", 1);
        usdcUsdPriceAggregator = new MockAggregatorV3(8, "Usdc-Usd", 1);

        usdPriceFeedManager.setAsset(daiAddress, daiDecimals, daiUsdPriceAggregator, true);
        daiUsdPriceAggregator.pushAnswer(1_00000000);

        usdPriceFeedManager.setAsset(usdcAddress, usdcDecimals, usdcUsdPriceAggregator, true);
        usdcUsdPriceAggregator.pushAnswer(1_00000000);
    }

    function test_shouldWorkWhenTokensHaveDifferentDecimals() public {
        // let us first calculate the exchange rate for both tokens
        uint256[] memory exchangeRates =
            SpoolUtils.getExchangeRates(Arrays.toArray(daiAddress, usdcAddress), usdPriceFeedManager);

        // exchange rate for both tokens should be the same
        assertEq(exchangeRates[0], exchangeRates[1]);
        assertEq(exchangeRates[0], 1 * 10 ** USD_DECIMALS);

        // strategy ratio should be about 1 DAI : 1 USDC (e.g., Uniswap v2)
        uint256[] memory strategyRatio = Arrays.toArray(10 ** daiDecimals, 10 ** usdcDecimals);

        // let us have a smart vault with two strategies
        // allocation is 60:40
        uint16a16 allocation = Arrays.toUint16a16(60_00, 40_00);
        // both have same strategyRatio
        uint256[][] memory strategyRatios = new uint256[][](2);
        strategyRatios[0] = strategyRatio;
        strategyRatios[1] = strategyRatio;

        // we have a deposit made of 10 DAI and 10 USDC
        uint256[] memory deposit = Arrays.toArray(10 * (10 ** daiDecimals), 10 * (10 ** usdcDecimals));

        // first check if deposit ratio is OK
        depositManager.checkDepositRatio(deposit, exchangeRates, allocation, strategyRatios);

        // now distribute the deposit
        uint256[][] memory distribution = depositManager.distributeDeposit(
            DepositQueryBag1({
                deposit: deposit,
                exchangeRates: exchangeRates,
                allocation: allocation,
                strategyRatios: strategyRatios
            })
        );

        // fist strategy should get 6 DAI and 6 USDC
        // second strategy should get 4 DAI and 4 USDC
        // (up to dust)
        assertEq(distribution[0], Arrays.toArray(6 * (10 ** daiDecimals) + 1, 6 * (10 ** usdcDecimals)));
        assertEq(distribution[1], Arrays.toArray(4 * (10 ** daiDecimals) - 1, 4 * (10 ** usdcDecimals)));
    }
}
