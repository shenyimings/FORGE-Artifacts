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
import "../src/Structs.sol";
import "../src/lib/ABDKMath64x64.sol";

import "./lib/MockUser.sol";
import "./lib/CheatCodes.sol";
import "./lib/Address.sol";
import "./lib/CurveParams.sol";
import "./lib/MockChainlinkOracle.sol";
import "./lib/MockOracleFactory.sol";
import "./lib/MockToken.sol";

import "./utils/Utils.sol";

contract V2Test is Test {
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

    uint256[] public dividends = [20,2];

    CurveFactoryV2 curveFactory;
    AssimilatorFactory assimFactory;

    function setUp() public {

        utils = new Utils();
        // create temp accounts
        for(uint256 i = 0; i < 3; ++i){
            accounts.push(new MockUser());
        }
        // deploy gold token & init 3 stable coins
        MockToken gold = new MockToken();
        tokens.push(IERC20Detailed(address(gold)));
        tokens.push(IERC20Detailed(Mainnet.EUROC));
        tokens.push(IERC20Detailed(Mainnet.CADC));
        tokens.push(IERC20Detailed(Mainnet.USDC));

        // deploy mock oracle factory for deployed token (named gold)
        oracleFactory = new MockOracleFactory();
        oracles.push(
            oracleFactory.newOracle(
            address(tokens[0]), "goldOracle",9, 20000000000
            )
        );
        oracles.push(IOracle(Mainnet.CHAINLINK_EUR_USD));
        oracles.push(IOracle(Mainnet.CHAINLINK_CAD_USD));
        oracles.push(IOracle(Mainnet.CHAINLINK_USDC_USD));

        // deploy new assimilator factory & curveFactory v2
        assimFactory = new AssimilatorFactory();
        curveFactory = new CurveFactoryV2(
            50000, address(accounts[2]), address(assimFactory)
        );
        assimFactory.setCurveFactory(address(curveFactory));
        // now deploy curves
        cheats.startPrank(address(accounts[2]));
        for(uint256 i = 0; i < 3;++i){
            CurveInfo memory curveInfo = CurveInfo(
                string(abi.encode("dfx-curve-",i)),
                string(abi.encode("lp-",i)),
                address(tokens[i]),
                address(tokens[3]),
                DefaultCurve.BASE_WEIGHT,
                DefaultCurve.QUOTE_WEIGHT,
                oracles[i],
                tokens[i].decimals(),
                oracles[3],
                tokens[3].decimals(),
                DefaultCurve.ALPHA,
                DefaultCurve.BETA,
                DefaultCurve.MAX,
                DefaultCurve.EPSILON,
                DefaultCurve.LAMBDA
            );
            Curve _curve = curveFactory.newCurve(curveInfo);
            curves.push(_curve);
        }
        cheats.stopPrank();
        
        // now mint gold & silver tokens
        uint256 mintAmt = 300_000_000_000;
        for(uint256 i = 0; i < 4; ++i){
            decimals.push(utils.tenToPowerOf(tokens[i].decimals()));
            if(i == 0) {
                tokens[0].mint(address(accounts[0]), mintAmt.mul(decimals[i]));
            }
            else{
                deal(address(tokens[i]), address(accounts[0]), mintAmt.mul(decimals[i]));
            }
        }
        // now approve
        cheats.startPrank(address(accounts[0]));
        for(uint256 i = 0; i < 3; ++i){
            tokens[i].approve(address(curves[i]), type(uint).max);
            tokens[3].approve(address(curves[i]), type(uint).max);
        }
        cheats.stopPrank();
    }
    /**
    deploy gold,usdc tokens, their price oracles, assimilators & test swap
    check if v2 factory & it's deployed curve works properly based on both token's price
    assuming both tokens are foreign stable coins
    gold usdc ratio is 1 : 20
     */
    function testDeployTokenAndSwap(uint256 amt) public {
        cheats.assume(amt > 100);
        cheats.assume(amt < 10000000);

        // mint gold to trader
        tokens[0].mint(address(accounts[1]), amt * decimals[0]);

        uint256 noDecGoldBal = tokens[0].balanceOf(address(accounts[1]));
        noDecGoldBal = noDecGoldBal.div(decimals[0]);

        cheats.startPrank(address(accounts[1]));
        tokens[0].approve(address(curves[0]), type(uint).max);
        tokens[3].approve(address(curves[0]), type(uint).max);
        cheats.stopPrank();

        // first deposit
        cheats.startPrank(address(accounts[0]));
        curves[0].deposit(2000000000 * decimals[0], block.timestamp + 60);
        cheats.stopPrank();

        cheats.startPrank(address(accounts[1]));
        uint256 originalGoldBal = tokens[0].balanceOf(address(accounts[1]));
        // now swap gold to usdc
        curves[0].originSwap(
            address(tokens[0]),
            address(tokens[3]), 
            originalGoldBal,
            0,
            block.timestamp + 60
        );
        cheats.stopPrank();

        uint256 noDecUsdcBal = tokens[3].balanceOf(address(accounts[1]));
        noDecUsdcBal = noDecUsdcBal.div(decimals[3]);
        // price ratio is 1:20, balance ration also needs to be approx 1:20
        assertApproxEqAbs(noDecGoldBal.mul(20), noDecUsdcBal, noDecUsdcBal.div(100));
    }
    // // test swap of forex stable coin(euroc, cadc) usdc
    function testForeignStableCoinSwap(uint256 amt) public {
        cheats.assume(amt > 100);
        cheats.assume(amt < 10000000);
        for(uint256 i = 0; i < 2; ++i){
            // mint token to trader
            deal(address(tokens[i+1]), address(accounts[1]), amt * decimals[i+1]);

            uint256 noDecForexBal = tokens[i+1].balanceOf(address(accounts[1]));
            noDecForexBal = noDecForexBal.div(decimals[i+1]);

            cheats.startPrank(address(accounts[1]));
            tokens[i+1].approve(address(curves[i+1]), type(uint).max);
            tokens[3].approve(address(curves[i+1]), type(uint).max);
            cheats.stopPrank();

            // first deposit
            cheats.startPrank(address(accounts[0]));
            curves[i+1].deposit(1000000000 * 1e18, block.timestamp + 60);
            cheats.stopPrank();

            cheats.startPrank(address(accounts[1]));
            uint256 originalForexBal = tokens[i+1].balanceOf(address(accounts[1]));
            // now swap forex stable coin to usdc
            curves[i+1].originSwap(
                address(tokens[i+1]),
                address(tokens[3]), 
                originalForexBal,
                0,
                block.timestamp + 60
            );
            cheats.stopPrank();

            uint256 noDecUsdcBal = tokens[3].balanceOf(address(accounts[1]));
            noDecUsdcBal = noDecUsdcBal.div(decimals[3]);
            assertApproxEqAbs(noDecForexBal, noDecUsdcBal, noDecUsdcBal.div(dividends[i]));
        }
    }

    // // checks if directly sending pool tokens, not by calling deposit func of the pool
    // // see if the pool token total supply is changed
    // // directly tranferring tokens to the pool shouldn't change the pool total supply
    function testTotalSupply(uint256 amount) public {
        cheats.assume(amount > 1);
        cheats.assume(amount < 10000000);
        for(uint256 i = 0; i < 3; ++i){
            uint256 originalSupply = curves[i].totalSupply();
            // first stake to get lp tokens
            uint256 originalLP = curves[i].balanceOf(address(tokens[i]));

            // now directly send tokens
            if(i == 0)
                tokens[i].mint(address(curves[i]), amount.div(100));
            else
                deal(address(tokens[i]),address(curves[i]), amount.div(50));
            deal(address(tokens[3]),address(curves[i]), amount.div(50));
            uint256 currentLP = curves[i].balanceOf(address(tokens[i]));
            assertApproxEqAbs(originalLP, currentLP,0);
        }
    }

    // /*
    // * user swaps gold to usdc then does reverse swap into gold from usdc
    // swap amount is relatively huge compare to the pool balance
    // after 2 rounds of swap, user gets almost same amount of gold to the original gold balance
    //  */
    function testSwapDifference (uint256 percentage) public {
        cheats.assume(percentage > 0);
        cheats.assume(percentage < 30);
        for(uint256 i = 0; i < 3; ++i){
            // first deposit from the depositor
            cheats.startPrank(address(accounts[0]));
            curves[i].deposit(10000000 * decimals[i], block.timestamp + 60);
            cheats.stopPrank();
            uint256 poolForexBal = tokens[i].balanceOf(address(curves[i]));
            // mint gold to trader
            if(i == 0)
                tokens[i].mint(address(accounts[1]), poolForexBal.div(100).mul(percentage));
            else
                deal(address(tokens[i]),address(accounts[1]), poolForexBal.div(100).mul(percentage));
            cheats.startPrank(address(accounts[1]));
            tokens[i].approve(address(curves[i]), type(uint).max);
            tokens[3].approve(address(curves[i]), type(uint).max);
            uint256 originalForexBal = tokens[i].balanceOf(address(accounts[1]));
            // first swap gold into usdc
            curves[i].originSwap(
                address(tokens[i]),
                address(tokens[3]),
                originalForexBal,
                0,
                block.timestamp + 60);
            // now swaps back usdc into gold
            curves[i].originSwap(
                address(tokens[3]),
                address(tokens[i]),
                tokens[3].balanceOf(address(accounts[1])),
                0,
                block.timestamp + 60
            );
            uint256 currentGoldBal = tokens[i].balanceOf(address(accounts[1]));
            assertApproxEqAbs(
                originalForexBal,
                currentGoldBal,
                originalForexBal.div(100)
            );
            cheats.stopPrank();
        }
    }

    function testInvariant (uint256 percentage) public {
        cheats.assume(percentage > 0);
        cheats.assume(percentage < 100);
        for(uint256 i = 0; i < 3; ++i){
            cheats.startPrank(address(accounts[0]));
            curves[i].deposit(10000000 * decimals[i], block.timestamp + 60);
            cheats.stopPrank();
            uint256 poolForexBal = tokens[i].balanceOf(address(curves[i]));
            uint256 poolUSDCBal = tokens[3].balanceOf(address(curves[i]));
            // mint some % of goldBal of the pool to the trader to swap
            if(i == 0)
                tokens[i].mint(address(accounts[i]),  poolForexBal.mul(9000000));
            else
                deal(address(tokens[i]),address(accounts[i]),  poolForexBal.mul(9000000));
            deal(address(tokens[3]),address(accounts[i]), poolUSDCBal.mul(9000000));
            // now deposit huge amount to the pool
            cheats.startPrank(address(accounts[0]));
            tokens[i].approve(address(curves[i]), type(uint).max);
            tokens[3].approve(address(curves[i]), type(uint).max);
            curves[i].deposit(poolForexBal.div(percentage).mul(100), block.timestamp + 60);
            cheats.stopPrank();
        }
    }
}
