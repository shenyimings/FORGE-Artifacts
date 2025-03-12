// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./ConicTest.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/vendor/ICurvePoolV1Eth.sol";
import "../interfaces/ICurveHandler.sol";

contract CurveHandlerTest is ConicTest {
    ICurveHandler public curveHandler;
    ICurveRegistryCache public curveRegistryCache;

    address public pool;
    bool public enteredReceive;

    function setUp() public override {
        super.setUp();
        _setFork(mainnetFork);
        IController controller = _createAndInitializeController();
        curveHandler = ICurveHandler(controller.curveHandler());
        curveRegistryCache = controller.curveRegistryCache();
        enteredReceive = false;
    }

    function _runTest() internal {
        curveRegistryCache.initPool(pool);
        IERC20 lpToken = IERC20(curveRegistryCache.lpToken(pool));

        assertFalse(curveHandler.isReentrantCall(pool), "should not be reentrant");
        // try once more to make sure that touching storage does not change the outcome
        assertFalse(curveHandler.isReentrantCall(pool), "should not be reentrant second time");

        uint256 interfaceVersion = curveRegistryCache.interfaceVersion(pool);

        if (interfaceVersion == 2) {
            uint256[2] memory amounts = [uint256(1e18), 0];
            ICurvePoolV2Eth(pool).add_liquidity{value: 1e18}(amounts, 0, true, address(this));
        } else {
            ICurvePoolV1Eth(pool).add_liquidity{value: 1e18}([uint256(1e18), 0], 0);
        }

        uint256 tokensBalance = lpToken.balanceOf(address(this));

        if (interfaceVersion == 2) {
            uint256[2] memory mins = [uint256(0), 0];
            ICurvePoolV2Eth(pool).remove_liquidity(tokensBalance, mins, true, address(this));
        } else {
            ICurvePoolV1Eth(pool).remove_liquidity(tokensBalance, [uint256(0), 0]);
        }

        // sanity check to make sure that touching other part of the storage does not change the outcome
        assertFalse(
            curveHandler.isReentrantCall(pool),
            "should not be reentrant after remove_liquidity"
        );
        assertFalse(
            curveHandler.isReentrantCall(pool),
            "should not be reentrant after remove_liquidity second time"
        );

        // ensure that the receive function actually got called
        assertTrue(enteredReceive, "receive not called");
    }

    function testStEth() public {
        pool = 0xDC24316b9AE028F1497c275EB9192a3Ea0f67022;
        _runTest();
    }

    function testStEth3() public {
        pool = 0x21E27a5E5513D6e65C4f830167390997aA84843a;
        _runTest();
    }

    function testRETH() public {
        pool = 0xF9440930043eb3997fc70e1339dBb11F341de7A8;
        _runTest();
    }

    function testCbETH() public {
        pool = 0x5FAE7E604FC3e24fd43A72867ceBaC94c65b404A;
        _runTest();
    }

    function testFrxEth() public {
        pool = 0xa1F8A6807c402E4A15ef4EBa36528A3FED24E577;
        _runTest();
    }

    function testOEth() public {
        pool = 0x94B17476A93b3262d87B9a326965D1E91f9c13E7;
        _runTest();
    }

    receive() external payable {
        enteredReceive = true;
        assertTrue(curveHandler.isReentrantCall(pool), "should be reentrant in receive");
    }
}
