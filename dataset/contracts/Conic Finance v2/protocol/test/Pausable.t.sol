// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./ConicTest.sol";

import "../contracts/Pausable.sol";

contract PausableSample is Pausable {
    uint256 public value;

    constructor(IController _controller) Pausable(_controller) {
        value = 42;
    }

    function setValue(uint256 _value) external notPaused {
        value = _value;
    }
}

contract PausableTest is ConicTest {
    event Paused(uint256 pausedUntil);

    IController public controller;
    PausableSample public pausable;

    function setUp() public override {
        super.setUp();
        controller = _createController(_getCNCToken(), _createRegistryCache());
        pausable = new PausableSample(controller);
        controller.setPauseManager(bb8, true);
    }

    function testPauseNotAuthorized() public {
        vm.expectRevert("not pause manager");
        pausable.pause();
        controller.setPauseManager(bb8, false);
        vm.prank(bb8);
        vm.expectRevert("not pause manager");
        pausable.pause();
    }

    function testPause() public {
        vm.expectEmit(true, false, false, false);
        emit Paused(block.timestamp + 3 hours);
        vm.prank(bb8);
        pausable.pause();
        assertTrue(pausable.isPaused());
        vm.expectRevert("paused");
        pausable.setValue(1);
        assertEq(pausable.value(), 42);

        skip(3 hours + 1);
        assertFalse(pausable.isPaused());
        pausable.setValue(1);
        assertEq(pausable.value(), 1);
    }

    function testPauseWithDifferentDuration() public {
        vm.prank(bb8);
        vm.expectRevert("Ownable: caller is not the owner");
        pausable.setPauseDuration(6 hours);
        assertEq(pausable.pauseDuration(), 3 hours);

        pausable.setPauseDuration(6 hours);
        assertEq(pausable.pauseDuration(), 6 hours);

        vm.prank(bb8);
        pausable.pause();
        assertTrue(pausable.isPaused());
        skip(4 hours);
        vm.expectRevert("paused");
        pausable.setValue(1);
        assertEq(pausable.value(), 42);

        skip(2 hours + 1);
        assertFalse(pausable.isPaused());
        pausable.setValue(1);
        assertEq(pausable.value(), 1);
    }
}
