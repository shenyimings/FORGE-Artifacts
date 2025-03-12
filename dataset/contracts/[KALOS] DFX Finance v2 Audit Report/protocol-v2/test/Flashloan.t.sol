
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../src/interfaces/IAssimilator.sol";
import "../src/interfaces/IOracle.sol";
import "../src/interfaces/ICurve.sol";
import "../src/interfaces/IERC20Detailed.sol";
import "../src/AssimilatorFactory.sol";
import "../src/CurveFactoryV2.sol";
import "../src/Curve.sol";
import "../src/Structs.sol";
import "../src/Router.sol";
import "../src/lib/ABDKMath64x64.sol";
import "../src/lib/FullMath.sol";

import "./lib/MockUser.sol";
import "./lib/CheatCodes.sol";
import "./lib/Address.sol";
import "./lib/CurveParams.sol";
import "./utils/Utils.sol";
import "./utils/CurveFlash.sol";
import "./utils/CurveFlashReentrancy.sol";

contract FlashloanTest is Test {
    using SafeMath for uint256;

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    Utils utils;

    MockUser multisig;
    MockUser flashloaner;
    MockUser[2] public users;

    IERC20Detailed usdc = IERC20Detailed(Mainnet.USDC);
    IERC20Detailed cadc = IERC20Detailed(Mainnet.CADC);
    IERC20Detailed xsgd = IERC20Detailed(Mainnet.XSGD);
    IERC20Detailed euroc = IERC20Detailed(Mainnet.EUROC);

    uint8 constant fxTokenCount = 3;

    IERC20Detailed[] public foreignStables = [
        cadc,
        xsgd, 
        euroc, 
        usdc
    ];

    IOracle usdcOracle = IOracle(Mainnet.CHAINLINK_USDC_USD);
    IOracle cadcOracle = IOracle(Mainnet.CHAINLINK_CAD_USD);
    IOracle xsgdOracle = IOracle(Mainnet.CHAINLINK_SGD_USD);
    IOracle eurocOracle = IOracle(Mainnet.CHAINLINK_EUR_USD);

    IOracle[] public foreignOracles = [
        cadcOracle,
        xsgdOracle,
        eurocOracle,
        usdcOracle
    ];

    int128 public protocolFee = 50000;

    AssimilatorFactory assimilatorFactory;
    CurveFactoryV2 curveFactory;
    Router router;
    Curve[fxTokenCount] dfxCurves;
    CurveFlash curveFlash;
    CurveFlashReentrancy curveFlashReentrancy;

    function setUp() public {
        multisig = new MockUser();
        flashloaner = new MockUser();
        utils = new Utils();
        curveFlash = new CurveFlash();
        curveFlashReentrancy = new CurveFlashReentrancy();

        for (uint8 i = 0; i < users.length; i++) {
            users[i] = new MockUser();
        }

        assimilatorFactory = new AssimilatorFactory();
        
        curveFactory = new CurveFactoryV2(
            protocolFee,
            address(multisig),
            address(assimilatorFactory)
        );

        curveFactory.transferOwnership(address(multisig));

        cheats.prank(address(multisig));
        curveFactory.setFlashable(true);

        router = new Router(address(curveFactory));
        
        assimilatorFactory.setCurveFactory(address(curveFactory));
        
        cheats.startPrank(address(multisig));
        for (uint8 i = 0; i < fxTokenCount; i++) {
            CurveInfo memory curveInfo = CurveInfo(
                string.concat("dfx-", foreignStables[i].symbol()),
                string.concat("dfx-", foreignStables[i].symbol()),
                address(foreignStables[i]),
                address(usdc),
                DefaultCurve.BASE_WEIGHT,
                DefaultCurve.QUOTE_WEIGHT,
                foreignOracles[i],
                foreignStables[i].decimals(),
                usdcOracle,
                usdc.decimals(),
                DefaultCurve.ALPHA,
                DefaultCurve.BETA,
                DefaultCurve.MAX,
                DefaultCurve.EPSILON,
                DefaultCurve.LAMBDA
            );

            dfxCurves[i] = curveFactory.newCurve(curveInfo);
        }
        cheats.stopPrank();

        uint256 user1TknAmnt = 300_000_000;

        // Mint Foreign Stables
        for (uint8 i = 0; i <= fxTokenCount; i++) {
            uint256 decimals = utils.tenToPowerOf(foreignStables[i].decimals());
            deal(address(foreignStables[i]), address(users[0]), user1TknAmnt.mul(decimals));
        }
        
        cheats.startPrank(address(users[0]));
        for (uint8 i = 0; i < fxTokenCount; i++) {            
            foreignStables[i].approve(address(dfxCurves[i]), type(uint).max);
            foreignStables[i].approve(address(router), type(uint).max);
            usdc.approve(address(dfxCurves[i]), type(uint).max);
        }
        usdc.approve(address(router), type(uint).max);
        cheats.stopPrank();

        cheats.startPrank(address(users[0]));
        for (uint8 i = 0; i < fxTokenCount; i++) {           
            dfxCurves[i].deposit(100_000_000e18, block.timestamp + 60);
        }
        cheats.stopPrank();
    }

    // Normal Flashloan
    function testFlashloanCadc(uint256 flashAmount0, uint256 flashAmount1) public {
        IERC20Detailed token0 = cadc;
        IERC20Detailed token1 = usdc;
        Curve curve = dfxCurves[0];

        cheats.assume(flashAmount0 > 0);
        cheats.assume(flashAmount0 < 10_000_000);
        cheats.assume(flashAmount1 > 0);
        cheats.assume(flashAmount1 < 10_000_000);

        // epsilon
        (,,,uint256 fee,) = curve.viewCurve();

        uint256 dec0 = utils.tenToPowerOf(token0.decimals());
        uint256 dec1 = utils.tenToPowerOf(token1.decimals());

        deal(address(token0), address(curveFlash), uint256(100_000).mul(dec0));
        deal(address(token1), address(curveFlash), uint256(100_000).mul(dec1));

        uint256 derivative0Before = token0.balanceOf(address(curve));
        uint256 derivative1Before = token1.balanceOf(address(curve));

        FlashParams memory flashData = FlashParams({
            token0: address(token0),
            token1: address(token1),
            amount0: flashAmount0.mul(dec0),
            amount1: flashAmount1.mul(dec1),
            decimal0: dec0,
            decimal1: dec1
        });

        curveFlash.initFlash(address(curve), flashData);

        uint256 derivative0After = token0.balanceOf(address(curve));
        uint256 derivative1After = token1.balanceOf(address(curve));

        uint256 generatedFee0 = FullMath.mulDivRoundingUp(flashData.amount0, fee, 1e18);
        uint256 generatedFee1 = FullMath.mulDivRoundingUp(flashData.amount1, fee, 1e18);

        // Should transfer the ownership to multisig tho
        assertEq(generatedFee0, token0.balanceOf(address(multisig)));
        assertEq(generatedFee1, token1.balanceOf(address(multisig)));

        assertGe(derivative0After, derivative0Before);
        assertGe(derivative1After, derivative1Before);
    }

    function testFlashloanXsgd(uint256 flashAmount0, uint256 flashAmount1) public {
        IERC20Detailed token0 = xsgd;
        IERC20Detailed token1 = usdc;
        Curve curve = dfxCurves[1];

        cheats.assume(flashAmount0 > 0);
        cheats.assume(flashAmount0 < 10_000_000);
        cheats.assume(flashAmount1 > 0);
        cheats.assume(flashAmount1 < 10_000_000);

        (,,,uint256 fee,) = curve.viewCurve();

        uint256 dec0 = utils.tenToPowerOf(token0.decimals());
        uint256 dec1 = utils.tenToPowerOf(token1.decimals());

        deal(address(token0), address(curveFlash), uint256(100_000).mul(dec0));
        deal(address(token1), address(curveFlash), uint256(100_000).mul(dec1));

        uint256 derivative0Before = token0.balanceOf(address(curve));
        uint256 derivative1Before = token1.balanceOf(address(curve));

        FlashParams memory flashData = FlashParams({
            token0: address(token0),
            token1: address(token1),
            amount0: flashAmount0.mul(dec0),
            amount1: flashAmount1.mul(dec1),
            decimal0: dec0,
            decimal1: dec1
        });

        curveFlash.initFlash(address(curve), flashData);
        
        uint256 derivative0After = token0.balanceOf(address(curve));
        uint256 derivative1After = token1.balanceOf(address(curve));

        uint256 generatedFee0 = FullMath.mulDivRoundingUp(flashData.amount0, fee, 1e18);
        uint256 generatedFee1 = FullMath.mulDivRoundingUp(flashData.amount1, fee, 1e18);

        // Should transfer the ownership to multisig tho
        assertEq(generatedFee0, token0.balanceOf(address(multisig)));
        assertEq(generatedFee1, token1.balanceOf(address(multisig)));

        assertGe(derivative0After, derivative0Before);
        assertGe(derivative1After, derivative1Before);
    }

    function testFlashloanEuro(uint256 flashAmount0, uint256 flashAmount1) public {
        IERC20Detailed token0 = euroc;
        IERC20Detailed token1 = usdc;
        Curve curve = dfxCurves[2];

        cheats.assume(flashAmount0 > 0);
        cheats.assume(flashAmount0 < 10_000_000);
        cheats.assume(flashAmount1 > 0);
        cheats.assume(flashAmount1 < 10_000_000);

        (,,,uint256 fee,) = curve.viewCurve();

        uint256 dec0 = utils.tenToPowerOf(token0.decimals());
        uint256 dec1 = utils.tenToPowerOf(token1.decimals());

        deal(address(token0), address(curveFlash), uint256(100_000).mul(dec0));
        deal(address(token1), address(curveFlash), uint256(100_000).mul(dec1));

        uint256 derivative0Before = token0.balanceOf(address(curve));
        uint256 derivative1Before = token1.balanceOf(address(curve));

        FlashParams memory flashData = FlashParams({
            token0: address(token0),
            token1: address(token1),
            amount0: flashAmount0.mul(dec0),
            amount1: flashAmount1.mul(dec1),
            decimal0: dec0,
            decimal1: dec1
        });

        curveFlash.initFlash(address(curve), flashData);
        
        uint256 derivative0After = token0.balanceOf(address(curve));
        uint256 derivative1After = token1.balanceOf(address(curve));

        uint256 generatedFee0 = FullMath.mulDivRoundingUp(flashData.amount0, fee, 1e18);
        uint256 generatedFee1 = FullMath.mulDivRoundingUp(flashData.amount1, fee, 1e18);

        // Should transfer the ownership to multisig tho
        assertEq(generatedFee0, token0.balanceOf(address(multisig)));
        assertEq(generatedFee1, token1.balanceOf(address(multisig)));

        assertGe(derivative0After, derivative0Before);
        assertGe(derivative1After, derivative1Before);
    }

    function testFail_FlashloanFeeCadc(uint256 flashAmount0, uint256 flashAmount1) public {
        IERC20Detailed token0 = cadc;
        IERC20Detailed token1 = usdc;
        Curve curve = dfxCurves[0];

        cheats.assume(flashAmount0 > 0);
        cheats.assume(flashAmount0 < 10_000_000);
        cheats.assume(flashAmount1 > 0);
        cheats.assume(flashAmount1 < 10_000_000);

        (,,,uint256 flashFee,) = curve.viewCurve();

        uint256 dec0 = utils.tenToPowerOf(token0.decimals());
        uint256 dec1 = utils.tenToPowerOf(token1.decimals());

        // Dealing less than what can be paid back
        uint256 dealAmount0 = flashAmount0.mul(flashFee).div(1e18).sub(uint(1));
        uint256 dealAmount1 = flashAmount1.mul(flashFee).div(1e18).sub(uint(1));
        deal(address(token0), address(curveFlash), dealAmount0.mul(dec0));
        deal(address(token1), address(curveFlash), dealAmount1.mul(dec1));

        FlashParams memory flashData = FlashParams({
            token0: address(token0),
            token1: address(token1),
            amount0: flashAmount0.mul(dec0),
            amount1: flashAmount1.mul(dec1),
            decimal0: dec0,
            decimal1: dec1
        });

        curveFlash.initFlash(address(curve), flashData);
    }

    function testFail_FlashloanFeeXsgd(uint256 flashAmount0, uint256 flashAmount1) public {
        IERC20Detailed token0 = xsgd;
        IERC20Detailed token1 = usdc;
        Curve curve = dfxCurves[1];

        cheats.assume(flashAmount0 > 0);
        cheats.assume(flashAmount0 < 10_000_000);
        cheats.assume(flashAmount1 > 0);
        cheats.assume(flashAmount1 < 10_000_000);

        (,,,uint256 flashFee,) = curve.viewCurve();

        uint256 dec0 = utils.tenToPowerOf(token0.decimals());
        uint256 dec1 = utils.tenToPowerOf(token1.decimals());

        // Dealing less than what can be paid back
        uint256 dealAmount0 = flashAmount0.mul(flashFee).div(1e18).sub(uint(1));
        uint256 dealAmount1 = flashAmount1.mul(flashFee).div(1e18).sub(uint(1));
        deal(address(token0), address(curveFlash), dealAmount0.mul(dec0));
        deal(address(token1), address(curveFlash), dealAmount1.mul(dec1));

        FlashParams memory flashData = FlashParams({
            token0: address(token0),
            token1: address(token1),
            amount0: flashAmount0.mul(dec0),
            amount1: flashAmount1.mul(dec1),
            decimal0: dec0,
            decimal1: dec1
        });

        curveFlash.initFlash(address(curve), flashData);
    }

    function testFail_FlashloanFeeEuroc(uint256 flashAmount0, uint256 flashAmount1) public {
        IERC20Detailed token0 = euroc;
        IERC20Detailed token1 = usdc;
        Curve curve = dfxCurves[2];

        cheats.assume(flashAmount0 > 0);
        cheats.assume(flashAmount0 < 10_000_000);
        cheats.assume(flashAmount1 > 0);
        cheats.assume(flashAmount1 < 10_000_000);
    
        (,,,uint256 flashFee,) = curve.viewCurve();

        uint256 dec0 = utils.tenToPowerOf(token0.decimals());
        uint256 dec1 = utils.tenToPowerOf(token1.decimals());

        // Dealing less than what can be paid back
        uint256 dealAmount0 = flashAmount0.mul(flashFee).div(1e18).sub(uint(1));
        uint256 dealAmount1 = flashAmount1.mul(flashFee).div(1e18).sub(uint(1));
        deal(address(token0), address(curveFlash), dealAmount0.mul(dec0));
        deal(address(token1), address(curveFlash), dealAmount1.mul(dec1));

        FlashParams memory flashData = FlashParams({
            token0: address(token0),
            token1: address(token1),
            amount0: flashAmount0.mul(dec0),
            amount1: flashAmount1.mul(dec1),
            decimal0: dec0,
            decimal1: dec1
        });

        curveFlash.initFlash(address(curve), flashData);
    }
    
    function testFail_FlashloanCurveDepthCadc(uint256 flashAmount0, uint256 flashAmount1) public {
        IERC20Detailed token0 = cadc;
        IERC20Detailed token1 = usdc;
        Curve curve = dfxCurves[0];

        cheats.assume(flashAmount0 > 0);
        cheats.assume(flashAmount0 < 10_000_000);
        cheats.assume(flashAmount1 > 0);
        cheats.assume(flashAmount1 < 10_000_000);

        uint256 dec0 = utils.tenToPowerOf(token0.decimals());
        uint256 dec1 = utils.tenToPowerOf(token1.decimals());

        deal(address(token0), address(curveFlash), uint256(100_000).mul(dec0));
        deal(address(token1), address(curveFlash), uint256(100_000).mul(dec1));

        FlashParams memory flashData = FlashParams({
            token0: address(token0),
            token1: address(token1),
            amount0: token0.balanceOf(address(curve)).add(flashAmount0.mul(dec0)),
            amount1: token1.balanceOf(address(curve)).add(flashAmount1.mul(dec1)),
            decimal0: dec0,
            decimal1: dec1
        });

        curveFlash.initFlash(address(curve), flashData);
    }

    function testFail_FlashloanCurveDepthXsgd(uint256 flashAmount0, uint256 flashAmount1) public {
        IERC20Detailed token0 = xsgd;
        IERC20Detailed token1 = usdc;
        Curve curve = dfxCurves[1];

        cheats.assume(flashAmount0 > 0);
        cheats.assume(flashAmount0 < 10_000_000);
        cheats.assume(flashAmount1 > 0);
        cheats.assume(flashAmount1 < 10_000_000);

        uint256 dec0 = utils.tenToPowerOf(token0.decimals());
        uint256 dec1 = utils.tenToPowerOf(token1.decimals());

        deal(address(token0), address(curveFlash), uint256(100_000).mul(dec0));
        deal(address(token1), address(curveFlash), uint256(100_000).mul(dec1));

        FlashParams memory flashData = FlashParams({
            token0: address(token0),
            token1: address(token1),
            amount0: token0.balanceOf(address(curve)).add(flashAmount0.mul(dec0)),
            amount1: token1.balanceOf(address(curve)).add(flashAmount1.mul(dec1)),
            decimal0: dec0,
            decimal1: dec1
        });

        curveFlash.initFlash(address(curve), flashData);
    }

    function testFail_FlashloanCurveDepthEuroc(uint256 flashAmount0, uint256 flashAmount1) public {
        IERC20Detailed token0 = euroc;
        IERC20Detailed token1 = usdc;
        Curve curve = dfxCurves[2];

        cheats.assume(flashAmount0 > 0);
        cheats.assume(flashAmount0 < 10_000_000);
        cheats.assume(flashAmount1 > 0);
        cheats.assume(flashAmount1 < 10_000_000);

        uint256 dec0 = utils.tenToPowerOf(token0.decimals());
        uint256 dec1 = utils.tenToPowerOf(token1.decimals());

        deal(address(token0), address(curveFlash), uint256(100_000).mul(dec0));
        deal(address(token1), address(curveFlash), uint256(100_000).mul(dec1));

        FlashParams memory flashData = FlashParams({
            token0: address(token0),
            token1: address(token1),
            amount0: token0.balanceOf(address(curve)).add(flashAmount0.mul(dec0)),
            amount1: token1.balanceOf(address(curve)).add(flashAmount1.mul(dec1)),
            decimal0: dec0,
            decimal1: dec1
        });

        curveFlash.initFlash(address(curve), flashData);
    }
    
    function testFail_Reentrancy() public {
        IERC20Detailed token0 = cadc;
        IERC20Detailed token1 = usdc;
        Curve curve = dfxCurves[0];

        uint256 dec0 = utils.tenToPowerOf(token0.decimals());
        uint256 dec1 = utils.tenToPowerOf(token1.decimals());

        deal(address(token0), address(curveFlashReentrancy), uint256(100_000).mul(dec0));
        deal(address(token1), address(curveFlashReentrancy), uint256(100_000).mul(dec1));

        // view deposit before flashing
        (uint256 one, uint256[] memory derivatives) = ICurve(address(curve)).viewDeposit(100_000e18);

        FlashParams memory flashData = FlashParams({
            token0: address(token0),
            token1: address(token1),
            amount0: derivatives[0],
            amount1: derivatives[1],
            decimal0: dec0,
            decimal1: dec1
        });

        curveFlashReentrancy.initFlash(address(curve), flashData);
    }

    function testFail_NotOwnerSettingFlashable() public {
        IERC20Detailed token0 = cadc;
        IERC20Detailed token1 = usdc;
        Curve curve = dfxCurves[0];

        // Make it flashable
        curveFactory.setFlashable(false);
    }

    function testFail_Flashable() public {
        IERC20Detailed token0 = cadc;
        IERC20Detailed token1 = usdc;
        Curve curve = dfxCurves[0];

        // Make it not flashable
        cheats.prank(address(multisig));
        curveFactory.setFlashable(false);

        uint256 dec0 = utils.tenToPowerOf(token0.decimals());
        uint256 dec1 = utils.tenToPowerOf(token1.decimals());

        deal(address(token0), address(curveFlash), uint256(100_000).mul(dec0));
        deal(address(token1), address(curveFlash), uint256(100_000).mul(dec1));

        (uint256 one, uint256[] memory derivatives) = ICurve(address(curve)).viewDeposit(100_000e18);

        FlashParams memory flashData = FlashParams({
            token0: address(token0),
            token1: address(token1),
            amount0: derivatives[0],
            amount1: derivatives[1],
            decimal0: dec0,
            decimal1: dec1
        });
        
        curveFlash.initFlash(address(curve), flashData);
    }
    
    // Global Transactable State Frozen
    function testFail_GlobalFrozenFlashloans() public {
        IERC20Detailed token0 = cadc;
        IERC20Detailed token1 = usdc;
        Curve curve = dfxCurves[0];

        uint256 dec0 = utils.tenToPowerOf(token0.decimals());
        uint256 dec1 = utils.tenToPowerOf(token1.decimals());

        deal(address(token0), address(curveFlash), uint256(100_000).mul(dec0));
        deal(address(token1), address(curveFlash), uint256(100_000).mul(dec1));

        (uint256 one, uint256[] memory derivatives) = ICurve(address(curve)).viewDeposit(100_000e18);

        FlashParams memory flashData = FlashParams({
            token0: address(token0),
            token1: address(token1),
            amount0: derivatives[0],
            amount1: derivatives[1],
            decimal0: dec0,
            decimal1: dec1
        });

        ICurveFactory(address(curveFactory)).setGlobalFrozen(true);
        curveFlash.initFlash(address(curve), flashData);
    }
}
