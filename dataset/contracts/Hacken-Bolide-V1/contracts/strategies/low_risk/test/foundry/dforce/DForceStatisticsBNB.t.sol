// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../../contracts/strategies/lbl/dforce/DForceStatistics.sol";
import "../../../contracts/SwapGateway.sol";

contract DForceStatisticsBNBTest is Test {
    address controller = 0x0b53E608bD058Bb54748C35148484fD627E6dc0A;
    address pancakeRouter = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    uint256 private mainnetFork;

    DForceStatistics public analytics;
    SwapGateway public swapGateway;

    uint256 private constant BLOCK_NUMBER = 27_050_910;

    function setUp() public {
        mainnetFork = vm.createSelectFork(vm.rpcUrl("bsc"), BLOCK_NUMBER);

        swapGateway = new SwapGateway();
        swapGateway.__SwapGateway_init();
        swapGateway.addSwapRouter(pancakeRouter, 2);

        analytics = new DForceStatistics();
        analytics.__StrategyStatistics_init();
        analytics.setSwapGateway(address(swapGateway));
        analytics.setRewardsXToken(0xeC3FD540A2dEE6F479bE539D64da593a59e12D08);

        analytics.setPriceOracle(
            0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56,
            0xcBb98864Ef56E9042e7d2efef76141f15731B82f
        ); // BUSD
        // analytics.setPriceOracle(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d, 0x51597f405303C4377E36123cBc172b13269EA163); // USDC
        analytics.setPriceOracle(
            0x55d398326f99059fF775485246999027B3197955,
            0xB97Ad0E74fa7d920791E90258A6E2085088b4320
        ); // USDT
        // analytics.setPriceOracle(0x4A9A2b2b04549C3927dd2c9668A5eF3fCA473623, 0x1b816F5E122eFa230300126F97C018716c4e47F5); // DF
        analytics.setPriceOracle(
            0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c,
            0x264990fbd0A4796A3E3d8E37C4d5F87a3aCa5Ebf
        ); // BTC
        analytics.setPriceOracle(
            0x2170Ed0880ac9A755fd29B2688956BD959F933F8,
            0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e
        ); // ETH
        analytics.setPriceOracle(
            0xBf5140A22578168FD562DCcF235E5D43A02ce9B1,
            0xb57f259E7C24e56a1dA00F66b55A5640d9f9E7e4
        ); // UNI
        analytics.setPriceOracle(
            0x0Eb3a705fc54725037CC9e008bDede697f62F335,
            0xb056B7C804297279A9a673289264c17E6Dc6055d
        ); // ATOM
        analytics.setPriceOracle(
            0x7083609fCE4d1d8Dc0C979AAb8c869Ea2C873402,
            0xC333eb0086309a16aa7c8308DfD32c8BBA0a2592
        ); // DOT
        analytics.setPriceOracle(
            0x0D8Ce2A99Bb6e3B7Db580eD848240e4a0F9aE153,
            0xE5dbFD9003bFf9dF5feB2f4F445Ca00fb121fb83
        ); // FIL
        analytics.setPriceOracle(
            0x0000000000000000000000000000000000000000,
            0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE
        ); // BNB
        analytics.setPriceOracle(
            0x1D2F0da169ceB9fC7B3144628dB156f3F6c60dBE,
            0x93A67D414896A280bF8FFB3b389fE3686E014fda
        ); // XRP
        analytics.setPriceOracle(
            0x4338665CBB7B2485A8855A139b75D5e34AB0DB94,
            0x74E72F37A8c415c8f1a98Ed42E78Ff997435791D
        ); // LTC
        analytics.setPriceOracle(
            0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD,
            0xca236E327F629f9Fc2c30A4E95775EbF0B89fac8
        ); // LINK
        analytics.setPriceOracle(
            0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82,
            0xB6064eD41d4f67e353768aA239cA86f4F73665a1
        ); // Cake
        analytics.setPriceOracle(
            0x8fF795a6F4D97E7887C79beA79aba5cc76444aDf,
            0x43d80f616DAf0b0B42a928EeD32147dC59027D41
        ); // BCH
        analytics.setPriceOracle(
            0x16939ef78684453bfDFb47825F8a5F714f12623a,
            0x9A18137ADCF7b05f033ad26968Ed5a9cf0Bf8E6b
        ); // XTZ
    }

    function testGetXTokensInfo() public {
        XTokenAnalytics[] memory xTokensInfo = analytics.getXTokensInfo(
            controller
        );

        assertEq(xTokensInfo.length, 28);
    }

    function testGetXTokenInfo() public {
        address iUSDT = 0x0BF8C72d618B5d46b055165e21d661400008fa0F;

        XTokenAnalytics memory xTokenInfo = analytics.getXTokenInfo(
            iUSDT,
            controller
        );

        assertEq(block.number, BLOCK_NUMBER);

        assertEq(xTokenInfo.platformAddress, iUSDT);
        assertEq(xTokenInfo.symbol, "iUSDT");
        assertEq(
            xTokenInfo.underlyingAddress,
            0x55d398326f99059fF775485246999027B3197955
        );
        assertEq(xTokenInfo.underlyingSymbol, "USDT");
        assertEq(xTokenInfo.totalSupply, 2296519944805428384652982);
        assertEq(xTokenInfo.totalBorrows, 1944369619821236732498464);
        assertEq(xTokenInfo.collateralFactor, 850000000000000000);
        assertEq(xTokenInfo.borrowApy, 48157214882473276);
        assertEq(xTokenInfo.supplyApy, 36489814477195346);
        assertEq(xTokenInfo.underlyingPrice, 1000321680000000000);
        assertEq(xTokenInfo.liquidity, 353373249617416689345036);
        assertEq(xTokenInfo.totalSupplyUSD, 2297258689341273394855757);
        assertEq(xTokenInfo.totalBorrowsUSD, 1944995084640540827930574);
        assertEq(xTokenInfo.borrowRewardsApy, 10645207442027326);
        assertEq(xTokenInfo.supplyRewardsApy, 21138896513210150);
    }
}
