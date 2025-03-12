// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../script/Deployer.s.sol";
import "../helper/TestHelper.sol";
import "../mock/StargateYieldModuleDeltaCreditMock.sol";

contract NativeGatewayTestAvax is Deployer, TestHelper {
    using SafeERC20 for IERC20;

    uint256 public DEPOSIT_AMOUNT;
    uint256 public PRECISION;
    uint256 public IOU_DECIMALS;

    event DepositNative(address indexed user, uint amount);

    function setUp() public {
        loadTestData();

        bool doDex = true;
        bool doTimelock = true;
        bool doNativeGateway = true;

        vm.startPrank(DEPLOYER);
        deployAll(doDex, doTimelock, doNativeGateway, new address[](0));
        addAllModules();
        setModuleAllocation();
        smartFarmooor.unpause();
        transferAllOwnership(doDex, doNativeGateway);
        renounceAllRoles(DEPLOYER);
        vm.stopPrank();

        IOU_DECIMALS = 1e18;
        PRECISION = 1;
        uint256 decimals = IERC20Metadata(smartFarmooor.baseToken()).decimals();
        if (decimals == 18) {
            PRECISION = 1e12;
            DEPOSIT_AMOUNT = 1000 * 10 ** IERC20Metadata(BASE_TOKEN).decimals();
        }
        if (decimals == 8) {
            PRECISION = 1e2;
            DEPOSIT_AMOUNT = 10 ** IERC20Metadata(BASE_TOKEN).decimals();
        }
        if (decimals == 6) {
            PRECISION = 1e3;
            DEPOSIT_AMOUNT = 1000 * 10 ** IERC20Metadata(BASE_TOKEN).decimals();
        }
    }

    function testInitIsCorrect() public {
        verifyNativeGateway(address(timelock), address(smartFarmooor));
    }

    function testCanDeploy() public {
        NativeGateway nativeGateway = new NativeGateway(WRAPPED_NATIVE_TOKEN, address(smartFarmooor));
        assertTrue(address(nativeGateway) != address(0));

        vm.expectRevert(bytes("NativeGateway: cannot be the zero address"));
        new NativeGateway(address(0), address(smartFarmooor));

        vm.expectRevert(bytes("NativeGateway: cannot be the zero address"));
        new NativeGateway(WRAPPED_NATIVE_TOKEN, address(0));

        BASE_TOKEN = USDC;
        deploySmartFarmooor(address(timelock), new address[](0));
        vm.expectRevert(bytes("NativeGateway: underlying is not the native token"));
        new NativeGateway(WRAPPED_NATIVE_TOKEN, address(smartFarmooor));
    }

    /** deposit native */

    function testCanDepositNative() public {
        deal(ALICE, DEPOSIT_AMOUNT);
        assertEq(ALICE.balance, DEPOSIT_AMOUNT);

        uint256 sharesBefore = smartFarmooor.balanceOf(ALICE);
        vm.prank(ALICE);
        nativeGateway.depositNative{value: DEPOSIT_AMOUNT}();
        uint256 sharesAfter = smartFarmooor.balanceOf(ALICE);

        assertEq(address(nativeGateway).balance, 0);
        assertEq(smartFarmooor.balanceOf(address(nativeGateway)), 0);
        assertEq(ALICE.balance, 0);
        assertGt(sharesAfter, sharesBefore);
    }

    function testDepositNativeEmitEvent() public {
        deal(ALICE, DEPOSIT_AMOUNT);
        assertEq(ALICE.balance, DEPOSIT_AMOUNT);

        uint256 sharesBefore = smartFarmooor.balanceOf(ALICE);
        vm.prank(ALICE);
        vm.expectEmit(false, false, false, true, address(nativeGateway));
        emit DepositNative(ALICE, DEPOSIT_AMOUNT);
        nativeGateway.depositNative{value: DEPOSIT_AMOUNT}();
    }

    function testIouIsCorrectWithDepositNative() public {
        deal(ALICE, DEPOSIT_AMOUNT);
        assertEq(ALICE.balance, DEPOSIT_AMOUNT);
        vm.prank(ALICE);
        nativeGateway.depositNative{value: DEPOSIT_AMOUNT}();

        deal(ALICE, DEPOSIT_AMOUNT / 2);
        assertEq(ALICE.balance, DEPOSIT_AMOUNT / 2);
        vm.prank(ALICE);
        nativeGateway.depositNative{value: DEPOSIT_AMOUNT / 2}();

        assertApproxEqAbs(smartFarmooor.balanceOf(ALICE), DEPOSIT_AMOUNT * 3 / 2, PRECISION);
    }

    function testCanWithdrawAfterDepositNative() public {
        testCanDepositNative();
        assertEq(IERC20(BASE_TOKEN).balanceOf(ALICE), 0);

        _moveBlock(100);

        uint256 shares = smartFarmooor.balanceOf(ALICE);
        vm.prank(ALICE);
        smartFarmooor.withdraw(shares);

        assertEq(smartFarmooor.balanceOf(ALICE), 0);
        assertGt(IERC20(BASE_TOKEN).balanceOf(ALICE), 0);
    }

    /** rescue interface */

    function testCanRescueToken() public {
        deal(JOE, address(nativeGateway), DEPOSIT_AMOUNT);
        assertEq(IERC20(JOE).balanceOf(address(nativeGateway)), DEPOSIT_AMOUNT);
        vm.startPrank(address(timelock));
        nativeGateway.rescueToken(JOE);
        vm.stopPrank();
        assertEq(IERC20(JOE).balanceOf(address(nativeGateway)), 0);
        assertEq(IERC20(JOE).balanceOf(address(timelock)), DEPOSIT_AMOUNT);
    }

    function testOnlyOwnerCanRescueToken() public {
        address token = WAVAX;
        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        nativeGateway.rescueToken(token);
    }

    function testCanRescueNative() public {
        uint256 ownerBalanceBefore = address(timelock).balance;
        deal(address(nativeGateway), DEPOSIT_AMOUNT);
        assertEq(address(nativeGateway).balance, DEPOSIT_AMOUNT);
        vm.prank(address(timelock));
        nativeGateway.rescueNative();
        assertEq(address(nativeGateway).balance, 0);
        assertEq(address(timelock).balance - ownerBalanceBefore, DEPOSIT_AMOUNT);
    }

    function testOnlyOwnerCanRescueNative() public {
        vm.prank(RANDOM_ADDRESS);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        nativeGateway.rescueNative();
    }

    /** fallback */

    function testFallbackOnlyAcceptNativeTokenComingFromWrappedNativeTokenContract() public {
        deal(WRAPPED_NATIVE_TOKEN, DEPOSIT_AMOUNT);
        vm.prank(WRAPPED_NATIVE_TOKEN);
        (bool sent,) = address(nativeGateway).call{value: DEPOSIT_AMOUNT}("");
        assertTrue(sent);
        
        deal(ALICE, DEPOSIT_AMOUNT);
        vm.prank(ALICE);
        (sent,) = address(nativeGateway).call{value: DEPOSIT_AMOUNT}("");
        assertFalse(sent);
    }
}
