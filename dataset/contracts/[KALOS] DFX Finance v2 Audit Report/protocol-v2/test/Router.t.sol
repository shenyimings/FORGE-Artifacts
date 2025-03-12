
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
import "../src/Router.sol";
import "../src/lib/ABDKMath64x64.sol";

import "./lib/MockUser.sol";
import "./lib/CheatCodes.sol";
import "./lib/Address.sol";
import "./lib/CurveParams.sol";

contract RouterTest is Test {
    using SafeMath for uint256;

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    MockUser multisig;
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

    int128 public protocolFee = 50;

    AssimilatorFactory assimilatorFactory;
    CurveFactoryV2 curveFactory;
    Router router;
    Curve[fxTokenCount] dfxCurves;

    function setUp() public {
        multisig = new MockUser();

        for (uint8 i = 0; i < users.length; i++) {
            users[i] = new MockUser();
        }

        assimilatorFactory = new AssimilatorFactory();
        
        curveFactory = new CurveFactoryV2(
            protocolFee,
            address(multisig),
            address(assimilatorFactory)
        );

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
            uint256 decimals = 10 ** foreignStables[i].decimals();
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

    function routerOriginSwapAndCheck(
        IERC20Detailed fromToken, 
        IERC20Detailed toToken, 
        IOracle fromOracle, 
        IOracle toOracle, 
        uint256 _amount) public {
        
        uint8 fromDecimals = fromToken.decimals();
        uint8 toDecimals = toToken.decimals();

        uint256 amount = uint256(_amount).mul(10 ** fromDecimals);

        deal(address(fromToken), address(this), amount);
        fromToken.approve(address(router), type(uint).max);
            
        uint256 beforeAmount = toToken.balanceOf(address(this));
        
        router.originSwap(Mainnet.USDC, address(fromToken), address(toToken), amount, 0, block.timestamp + 60);
        
        uint256 afterAmount = toToken.balanceOf(address(this));

        // Get oracle rates assuming decimals are equal
        uint256 fromRate = uint256(fromOracle.latestAnswer());
        uint256 toRate = uint256(toOracle.latestAnswer());

        uint256 obtained = afterAmount.sub(beforeAmount);
        uint256 expected = amount.mul(fromRate).div(toRate);

        if (fromDecimals <= toDecimals) {
            uint8 decimalsDiff = toDecimals - fromDecimals;
            expected = expected.mul(10 ** decimalsDiff);
        } else {
            uint8 decimalsDiff = fromDecimals - toDecimals;
            expected = expected.div(10 ** decimalsDiff);
        }

        // 99% approximate
        assertApproxEqRel(obtained, expected, 0.01e18);
    }

    function routerViewTargetSwapAndCheck(
        IERC20Detailed fromToken, 
        IERC20Detailed toToken, 
        IOracle fromOracle, 
        IOracle toOracle, 
        uint256 _amount) public {

        uint8 fromDecimals = fromToken.decimals();
        uint8 toDecimals = toToken.decimals();

        uint256 amount = uint256(_amount).mul(10 ** toDecimals);

        // Get oracle rates assuming decimals are equal
        uint256 fromRate = uint256(fromOracle.latestAnswer());
        uint256 toRate = uint256(toOracle.latestAnswer());

        uint256 obtained = router.viewTargetSwap(Mainnet.USDC, address(fromToken), address(toToken), amount);

        uint256 expected = amount.mul(toRate).div(fromRate);
        
        emit log_uint(expected);

        if (fromDecimals <= toDecimals) {
            uint8 decimalsDiff = toDecimals - fromDecimals;
            expected = expected.div(10 ** decimalsDiff);
        } else {
            uint8 decimalsDiff = fromDecimals - toDecimals;
            expected = expected.mul(10 ** decimalsDiff);
        }
        
        assertApproxEqRel(obtained, expected, 0.01e18);
    }
    
    // TARGET SWAPS
    function testCadcToUsdcTargetSwap(uint256 _amount) public {
        cheats.assume(_amount > 100);
        cheats.assume(_amount < 10_000_000);

        routerViewTargetSwapAndCheck(cadc, usdc, cadcOracle, usdcOracle, _amount);
    }
    
    function testUsdcToCadcTargetSwap(uint256 _amount) public {
        cheats.assume(_amount > 100);
        cheats.assume(_amount < 10_000_000);

        routerViewTargetSwapAndCheck(usdc, cadc, usdcOracle, cadcOracle, _amount);
    }

    function testCadcToXsgdTargetSwap(uint256 _amount) public {
        cheats.assume(_amount > 100);
        cheats.assume(_amount < 10_000_000);

        routerViewTargetSwapAndCheck(cadc, xsgd, cadcOracle, xsgdOracle, _amount);
    }

    function testCadcToEurocTargetSwap(uint256 _amount) public {
        cheats.assume(_amount > 100);
        cheats.assume(_amount < 10_000_000);

        routerViewTargetSwapAndCheck(cadc, euroc, cadcOracle, eurocOracle, _amount);
    }

    function testEurocToXsgdTargetSwap(uint256 _amount) public {
        cheats.assume(_amount > 100);
        cheats.assume(_amount < 10_000_000);

        routerViewTargetSwapAndCheck(euroc, xsgd, eurocOracle, xsgdOracle, _amount);
    }

    function testXsgdToEurocTargetSwap(uint256 _amount) public {
        cheats.assume(_amount > 100);
        cheats.assume(_amount < 10_000_000);

        routerViewTargetSwapAndCheck(xsgd, euroc, xsgdOracle, eurocOracle, _amount);
    }

    function testXsgdToCadcTargetSwap(uint256 _amount) public {
        cheats.assume(_amount > 100);
        cheats.assume(_amount < 10_000_000);

        routerViewTargetSwapAndCheck(xsgd, cadc, xsgdOracle, cadcOracle, _amount);
    }

    function testEurocToCadcTargetSwap(uint256 _amount) public {
        cheats.assume(_amount > 100);
        cheats.assume(_amount < 10_000_000);

        routerViewTargetSwapAndCheck(euroc, cadc, eurocOracle, cadcOracle, _amount);
    }

    // ORIGIN SWAPS
    function testCadcToUsdcOriginSwap(uint256 _amount) public {
        cheats.assume(_amount > 100);
        cheats.assume(_amount < 10_000_000);

        routerOriginSwapAndCheck(cadc, usdc, cadcOracle, usdcOracle, _amount);
    }

    function testUsdcToXsgdOriginSwap(uint256 _amount) public {
        cheats.assume(_amount > 100);
        cheats.assume(_amount < 10_000_000);

        routerOriginSwapAndCheck(usdc, xsgd, usdcOracle, xsgdOracle, _amount);
    }

    function testCadcToEursOriginSwap(uint256 _amount) public {
        cheats.assume(_amount > 100);
        cheats.assume(_amount < 10_000_000);

        routerOriginSwapAndCheck(cadc, euroc, cadcOracle, eurocOracle, _amount);
    }

    function testCadcToXsgdOriginSwap(uint256 _amount) public {
        cheats.assume(_amount > 10);
        cheats.assume(_amount < 10_000_000);

        routerOriginSwapAndCheck(cadc, xsgd, cadcOracle, xsgdOracle, _amount);
    }

    function testEurocToXsgdOriginSwap(uint256 _amount) public {
        cheats.assume(_amount > 100);
        cheats.assume(_amount < 10_000_000);

        routerOriginSwapAndCheck(euroc, xsgd, eurocOracle, xsgdOracle, _amount);
    }

    function testEurocToCadcOriginSwap(uint256 _amount) public {
        cheats.assume(_amount > 100);
        cheats.assume(_amount < 10_000_000);

        routerOriginSwapAndCheck(euroc, cadc, eurocOracle, cadcOracle, _amount);
    }

    function testXSGDToEurocOriginSwap(uint256 _amount) public {
        cheats.assume(_amount > 100);
        cheats.assume(_amount < 10_000_000);

        routerOriginSwapAndCheck(xsgd, euroc, xsgdOracle, eurocOracle, _amount);
    }

    function testXSGDToCadcOriginSwap(uint256 _amount) public {
        cheats.assume(_amount > 100);
        cheats.assume(_amount < 10_000_000);

        routerOriginSwapAndCheck(xsgd, cadc, xsgdOracle, cadcOracle, _amount);
    }


    // Global Transactable State Frozen
    function testFail_GlobalFrozenOriginSwap() public {
        // Cannot make swaps because global state is frozen
        ICurveFactory(address(curveFactory)).setGlobalFrozen(true);
        routerOriginSwapAndCheck(cadc, euroc, cadcOracle, eurocOracle, 100_000);
    }

     function testFail_GlobalFrozenTargetSwap() public {
        // Cannot make swaps because global state is frozen
        ICurveFactory(address(curveFactory)).setGlobalFrozen(true);
        routerViewTargetSwapAndCheck(euroc, xsgd, usdcOracle, cadcOracle, 100_000);
    }
}
