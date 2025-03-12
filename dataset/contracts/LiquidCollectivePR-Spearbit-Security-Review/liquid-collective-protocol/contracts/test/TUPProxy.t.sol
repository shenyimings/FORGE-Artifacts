//SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.10;

import "forge-std/Test.sol";
import "./utils/LibRlp.sol";

import "../src/TUPProxy.sol";
import "../src/Firewall.sol";

contract DummyCounter {
    error BigError(uint256);
    error CallWentIn();

    uint256 public i;

    function inc() external {
        ++i;
    }

    function fail() external view {
        revert BigError(i);
    }

    function paused() external pure {
        revert CallWentIn();
    }
}

contract DummyCounterEvolved is DummyCounter {
    bool internal init;

    function superInc() external {
        ++i;
        ++i;
    }

    function superI() external view returns (uint256) {
        return i * i;
    }

    function initEvolved(uint256 _i) external {
        require(init == false, "already initialised");
        i = _i;
        init = true;
    }
}

contract TUPProxyTest is Test {
    DummyCounter internal implem;
    DummyCounterEvolved internal implemEvolved;
    TUPProxy internal proxy;

    address internal admin;

    event Paused(address admin);
    event Unpaused(address admin);

    function setUp() public {
        admin = makeAddr("admin");
        implem = new DummyCounter();
        implemEvolved = new DummyCounterEvolved();
        proxy = new TUPProxy(address(implem), admin, "");
    }

    function testViewFunc() public view {
        assert(DummyCounter(address(proxy)).i() == 0);
    }

    function testFunc() public {
        assert(DummyCounter(address(proxy)).i() == 0);
        DummyCounter(address(proxy)).inc();
        assert(DummyCounter(address(proxy)).i() == 1);
    }

    function testAdminFuncAsLambda() public {
        vm.expectRevert(abi.encodeWithSignature("CallWentIn()"));
        proxy.paused();
    }

    function testFuncAsAdmin() public {
        assert(DummyCounter(address(proxy)).i() == 0);
        vm.startPrank(admin);
        vm.expectRevert("TransparentUpgradeableProxy: admin cannot fallback to proxy target");
        DummyCounter(address(proxy)).inc();
    }

    function testRevert() public {
        vm.expectRevert(abi.encodeWithSignature("BigError(uint256)", 0));
        DummyCounter(address(proxy)).fail();
        DummyCounter(address(proxy)).inc();
        vm.expectRevert(abi.encodeWithSignature("BigError(uint256)", 1));
        DummyCounter(address(proxy)).fail();
    }

    function testUpgradeToAndCall() public {
        assert(DummyCounter(address(proxy)).i() == 0);
        vm.startPrank(admin);
        proxy.upgradeToAndCall(address(implemEvolved), abi.encodeWithSignature("initEvolved(uint256)", 5));
        vm.stopPrank();
        assert(DummyCounterEvolved(address(proxy)).i() == 5);
        DummyCounterEvolved(address(proxy)).superInc();
        assert(DummyCounterEvolved(address(proxy)).i() == 7);
        assert(DummyCounterEvolved(address(proxy)).superI() == 49);
    }

    function testPause() public {
        assert(DummyCounter(address(proxy)).i() == 0);
        DummyCounter(address(proxy)).inc();
        assert(DummyCounter(address(proxy)).i() == 1);
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit Paused(admin);
        proxy.pause();
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSignature("CallWhenPaused()"));
        DummyCounter(address(proxy)).inc();
    }

    function testUnPause() public {
        assert(DummyCounter(address(proxy)).i() == 0);
        DummyCounter(address(proxy)).inc();
        assert(DummyCounter(address(proxy)).i() == 1);
        vm.startPrank(admin);
        proxy.pause();
        assert(proxy.paused() == true);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSignature("CallWhenPaused()"));
        DummyCounter(address(proxy)).inc();
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit Unpaused(admin);
        proxy.unpause();
        assert(proxy.paused() == false);
        vm.stopPrank();
        DummyCounter(address(proxy)).inc();
        assert(DummyCounter(address(proxy)).i() == 2);
    }

    function testPauseAddressZeroFallback() public {
        assert(DummyCounter(address(proxy)).i() == 0);
        DummyCounter(address(proxy)).inc();
        assert(DummyCounter(address(proxy)).i() == 1);
        vm.startPrank(admin);
        proxy.pause();
        vm.stopPrank();

        vm.startPrank(address(0));
        assert(DummyCounter(address(proxy)).i() == 1);
        vm.stopPrank();
    }
}

contract TUPProxyBehindFirewallTest is Test {
    DummyCounter internal implem;
    DummyCounterEvolved internal implemEvolved;
    TUPProxy internal proxy;

    address internal governor;
    address internal executor;
    address internal firewall;

    event Paused(address admin);
    event Unpaused(address admin);

    function setUp() public {
        governor = makeAddr("governor");
        executor = makeAddr("executor");
        implem = new DummyCounter();

        address predictedProxy = LibRLP.computeAddress(address(this), vm.getNonce(address(this)) + 1);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(keccak256(bytes("pause()")));
        firewall = address(new Firewall(governor, executor, predictedProxy, selectors));
        proxy = new TUPProxy(address(implem), address(firewall), "");
        implemEvolved = new DummyCounterEvolved();
    }

    function testViewFunc() public view {
        assert(DummyCounter(address(proxy)).i() == 0);
    }

    function testFunc() public {
        assert(DummyCounter(address(proxy)).i() == 0);
        DummyCounter(address(proxy)).inc();
        assert(DummyCounter(address(proxy)).i() == 1);
    }

    function testAdminFuncAsLambda() public {
        vm.expectRevert(abi.encodeWithSignature("CallWentIn()"));
        proxy.paused();
    }

    function testFuncAsAdmin() public {
        assert(DummyCounter(address(proxy)).i() == 0);
        vm.startPrank(firewall);
        vm.expectRevert("TransparentUpgradeableProxy: admin cannot fallback to proxy target");
        DummyCounter(address(proxy)).inc();
    }

    function testRevert() public {
        vm.expectRevert(abi.encodeWithSignature("BigError(uint256)", 0));
        DummyCounter(address(proxy)).fail();
        DummyCounter(address(proxy)).inc();
        vm.expectRevert(abi.encodeWithSignature("BigError(uint256)", 1));
        DummyCounter(address(proxy)).fail();
    }

    function testUpgradeToAndCallFromGovernor() public {
        assert(DummyCounter(address(proxy)).i() == 0);
        vm.prank(governor);
        TUPProxy(payable(address(firewall))).upgradeToAndCall(
            address(implemEvolved), abi.encodeWithSignature("initEvolved(uint256)", 5)
        );
        assert(DummyCounterEvolved(address(proxy)).i() == 5);
        DummyCounterEvolved(address(proxy)).superInc();
        assert(DummyCounterEvolved(address(proxy)).i() == 7);
        assert(DummyCounterEvolved(address(proxy)).superI() == 49);
    }

    function testUpgradeToAndCallFromExecutor() public {
        assert(DummyCounter(address(proxy)).i() == 0);
        vm.prank(executor);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", executor));
        TUPProxy(payable(address(firewall))).upgradeToAndCall(
            address(implemEvolved), abi.encodeWithSignature("initEvolved(uint256)", 5)
        );
    }

    function testPauseFromGovernor() public {
        assert(DummyCounter(address(proxy)).i() == 0);
        DummyCounter(address(proxy)).inc();
        assert(DummyCounter(address(proxy)).i() == 1);
        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit Paused(address(firewall));
        TUPProxy(payable(address(firewall))).pause();
        vm.expectRevert(abi.encodeWithSignature("CallWhenPaused()"));
        DummyCounter(address(proxy)).inc();
    }

    function testPauseFromExecutor() public {
        assert(DummyCounter(address(proxy)).i() == 0);
        DummyCounter(address(proxy)).inc();
        assert(DummyCounter(address(proxy)).i() == 1);
        vm.prank(executor);
        vm.expectEmit(true, true, true, true);
        emit Paused(address(firewall));
        TUPProxy(payable(address(firewall))).pause();
        vm.expectRevert(abi.encodeWithSignature("CallWhenPaused()"));
        DummyCounter(address(proxy)).inc();
    }

    function testUnPauseFromGovernor() public {
        assert(DummyCounter(address(proxy)).i() == 0);
        DummyCounter(address(proxy)).inc();
        assert(DummyCounter(address(proxy)).i() == 1);
        vm.prank(governor);
        TUPProxy(payable(address(firewall))).pause();
        vm.prank(address(firewall));
        assert(proxy.paused() == true);
        vm.expectRevert(abi.encodeWithSignature("CallWhenPaused()"));
        DummyCounter(address(proxy)).inc();
        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit Unpaused(address(firewall));
        TUPProxy(payable(address(firewall))).unpause();
        vm.prank(address(firewall));
        assert(proxy.paused() == false);
        DummyCounter(address(proxy)).inc();
        assert(DummyCounter(address(proxy)).i() == 2);
    }

    function testUnPauseFromExecutor() public {
        assert(DummyCounter(address(proxy)).i() == 0);
        DummyCounter(address(proxy)).inc();
        assert(DummyCounter(address(proxy)).i() == 1);
        vm.prank(executor);
        TUPProxy(payable(address(firewall))).pause();
        vm.prank(address(firewall));
        assert(proxy.paused() == true);
        vm.expectRevert(abi.encodeWithSignature("CallWhenPaused()"));
        DummyCounter(address(proxy)).inc();
        vm.prank(executor);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(executor)));
        TUPProxy(payable(address(firewall))).unpause();
        vm.prank(address(firewall));
        assert(proxy.paused() == true);
        vm.expectRevert(abi.encodeWithSignature("CallWhenPaused()"));
        DummyCounter(address(proxy)).inc();
    }

    function testPauseAddressZeroFallback() public {
        assert(DummyCounter(address(proxy)).i() == 0);
        DummyCounter(address(proxy)).inc();
        assert(DummyCounter(address(proxy)).i() == 1);
        vm.prank(governor);
        TUPProxy(payable(address(firewall))).pause();

        vm.startPrank(address(0));
        assert(DummyCounter(address(proxy)).i() == 1);
        vm.stopPrank();
    }
}
