// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/factories/VestingCloneFactory.sol";
import "./resources/ERC20MintableByAnyone.sol";

function checkLimits(
    uint256 _allocation,
    address _beneficiary,
    uint64 _start,
    uint64 _cliff,
    uint64 _duration,
    address _trustedForwarder
) pure returns (bool valid) {
    valid =
        _beneficiary != address(0) &&
        _beneficiary != address(_trustedForwarder) &&
        _allocation != 0 &&
        _start > 0 &&
        _start < type(uint64).max / 2 &&
        _duration < type(uint64).max / 2 &&
        _duration >= _cliff &&
        _duration > 0;
}

contract VestingTest is Test {
    event BeneficiaryChanged(uint64 id, address newBeneficiary);

    Vesting implementation;
    VestingCloneFactory factory;

    address owner = address(7);

    ERC20MintableByAnyone token = new ERC20MintableByAnyone("test token", "TST");

    Vesting vesting;

    address trustedForwarder = address(1);
    address platformAdmin = address(2);
    address beneficiary = address(3);

    uint256 exampleAmount = type(uint256).max / 1e25;
    uint64 exampleStart;
    uint64 exampleDuration = 10 * 365 days; // 10 years
    uint64 exampleCliff = 1 * 365 days; // 1 year

    function setUp() public {
        implementation = new Vesting(trustedForwarder);

        factory = new VestingCloneFactory(address(implementation));

        vesting = Vesting(factory.createVestingClone(0, trustedForwarder, owner, address(token)));

        exampleStart = 2 * 365 days;
    }

    function testSwitchOwner(address _owner, address newOwner) public {
        vm.assume(_owner != address(0));
        vm.assume(_owner != trustedForwarder);
        vm.assume(newOwner != address(0));
        vm.assume(newOwner != _owner);
        vm.assume(_owner != address(this));
        Vesting vest = Vesting(factory.createVestingClone(bytes32("1"), trustedForwarder, _owner, address(token)));
        assertEq(vest.owner(), _owner, "owner not set");

        vm.prank(_owner);
        vest.transferOwnership(newOwner);

        assertEq(vest.owner(), newOwner, "owner not changed");
    }

    function testOnlyOwnerCanCommit(address rando, bytes32 hash) public {
        Vesting vest = Vesting(factory.createVestingClone(0, trustedForwarder, address(this), address(token)));
        vm.assume(rando != address(0));
        vm.assume(rando != address(this));
        vm.assume(hash != bytes32(0));

        // rando cannot commit
        vm.prank(rando);
        vm.expectRevert("Caller is not a manager");
        vest.commit(hash);

        // owner can commit
        vest.commit(hash);
    }

    function testOnlyOwnerCanCreate(address _owner, address _rando, address _token) public {
        vm.assume(_rando != address(0));
        vm.assume(_rando != address(this));
        vm.assume(_owner != address(0));
        vm.assume(_owner != address(this));
        vm.assume(_owner != _rando);
        vm.assume(_owner != trustedForwarder);
        vm.assume(_token != address(0));

        Vesting vest = Vesting(factory.createVestingClone(0, trustedForwarder, _owner, _token));
        vm.assume(_rando != address(0));
        vm.assume(_rando != address(this));

        // rando cannot create
        vm.prank(_rando);
        vm.expectRevert("Caller is not a manager");
        vest.createVesting(100, address(7), 1, 20 days, 40 days, false);

        // owner can create
        vm.prank(_owner);
        vest.createVesting(100, address(7), 1, 20 days, 40 days, false);
    }

    function testCreateMintableVest(address _beneficiary, address rando) public {
        vm.assume(_beneficiary != address(0));
        vm.assume(rando != address(0));
        vm.assume(rando != _beneficiary);
        vm.assume(_beneficiary != trustedForwarder);

        uint256 amount = 10 ** 18;

        vm.startPrank(owner);
        uint64 id = vesting.createVesting(amount, _beneficiary, 0, 0, 100 days, true);
        vm.stopPrank();

        assertEq(vesting.beneficiary(id), _beneficiary);
        assertEq(vesting.allocation(id), amount);
        assertEq(vesting.released(id), 0);
        assertEq(vesting.start(id), 0);
        assertEq(vesting.cliff(id), 0);
        assertEq(vesting.duration(id), 100 days);
        assertEq(vesting.isMintable(id), true, "Vesting plan not mintable");

        assertEq(token.balanceOf(_beneficiary), 0);

        // rando can not release tokens
        vm.warp(10 days);
        vm.prank(rando);
        vm.expectRevert("Only beneficiary can release tokens");
        vesting.release(id);

        // beneficiary can release tokens
        vm.warp(80 days);
        vm.prank(_beneficiary);
        vesting.release(id);

        assertEq(vesting.released(id), 8e17, "released amount is wrong");
        assertEq(token.balanceOf(_beneficiary), 8e17, "beneficiary balance is wrong");
    }

    function testPauseBeforeCliff(address _beneficiary) public {
        vm.assume(_beneficiary != address(0));
        vm.assume(_beneficiary != trustedForwarder);

        uint256 amount = 70e18;
        uint64 start = 2 * 365 days;
        uint64 duration = 2 * 365 days;
        uint64 cliff = 1 * 365 days;
        uint64 pauseStart = start + 90 days;
        uint64 pauseEnd = start + 1 * 365 days;

        vm.prank(owner);
        uint64 id = vesting.createVesting(amount, _beneficiary, start, cliff, duration, false);
        token.mint(address(vesting), amount);

        assertEq(id, 1, "ids don't start at 1");

        // log vestings total amount
        console.log("total amount", vesting.allocation(id));
        console.log("ids", vesting.ids());

        vm.warp(start + 20 days);

        vm.startPrank(owner);
        uint64 newId = vesting.pauseVesting(id, pauseStart, pauseEnd);
        vm.stopPrank();
        assertEq(newId, 2, "ids don't increase by 1");

        console.log("total amount", vesting.allocation(id));
        // allocation new id
        console.log("total amount new id", vesting.allocation(newId));
        console.log("ids", vesting.ids());

        // make sure old vesting is deleted
        assertEq(vesting.allocation(id), 0, "old total is wrong");
        assertEq(vesting.released(id), 0, "old released is wrong");
        assertEq(vesting.beneficiary(id), address(0), "old beneficiary is not deleted");
        assertEq(vesting.start(id), 0, "old start is wrong");
        assertEq(vesting.cliff(id), 0, "old cliff is wrong");
        assertEq(vesting.duration(id), 0, "old duration is wrong");
        assertEq(vesting.isMintable(id), false, "old mintable is wrong");

        // make sure new id has proper values
        assertEq(vesting.allocation(newId), amount, "total is wrong");
        assertEq(vesting.released(newId), 0, "released is wrong");
        assertEq(vesting.beneficiary(newId), _beneficiary, "beneficiary is not deleted");
        assertEq(vesting.start(newId), pauseEnd, "start is wrong");
        assertEq(vesting.cliff(newId), cliff - 90 days, "cliff is wrong");
        assertEq(vesting.duration(newId), duration - 90 days, "duration is wrong");
        assertEq(vesting.isMintable(newId), false, "mintable is wrong");

        // go to end of vestings and claim all. It must match the total
        vm.warp(pauseEnd + duration);
        vm.startPrank(_beneficiary);
        vesting.release(newId);

        assertEq(token.balanceOf(_beneficiary), amount, "balance is wrong");

        vm.stopPrank();
    }

    function testPauseAfterCliff(address _beneficiary, uint64 pauseAfter, uint64 pauseDuration) public {
        vm.assume(_beneficiary != address(0));
        vm.assume(_beneficiary != trustedForwarder);
        pauseAfter = (pauseAfter % 364 days);
        pauseDuration = (pauseDuration % (10 * 365 days)) + 1;

        uint256 amount = 70e18;
        uint64 start = 2 * 365 days;
        uint64 duration = 2 * 365 days;
        uint64 cliff = 1 * 365 days;
        uint64 pauseStart = start + cliff + pauseAfter;
        uint64 pauseEnd = pauseStart + pauseDuration;

        console.log("vesting end", start + duration);
        console.log("pause start", pauseStart);

        vm.startPrank(owner);
        uint64 id = vesting.createVesting(amount, _beneficiary, start, cliff, duration, true);

        vm.warp(start + 3);

        uint64 newId = vesting.pauseVesting(id, pauseStart, pauseEnd);
        vm.stopPrank();

        // make sure old vesting is updated
        assertEq(vesting.allocation(id), (amount * (pauseStart - start)) / duration, "old total is wrong");
        assertTrue(vesting.allocation(id) < amount, "old total is too high");
        assertEq(vesting.released(id), 0, "old released is wrong");
        assertEq(vesting.beneficiary(id), _beneficiary, "old beneficiary is wrong");
        assertEq(vesting.start(id), start, "old start is wrong");
        assertEq(vesting.cliff(id), cliff, "old cliff is wrong");
        assertEq(vesting.duration(id), pauseStart - start, "old duration is wrong");
        assertEq(vesting.isMintable(id), true, "old mintable is wrong");

        // make sure new id has proper values
        assertEq(vesting.allocation(newId), amount - vesting.allocation(id), "total is wrong");
        assertEq(vesting.released(newId), 0, "released is wrong");
        assertEq(vesting.beneficiary(newId), _beneficiary, "beneficiary is not deleted");
        assertEq(vesting.start(newId), pauseEnd, "start is wrong");
        assertEq(vesting.cliff(newId), 0, "cliff is wrong");
        assertEq(vesting.duration(newId), duration - vesting.duration(id), "duration is wrong");
        assertEq(vesting.isMintable(newId), true, "mintable is wrong");

        console.log("old id beneficial", vesting.beneficiary(id));
        console.log("new id beneficial", vesting.beneficiary(newId));

        // go to end of vestings and claim all. It must match the total
        vm.warp(pauseEnd + duration);
        vm.startPrank(_beneficiary);
        vesting.release(id);
        vesting.release(newId);
        vm.stopPrank();

        console.log("new id beneficial", vesting.beneficiary(newId));

        assertEq(token.balanceOf(_beneficiary), amount, "balance is wrong");
    }

    function testNoWrongManagers(address rando) public {
        vm.assume(rando != address(owner));

        assertFalse(vesting.managers(rando), "rando is a manager");
    }

    function testAddAndRemoveManager(address rando) public {
        vm.assume(rando != address(owner));
        vm.assume(rando != address(0));
        vm.assume(rando != trustedForwarder);

        vm.prank(owner);
        vesting.addManager(rando);

        assertTrue(vesting.managers(rando), "rando is not a manager");

        vm.prank(owner);
        vesting.removeManager(rando);

        assertFalse(vesting.managers(rando), "rando is a manager");
    }

    function testReleasable(uint64 testAfter) public {
        testAfter = (testAfter % exampleDuration);

        vm.startPrank(owner);
        uint64 id = vesting.createVesting(
            exampleAmount,
            beneficiary,
            exampleStart,
            exampleCliff,
            exampleDuration,
            true
        );
        vm.stopPrank();

        // check releasable after 5 years
        uint256 releasable = vesting.releasable(id, uint64(exampleStart + 5 * 365 days));
        assertEq(releasable, exampleAmount / 2, "releasable amount is wrong");

        // check releasable after duration
        releasable = vesting.releasable(id, uint64(exampleStart + exampleDuration));
        assertEq(releasable, exampleAmount, "releasable amount is wrong");

        // check releasable before cliff
        releasable = vesting.releasable(id, uint64(exampleStart + exampleCliff - 1));
        assertEq(releasable, 0, "releasable amount is wrong");

        // check releasable after cliff
        releasable = vesting.releasable(id, uint64(exampleStart + exampleCliff));
        assertEq(releasable, exampleAmount / 10, "releasable amount is wrong");

        // check releasable after testAfter
        releasable = vesting.releasable(id, uint64(exampleStart + testAfter));
        vm.warp(exampleStart + testAfter);
        uint256 releasable2 = vesting.releasable(id);
        assertEq(releasable, releasable2, "releasable functions disagree");
        vm.prank(beneficiary);
        vesting.release(id);
        assertEq(token.balanceOf(beneficiary), releasable, "released amount is different from releasable");
    }

    function testChangeBeneficiary(uint64 changeAfter, address rando) public {
        changeAfter = ((changeAfter % exampleDuration) * 2);
        vm.assume(rando != address(0));
        vm.assume(rando != trustedForwarder);
        vm.assume(rando != beneficiary);
        vm.assume(rando != owner);

        vm.startPrank(owner);
        uint64 id = vesting.createVesting(
            exampleAmount,
            beneficiary,
            exampleStart,
            exampleCliff,
            exampleDuration,
            true
        );
        vm.stopPrank();

        assertEq(vesting.beneficiary(id), beneficiary, "beneficiary not correct");

        vm.warp(exampleStart + changeAfter);
        // rando can never change beneficiary
        vm.prank(rando);
        vm.expectRevert("Only beneficiary can change beneficiary, or owner 1 year after vesting end");
        vesting.changeBeneficiary(id, rando);
        assertEq(vesting.beneficiary(id), beneficiary, "rando changed beneficiary");

        // even beneficiary can never set beneficiary to 0
        vm.prank(beneficiary);
        vm.expectRevert("Beneficiary must not be zero address");
        vesting.changeBeneficiary(id, address(0));
        assertEq(vesting.beneficiary(id), beneficiary, "beneficiary should not have changed!");

        // beneficiary can always change beneficiary, which emits an event
        vm.prank(beneficiary);
        vm.expectEmit(true, true, true, true, address(vesting));
        emit BeneficiaryChanged(id, rando);
        vesting.changeBeneficiary(id, rando);
        assertEq(vesting.beneficiary(id), rando, "beneficiary not changed");

        if (changeAfter > exampleDuration + 365 days) {
            // owner can change beneficiary after 1 year
            vm.prank(owner);
            vesting.changeBeneficiary(id, beneficiary);
            assertEq(vesting.beneficiary(id), beneficiary, "owner could not change beneficiary");
        } else {
            // owner can not change beneficiary before 1 year
            vm.prank(owner);
            vm.expectRevert("Only beneficiary can change beneficiary, or owner 1 year after vesting end");
            vesting.changeBeneficiary(id, beneficiary);
            assertEq(vesting.beneficiary(id), rando, "owner changed beneficiary too early");
        }
    }

    function testDurationIsExtendedToCliff(uint64 _duration, uint64 _cliff) public {
        vm.assume(_duration > 0);
        vm.assume(_cliff > 0);

        // create vesting plan
        vm.startPrank(owner);
        uint64 id = vesting.createVesting(exampleAmount, beneficiary, exampleStart, _cliff, _duration, true);
        vm.stopPrank();

        // check duration is extended to cliff
        if (_duration < _cliff) {
            assertEq(vesting.duration(id), _cliff, "duration is not extended to cliff");
        } else {
            assertEq(vesting.duration(id), _duration, "duration is changed");
        }
    }

    function testInitializingWith0() public {
        // owner 0
        vm.expectRevert("Owner must not be zero address");
        Vesting vest = Vesting(factory.createVestingClone(0, trustedForwarder, address(0), address(token)));

        // token 0
        vm.expectRevert("Token must not be zero address");
        vest = Vesting(factory.createVestingClone(0, trustedForwarder, owner, address(0)));
    }

    function testCommit0() public {
        vm.expectRevert("hash must not be zero");
        vm.prank(owner);
        vesting.commit(bytes32(0));
    }

    function testRevoke0() public {
        vm.expectRevert("invalid-hash");
        vm.prank(owner);
        vesting.revoke(bytes32(0), 20 days);
    }

    function testBeneficiary0() public {
        vm.expectRevert("Beneficiary must not be zero address");
        vm.prank(owner);
        vesting.createVesting(100, address(0), 1, 20 days, 40 days, false);
    }

    function testStopVestingAfterEnd() public {
        vm.startPrank(owner);
        uint64 id = vesting.createVesting(
            exampleAmount,
            beneficiary,
            exampleStart,
            exampleCliff,
            exampleDuration,
            true
        );
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert("endTime must be before vesting end");
        vesting.stopVesting(id, exampleStart + exampleDuration + 1);
    }

    function testPauseVestingWrong() public {
        vm.startPrank(owner);
        uint64 id = vesting.createVesting(
            exampleAmount,
            beneficiary,
            exampleStart,
            exampleCliff,
            exampleDuration,
            true
        );

        vm.warp(exampleStart + exampleCliff);

        // end time in past
        vm.expectRevert("endTime must be in the future");
        vesting.pauseVesting(id, exampleStart, exampleStart + 2 * exampleDuration);

        // end time is vesting end
        vm.expectRevert("endTime must be before vesting end");
        vesting.pauseVesting(id, exampleStart + exampleDuration, exampleStart + 2 * exampleDuration);

        // new start before end
        vm.expectRevert("newStartTime must be after endTime");
        vesting.pauseVesting(id, exampleStart + exampleCliff + 1, exampleStart + exampleCliff / 2);
    }
}
