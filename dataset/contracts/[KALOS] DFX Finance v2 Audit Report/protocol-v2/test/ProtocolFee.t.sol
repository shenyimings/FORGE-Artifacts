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

contract ProtocolFeeTest is Test {
    using SafeMath for uint256;
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    Utils utils;

    // account order is lp provider, trader, treasury, burn address
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
        for(uint256 i = 0; i < 4; ++i){
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
                tokens[0].mint(address(accounts[0]), mintAmt.mul(1e18));
            }
            else{
                deal(address(tokens[i]), address(accounts[0]), mintAmt.mul(1e18));
            }
        }
        // now approve
        cheats.startPrank(address(accounts[0]));
        for(uint256 i = 0; i < 3; ++i){
            tokens[i].approve(address(curves[i]), type(uint).max);
            tokens[3].approve(address(curves[i]), type(uint).max);
            curves[i].deposit(100_000_000_000 * 1e18, block.timestamp + 60);
        }
        cheats.stopPrank();
    }
    
    function testProtocolFeeUsdcCadcSwap(uint256 mintAmount) public {
        cheats.assume(mintAmount > 10000);
        cheats.assume(mintAmount < 10000000);
        
        for(uint256 i = 0 ; i < 3; ++i){

            deal(address(tokens[i]), address(accounts[1]), mintAmount * decimals[i]);

            cheats.startPrank(address(accounts[1]));
            tokens[i].approve(address(curves[i]), type(uint256).max);
            tokens[3].approve(address(curves[i]), type(uint256).max);

            uint256 traderOriginalUsdcBal = tokens[3].balanceOf(address(accounts[1]));
            uint256 traderOriginalTokeniBal = tokens[i].balanceOf(address(accounts[1]));
            uint256 treasuryOriginalUsdcBal = tokens[3].balanceOf(address(accounts[2]));
            uint256 treasuryOriginalTokeniBal = tokens[i].balanceOf(address(accounts[2]));

            // now swap
            curves[i].originSwap(
                address(tokens[i]),
                address(tokens[3]),
                traderOriginalTokeniBal,
                0,
                block.timestamp + 60
            );

            uint256 trader1stUsdcBal = tokens[3].balanceOf(address(accounts[1]));
            uint256 trader1stTokeniBal = tokens[i].balanceOf(address(accounts[1]));
            uint256 treasury1stUsdcBal = tokens[3].balanceOf(address(accounts[2]));
            uint256 treasury1stTokeniBal = tokens[i].balanceOf(address(accounts[2]));

            // now swap back
            curves[i].originSwap(
                address(tokens[3]),
                address(tokens[i]),
                treasury1stUsdcBal,
                0,
                block.timestamp + 60
            );

            uint256 trader2ndUsdcBal = tokens[3].balanceOf(address(accounts[1]));
            uint256 trader2ndTokeniBal = tokens[i].balanceOf(address(accounts[1]));
            uint256 treasury2ndUsdcBal = tokens[3].balanceOf(address(accounts[2]));
            uint256 treasury2ndTokeniBal = tokens[i].balanceOf(address(accounts[2]));
            cheats.stopPrank();
            // now burn tokens from treasury
            cheats.startPrank(address(accounts[2]));
            tokens[i].transfer(address(accounts[3]), treasury2ndTokeniBal);
            tokens[3].transfer(address(accounts[3]), treasury2ndUsdcBal);
            cheats.stopPrank();
            cheats.startPrank(address(accounts[1]));
            tokens[i].transfer(address(accounts[3]), trader2ndTokeniBal);
            tokens[3].transfer(address(accounts[3]), trader2ndUsdcBal);
            cheats.stopPrank();

            // assert
            assertApproxEqAbs(
                (trader2ndUsdcBal+treasury2ndUsdcBal).div(treasury2ndUsdcBal),
                5000,
                160
            );
            assertApproxEqAbs(
                (trader2ndTokeniBal+treasury2ndTokeniBal).div(treasury2ndTokeniBal),
                5000,
                160
            );
        }
    }

    
}