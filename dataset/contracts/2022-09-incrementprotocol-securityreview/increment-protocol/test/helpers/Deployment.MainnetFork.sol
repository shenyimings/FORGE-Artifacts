// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

// contracts
import {Test} from "../../lib/forge-std/src/Test.sol";
import "../../contracts/Oracle.sol";
import "../../contracts/CurveCryptoViews.sol";
import "../mocks/TestClearingHouse.sol";
import "../mocks/TestClearingHouseViewer.sol";
import "../mocks/TestPerpetual.sol";
import "../mocks/TestVault.sol";
import "../mocks/TestInsurance.sol";
import "../../contracts/tokens/UA.sol";
import "../../contracts/tokens/VBase.sol";
import "../../contracts/tokens/VQuote.sol";
import "../../contracts/utils/UAHelper.sol";
import {Global} from "./Parameters.Global.sol";
import {EURUSD} from "./Parameters.EURUSD.sol";
import {ETHUSD} from "./Parameters.ETHUSD.sol";

// interfaces
import "../../contracts/interfaces/ICryptoSwap.sol";
import "../../contracts/interfaces/IPerpetual.sol";
import "../../contracts/interfaces/IClearingHouse.sol";
import "../../contracts/interfaces/ICurveCryptoFactory.sol";
import "../../contracts/interfaces/IVault.sol";
import "../../contracts/interfaces/IInsurance.sol";
import "../../contracts/interfaces/IMath.sol";
import "../../contracts/interfaces/ICurveToken.sol";
import "../../lib/chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../../lib/chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// utils
import "../../contracts/lib/LibMath.sol";

abstract contract Deployment is Test {
    using LibMath for int256;

    /* fork */
    uint256 public mainnetFork;

    /* fork addresses */
    address constant CRYPTO_SWAP_FACTORY = 0xF18056Bbd320E96A48e3Fbf8bC061322531aac99;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant EUR_ORACLE = 0xb49f677943BC038e9857d61E7d053CaA2C1734C1;
    address constant ETH_ORACLE = 0xb49f677943BC038e9857d61E7d053CaA2C1734C1;
    address constant USDC_ORACLE = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address constant CURVE_MATH = 0x69522fb5337663d3B4dFB0030b881c1A750Adb4f;

    /* contracts */
    ICurveCryptoFactory public factory;
    ICryptoSwap public cryptoSwap;
    AggregatorV3Interface public baseOracle;
    AggregatorV3Interface public usdcOracle;

    TestClearingHouse public clearingHouse;
    TestPerpetual public perpetual;
    TestVault public vault;
    TestInsurance public insurance;
    MockV3Aggregator public sequencerUptimeFeed;
    Oracle public oracle;
    TestClearingHouseViewer public viewer;

    IERC20Metadata public usdc;
    UA public ua;
    VBase public vBase;
    VQuote public vQuote;
    ICurveToken public lpToken;

    IMath public math;
    CurveCryptoViews public curveCryptoViews;
    UAHelper public uaHelper;

    /* ETH Market */
    VBase public eth_vBase;
    VQuote public eth_vQuote;
    ICurveToken public eth_lpToken;
    TestPerpetual public eth_perpetual;
    ICryptoSwap public eth_cryptoSwap;
    AggregatorV3Interface public eth_baseOracle;

    function test_IgnoreCoverage() public {}

    function _deployEthMarket() internal {
        // set aggregator
        eth_baseOracle = AggregatorV3Interface(ETH_ORACLE);

        // deploy virtual tokens
        eth_vBase =
            new VBase("vETH base token", "vETH", baseOracle, ETHUSD.heartBeat, sequencerUptimeFeed, ETHUSD.gracePeriod);
        eth_vQuote = new VQuote("vUSD quote token", "vUSD");

        // deploy cryptoswap
        (, int256 answer,,,) = baseOracle.latestRoundData();
        uint8 decimals = eth_baseOracle.decimals();
        uint256 initialPrice = answer.toUint256() * (10 ** (18 - decimals));
        eth_cryptoSwap = ICryptoSwap(
            factory.deploy_pool(
                "ETHUSD",
                "ETHUSD",
                [address(eth_vQuote), address(eth_vBase)],
                ETHUSD.A,
                ETHUSD.gamma,
                ETHUSD.mid_fee,
                ETHUSD.out_fee,
                ETHUSD.allowed_extra_profit,
                ETHUSD.fee_gamma,
                ETHUSD.adjustment_step,
                ETHUSD.admin_fee,
                ETHUSD.ma_half_time,
                initialPrice
            )
        );
        eth_lpToken = ICurveToken(eth_cryptoSwap.token());

        // deploy perpetual
        eth_perpetual = new TestPerpetual(
            eth_vBase,
            eth_vQuote,
            eth_cryptoSwap,
            clearingHouse,
            curveCryptoViews,
            true,
            IPerpetual.PerpetualParams(
                ETHUSD.riskWeight,
                ETHUSD.maxLiquidityProvided,
                ETHUSD.twapFrequency,
                ETHUSD.sensitivity,
                ETHUSD.maxBlockTradeAmount,
                ETHUSD.insuranceFee,
                ETHUSD.lpDebtCoef,
                ETHUSD.lockPeriod
            )
        );
        eth_vBase.transferPerpOwner(address(eth_perpetual));
        eth_vQuote.transferPerpOwner(address(eth_perpetual));
        clearingHouse.allowListPerpetual(eth_perpetual);
    }

    function setUp() public virtual {
        /* initialize fork */
        vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);

        /* get existing deployments */
        factory = ICurveCryptoFactory(CRYPTO_SWAP_FACTORY);
        usdc = IERC20Metadata(USDC);
        baseOracle = AggregatorV3Interface(EUR_ORACLE);
        usdcOracle = AggregatorV3Interface(USDC_ORACLE);
        math = IMath(CURVE_MATH);

        /*  deploy own contracts*/

        // 001_deploy_UA
        ua = new UA(usdc, Global.initialTokenMaxMintCap);

        // 002_deploy_vault
        vault = new TestVault(ua);

        // 003_deploy_insurance
        insurance = new TestInsurance(ua, vault);
        vault.setInsurance(insurance);

        // 004_deploy_oracle
        // deploy mock sequencer uptime feed
        sequencerUptimeFeed = new MockV3Aggregator(0, 0);
        sequencerUptimeFeed.updateRoundData(0, 0, 0, 0);

        oracle = new Oracle(sequencerUptimeFeed, Global.gracePeriod);
        oracle.setOracle(address(ua), usdcOracle, Global.uaHeartBeat, false);
        oracle.setFixedPrice(address(ua), 1 ether);
        vault.setOracle(oracle);

        // 005_deploy_clearingHouse
        clearingHouse = new TestClearingHouse(
            vault,
            insurance,
            IClearingHouse.ClearingHouseParams(
                Global.minMargin,
                Global.minMarginAtCreation,
                Global.minPositiveOpenNotional,
                Global.liquidationReward,
                Global.insuranceRatio,
                Global.liquidationRewardInsuranceShare,
                Global.liquidationDiscount,
                Global.nonUACollSeizureDiscount,
                Global.uaDebtSeizureThreshold
            )
        );
        vault.setClearingHouse(clearingHouse);
        insurance.setClearingHouse(clearingHouse);

        // 006_deploy_virtual_tokens
        vBase =
            new VBase("vEUR base token", "vEUR", baseOracle, EURUSD.heartBeat, sequencerUptimeFeed, EURUSD.gracePeriod);
        vQuote = new VQuote("vUSD quote token", "vUSD");

        // 007_create_curve_pool
        (, int256 answer,,,) = baseOracle.latestRoundData();
        uint8 decimals = baseOracle.decimals();
        uint256 initialPrice = answer.toUint256() * (10 ** (18 - decimals));
        cryptoSwap = ICryptoSwap(
            factory.deploy_pool(
                "EURUSD",
                "EURUSD",
                [address(vQuote), address(vBase)],
                EURUSD.A,
                EURUSD.gamma,
                EURUSD.mid_fee,
                EURUSD.out_fee,
                EURUSD.allowed_extra_profit,
                EURUSD.fee_gamma,
                EURUSD.adjustment_step,
                EURUSD.admin_fee,
                EURUSD.ma_half_time,
                initialPrice
            )
        );
        lpToken = ICurveToken(cryptoSwap.token());

        // 008_deploy_curveCryptoViews
        curveCryptoViews = new CurveCryptoViews(address(math));

        // 009_deploy_perpetuals
        perpetual = new TestPerpetual(
            vBase,
            vQuote,
            cryptoSwap,
            clearingHouse,
            curveCryptoViews,
            true,
            IPerpetual.PerpetualParams(
                EURUSD.riskWeight,
                EURUSD.maxLiquidityProvided,
                EURUSD.twapFrequency,
                EURUSD.sensitivity,
                EURUSD.maxBlockTradeAmount,
                EURUSD.insuranceFee,
                EURUSD.lpDebtCoef,
                EURUSD.lockPeriod
            )
        );
        vBase.transferPerpOwner(address(perpetual));
        vQuote.transferPerpOwner(address(perpetual));
        clearingHouse.allowListPerpetual(perpetual);

        // 010_deploy_clearingHouseViewer
        viewer = new TestClearingHouseViewer(clearingHouse);

        // 011_deploy_uaHelper
        uaHelper = new UAHelper(ua, clearingHouse);
    }
}
