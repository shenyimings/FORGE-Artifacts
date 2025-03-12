// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/factories/VestingCloneFactory.sol";
import "./Vesting.t.sol";
import "./resources/ERC20MintableByAnyone.sol";

contract VestingBlindTest is Test {
    event Commit(bytes32);
    event Revoke(bytes32, uint64);
    event Reveal(bytes32, uint64 id);

    Vesting implementation;
    VestingCloneFactory factory;

    ERC20MintableByAnyone token = new ERC20MintableByAnyone("test token", "TST");

    Vesting vesting;

    address trustedForwarder = address(1);
    address platformAdmin = address(2);
    address owner = address(3);
    address beneficiary = address(7);
    bytes32 salt = 0;
    bool isMintable = true; // we mostly check mintable stuff
    uint64 start = 30 * 365 days;

    function setUp() public {
        implementation = new Vesting(trustedForwarder);

        factory = new VestingCloneFactory(address(implementation));

        vesting = Vesting(factory.createVestingClone(0, trustedForwarder, owner, address(token)));
    }

    function testCommit(bytes32 hash) public {
        vm.assume(hash != bytes32(0));
        assertTrue(vesting.commitments(hash) == 0, "commitment already exists");
        vm.prank(owner);
        vesting.commit(hash);
        assertTrue(vesting.commitments(hash) == type(uint64).max, "commitment does not exist");
    }

    function testCommitNoManager(address noOwner, bytes32 hash) public {
        vm.assume(noOwner != address(0));
        vm.assume(vesting.managers(noOwner) == false);
        vm.assume(hash != bytes32(0));
        vm.expectRevert("Caller is not a manager");
        vm.prank(noOwner);
        vesting.commit(hash);
    }

    function testRevokeNow(bytes32 hash) public {
        vm.assume(hash != bytes32(0));
        vm.prank(owner);
        vesting.commit(hash);
        assertTrue(vesting.commitments(hash) == type(uint64).max, "commitment does not exist");
        vm.prank(owner);
        vesting.revoke(hash, uint64(block.timestamp));
        assertTrue(vesting.commitments(hash) == block.timestamp, "revocation not correct");
    }

    function testRevokeLater(bytes32 hash, uint64 end) public {
        vm.assume(hash != bytes32(0));
        vm.assume(end > block.timestamp);
        vm.prank(owner);
        vesting.commit(hash);
        assertTrue(vesting.commitments(hash) > 0, "commitment does not exist");
        vm.prank(owner);
        vesting.revoke(hash, end);
        assertTrue(vesting.commitments(hash) == end, "revocation not correct");
    }

    function testRevokeNoOwner(address noOwner, bytes32 hash) public {
        vm.assume(noOwner != address(0));
        vm.assume(vesting.managers(noOwner) == false);
        vm.assume(hash != bytes32(0));
        vm.prank(owner);
        vesting.commit(hash);

        assertTrue(vesting.commitments(hash) == type(uint64).max, "commitment does not exist");
        vm.prank(noOwner);
        vm.expectRevert("Caller is not a manager");
        vesting.revoke(hash, uint64(block.timestamp));
        assertEq(vesting.commitments(hash), type(uint64).max, "commitment has been revoked");
    }

    function testReveal(
        address _beneficiary,
        uint256 _allocation,
        uint64 _start,
        uint64 _duration,
        uint64 _cliff,
        bytes32 _salt,
        bool _isMintable,
        address _rando
    ) public {
        vm.assume(checkLimits(_allocation, _beneficiary, _start, _cliff, _duration, trustedForwarder));
        vm.assume(_rando != address(0));
        bytes32 hash = keccak256(
            abi.encodePacked(_allocation, _beneficiary, _start, _cliff, _duration, _isMintable, _salt)
        );

        console.log("duration: ", _duration);

        // commit
        assertTrue(vesting.commitments(hash) == 0, "commitment already exists");
        vm.expectEmit(true, true, true, true, address(vesting));
        emit Commit(hash);
        vm.prank(owner);
        vesting.commit(hash);
        assertTrue(vesting.commitments(hash) > 0, "commitment does not exist");

        // reveal
        vm.expectEmit(true, true, true, true, address(vesting));
        emit Reveal(hash, 1);
        vm.prank(_rando);
        uint64 id = vesting.reveal(hash, _allocation, _beneficiary, _start, _cliff, _duration, _isMintable, _salt);
        assertEq(id, 1, "id is not 1");

        checkVestingPlanDetails(id, _beneficiary, _allocation, _start, _duration, _cliff, _isMintable, vesting);

        // make sure the commitment is deleted
        assertTrue(vesting.commitments(hash) == 0, "commitment still exists");

        // make sure a second creation fails
        vm.expectRevert("invalid-hash");
        vm.prank(_rando);
        vesting.reveal(hash, _allocation, _beneficiary, _start, _cliff, _duration, _isMintable, _salt);
    }

    function testRevealAndRelease(
        address _beneficiary,
        uint256 _allocation,
        uint64 _start,
        uint64 _duration,
        uint64 _cliff,
        bytes32 _salt,
        bool _isMintable,
        address _rando,
        uint256 _maxReleaseAmount
    ) public {
        vm.assume(checkLimits(_allocation, _beneficiary, _start, _cliff, _duration, trustedForwarder));
        vm.assume(_rando != address(0));
        vm.assume(_rando != trustedForwarder);
        bytes32 hash = keccak256(
            abi.encodePacked(_allocation, _beneficiary, _start, _cliff, _duration, _isMintable, _salt)
        );

        _maxReleaseAmount = 0;

        // commit
        assertTrue(vesting.commitments(hash) == 0, "commitment already exists");
        vm.expectEmit(true, true, true, true, address(vesting));
        emit Commit(hash);
        vm.prank(owner);
        vesting.commit(hash);
        assertTrue(vesting.commitments(hash) > 0, "commitment does not exist");

        // mint tokens if necessary
        if (!_isMintable) {
            token.mint(address(vesting), _maxReleaseAmount);
        }

        vm.warp(_start + _duration + 1); // go to end of vesting period

        // revealAndRelease
        vm.expectEmit(true, true, true, true, address(vesting));
        emit Reveal(hash, 1);
        vm.prank(_rando);
        uint64 id = vesting.reveal(hash, _allocation, _beneficiary, _start, _cliff, _duration, _isMintable, _salt);
        assertEq(id, 1, "id is not 1");

        if (_maxReleaseAmount > _allocation) {
            assertEq(token.balanceOf(_beneficiary), _allocation, "balance is not equal to total");
        } else {
            assertEq(token.balanceOf(_beneficiary), _maxReleaseAmount, "balance is not equal to amount");
        }

        checkVestingPlanDetails(id, _beneficiary, _allocation, _start, _duration, _cliff, _isMintable, vesting);

        // make sure the commitment is deleted
        assertTrue(vesting.commitments(hash) == 0, "commitment still exists");

        // make sure a second creation fails
        vm.expectRevert("invalid-hash");
        vm.prank(_rando);
        vesting.reveal(hash, _allocation, _beneficiary, _start, _cliff, _duration, _isMintable, _salt);
    }

    function testClaimAfterRevoke() public {
        uint256 commitmentAllocation = 100;
        uint256 realAllocation = 75;
        uint64 _start = 40 * 365 days;
        uint64 _duration = 2 * 365 days;
        uint64 _cliff = 1 * 365 days;
        bytes32 _salt = 0;
        bool _isMintable = true;

        vm.warp(_start - 1 days);
        bytes32 hash = keccak256(
            abi.encodePacked(commitmentAllocation, beneficiary, _start, _cliff, _duration, _isMintable, _salt)
        );

        // commit
        assertTrue(vesting.commitments(hash) == 0, "commitment already exists");
        vm.expectEmit(true, true, true, true, address(vesting));
        emit Commit(hash);
        vm.prank(owner);
        vesting.commit(hash);
        assertTrue(vesting.commitments(hash) > 0, "commitment does not exist");

        // warp to 1.5 years into the vesting period and revoke
        vm.warp(_start + _cliff + _duration / 4);
        vm.prank(owner);
        vesting.revoke(hash, uint64(block.timestamp));
        assertTrue(vesting.commitments(hash) == block.timestamp, "revocation not correct");

        // warp till end of vesting and claim
        vm.warp(_start + _duration);
        vm.expectEmit(true, true, true, true, address(vesting));
        emit Reveal(hash, 1);
        uint64 id = vesting.reveal(
            hash,
            commitmentAllocation,
            beneficiary,
            _start,
            _cliff,
            _duration,
            _isMintable,
            _salt
        );
        assertEq(id, 1, "id is not 1");

        checkVestingPlanDetails(id, beneficiary, realAllocation, _start, 1.5 * 365 days, _cliff, _isMintable, vesting);

        // make sure the commitment is deleted
        assertTrue(vesting.commitments(hash) == 0, "commitment still exists");

        // make sure a second creation fails
        vm.expectRevert("invalid-hash");
        vesting.reveal(hash, commitmentAllocation, beneficiary, _start, _cliff, _duration, _isMintable, _salt);

        // vest everything
        vm.prank(beneficiary);
        vesting.release(id);
        assertEq(realAllocation, token.balanceOf(beneficiary), "balance is not equal to total");
    }

    function testRevokeBeforeCliff(
        uint256 _allocation,
        address _beneficiary,
        uint64 _start,
        uint24 _duration24,
        uint24 _cliff24,
        bytes32 _salt,
        uint24 revokeAfter24
    ) public {
        uint64 _duration = _duration24;
        uint64 _cliff = _cliff24;
        uint64 revokeAfter = revokeAfter24;

        vm.assume(revokeAfter < _cliff);
        vm.assume(checkLimits(_allocation, _beneficiary, _start, _cliff, _duration, trustedForwarder));
        bytes32 hash = keccak256(
            abi.encodePacked(_allocation, _beneficiary, _start, _cliff, _duration, isMintable, _salt)
        );

        // commit
        assertTrue(vesting.commitments(hash) == 0, "commitment already exists");
        vm.expectEmit(true, true, true, true, address(vesting));
        emit Commit(hash);
        vm.prank(owner);
        vesting.commit(hash);
        assertTrue(vesting.commitments(hash) > 0, "commitment does not exist");

        // revoke
        uint256 end = _start + revokeAfter;
        vm.warp(end);
        vm.expectEmit(true, true, true, true, address(vesting));
        emit Revoke(hash, uint64(end));
        vm.prank(owner);
        vesting.revoke(hash, uint64(end));

        // claim
        vm.expectRevert("commitment revoked before cliff ended");
        vesting.reveal(hash, _allocation, _beneficiary, _start, _cliff, _duration, isMintable, _salt);

        // make sure nothing changed
        assertTrue(vesting.commitments(hash) > 0, "commitment does not exist");
        assertTrue(vesting.commitments(hash) == end, "revocation not correct");
        assertTrue(vesting.ids() == 0, "a vesting plan has been created");
    }

    function testRevokeBeforeEnd(uint64 _duration, uint64 _cliff, uint64 revokeAfter) public {
        uint256 _allocation = 8127847e18;
        uint64 _start = 30 * 365 days;

        vm.assume(_duration < type(uint64).max / 2);
        vm.assume(revokeAfter < type(uint64).max / 2);
        vm.assume(_cliff < type(uint64).max / 2);
        vm.assume(revokeAfter < _duration);
        vm.assume(_cliff < revokeAfter);
        vm.assume(_cliff < _duration);

        vm.assume(checkLimits(_allocation, beneficiary, _start, _cliff, _duration, trustedForwarder));

        bytes32 hash = keccak256(
            abi.encodePacked(_allocation, beneficiary, _start, _cliff, _duration, isMintable, salt)
        );

        // commit
        assertTrue(vesting.commitments(hash) == 0, "commitment already exists");
        vm.expectEmit(true, true, true, true, address(vesting));
        emit Commit(hash);
        vm.prank(owner);
        vesting.commit(hash);
        assertTrue(vesting.commitments(hash) > 0, "commitment does not exist");

        // revoke
        vm.warp(_start);
        uint64 end = _start + revokeAfter;
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(vesting));
        emit Revoke(hash, end);
        vesting.revoke(hash, end);

        // claim
        vm.warp(uint256(_start) + uint256(_duration) + 1);

        uint256 newTot = (_allocation * uint256(revokeAfter)) / uint256(_duration);
        if (newTot == 0) {
            console.log("newTot is 0");
            vm.prank(beneficiary);
            //vm.expectRevert(); // todo: this path is never used. why?
            vesting.revealAndRelease(
                hash,
                _allocation,
                beneficiary,
                _start,
                _cliff,
                _duration,
                isMintable,
                salt,
                type(uint256).max
            );
            // assure no vesting plan has been created
            assertTrue(vesting.ids() == 0, "a vesting plan has been created");
        } else {
            console.log("newTot is not 0");
            vm.prank(beneficiary);
            uint64 id = vesting.revealAndRelease(
                hash,
                _allocation,
                beneficiary,
                _start,
                _cliff,
                _duration,
                isMintable,
                salt,
                type(uint256).max
            );
            // check correct execution
            assertTrue(vesting.commitments(hash) == 0, "revocation not correct");
            assertTrue(vesting.ids() == 1, "no vesting plan has been created");
            assertEq(vesting.isMintable(id), isMintable, "isMintable is wrong");
            assertEq(vesting.beneficiary(id), beneficiary, "beneficiary is wrong");
            assertEq(vesting.allocation(id), newTot, "allocation is wrong");
            assertTrue(vesting.released(id) == newTot, "accrued is not new total");
            assertTrue(vesting.releasable(id) == 0, "unpaid is not 0");
            assertTrue(token.balanceOf(beneficiary) == newTot, "balance is not equal to new total");
        }
    }

    function testRevokeAfterEnd(uint64 _duration, uint64 _cliff, uint64 revokeAfter) public {
        uint256 _allocation = 8127847e18;
        uint64 _start = 30 * 365 days;

        bytes32 _salt = 0;

        vm.assume(_duration < type(uint64).max / 2);
        vm.assume(revokeAfter < type(uint64).max / 2);
        vm.assume(_cliff < type(uint64).max / 2);
        vm.assume(revokeAfter > _duration);
        vm.assume(_cliff < _duration);

        vm.assume(checkLimits(_allocation, beneficiary, _start, _cliff, _duration, trustedForwarder));
        bytes32 hash = keccak256(
            abi.encodePacked(_allocation, beneficiary, _start, _cliff, _duration, isMintable, salt)
        );

        // commit
        assertTrue(vesting.commitments(hash) == 0, "commitment already exists");
        vm.expectEmit(true, true, true, true, address(vesting));
        emit Commit(hash);
        vm.prank(owner);
        vesting.commit(hash);
        assertTrue(vesting.commitments(hash) > 0, "commitment does not exist");

        // revoke
        vm.warp(_start);
        uint64 end = _start + revokeAfter;
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(vesting));
        emit Revoke(hash, end);
        vesting.revoke(hash, end);

        // claim
        vm.warp(uint256(_start) + uint256(_duration) + 1);

        vm.prank(beneficiary);
        uint64 id = vesting.revealAndRelease(
            hash,
            _allocation,
            beneficiary,
            _start,
            _cliff,
            _duration,
            isMintable,
            _salt,
            type(uint256).max
        );
        // check correct execution
        assertTrue(vesting.commitments(hash) == 0, "commitment still exists");
        assertTrue(vesting.ids() == 1, "no vesting plan has been created");
        assertTrue(vesting.released(id) == _allocation, "released is not original total amount");
        assertTrue(vesting.releasable(id) == 0, "unpaid is not 0");
        assertTrue(token.balanceOf(beneficiary) == _allocation, "balance is not equal to total");
    }

    function testRevokeAndYankBehaveEqual(
        uint64 _duration,
        uint64 _cliff,
        uint256 _allocation,
        uint64 revokeAfter
    ) public {
        address _beneficiaryCreate = address(23);
        vm.assume(_allocation > 0);
        vm.assume(type(uint256).max / _allocation > revokeAfter); // prevent overflow
        vm.assume(_duration < type(uint64).max / 2);
        vm.assume(revokeAfter > 0);
        vm.assume(_cliff < type(uint64).max / 2);
        vm.assume(revokeAfter < _duration);
        vm.assume(_cliff < _duration);
        vm.assume(checkLimits(_allocation, beneficiary, start, _cliff, _duration, trustedForwarder));
        bytes32 hash = keccak256(
            abi.encodePacked(_allocation, beneficiary, start, _cliff, _duration, isMintable, salt)
        );

        // commit to a vesting plan
        assertTrue(vesting.commitments(hash) == 0, "commitment already exists");
        vm.prank(owner);
        vesting.commit(hash);
        assertTrue(vesting.commitments(hash) > 0, "commitment does not exist");

        // create a vesting plan with the same parameters but a different receiver
        vm.prank(owner);
        uint64 createId = vesting.createVesting(_allocation, _beneficiaryCreate, start, _cliff, _duration, isMintable);

        // revoke the commitment
        vm.warp(start);
        uint64 end = start + revokeAfter;
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(vesting));
        emit Revoke(hash, end);
        vesting.revoke(hash, end);

        // log end and createId
        console.log("end: ", end);
        console.log("createId: ", createId);

        // yank the vesting plan
        vm.prank(owner);
        vesting.stopVesting(createId, end);

        // fast forward to the end of the vesting period
        vm.warp(uint256(start) + uint256(_duration) + 1);

        if (vesting.allocation(createId) == 0) {
            // two options take us here:
            // 1. stop and revoke happened before cliff, the vesting plan has been deleted
            // 2. plan still exists, but allocation is 0 duration is too short.
            console.log("User gets no tokens, so claim must fail");
            vm.prank(beneficiary);
            vm.expectRevert();
            vesting.revealAndRelease(
                hash,
                _allocation,
                beneficiary,
                start,
                _cliff,
                _duration,
                isMintable,
                salt,
                type(uint256).max
            );
            // assure no vesting plan has been created
            assertTrue(vesting.ids() == createId, "a vesting plan has been created");
        } else {
            console.log("User gets tokens");
            vm.prank(_beneficiaryCreate);
            vesting.release(createId);
            console.log("usrCreate balance: ", token.balanceOf(_beneficiaryCreate));
            vm.prank(beneficiary);
            uint64 commitId = vesting.revealAndRelease(
                hash,
                _allocation,
                beneficiary,
                start,
                _cliff,
                _duration,
                isMintable,
                salt,
                type(uint256).max
            );

            console.log("usrCommit balance: ", token.balanceOf(beneficiary));
            // check correct execution
            assertTrue(vesting.commitments(hash) == 0, "commitment still exists");
            assertTrue(vesting.ids() == createId + 1, "no vesting plan has been created");
            assertTrue(vesting.released(commitId) == token.balanceOf(_beneficiaryCreate), "accrued is not new total");
            assertTrue(vesting.releasable(commitId) == 0, "unpaid is not 0");
            assertTrue(
                token.balanceOf(beneficiary) == token.balanceOf(_beneficiaryCreate),
                "balance is not equal to new total"
            );
        }
    }

    function testClaimWithModifiedData(
        address _beneficiary,
        address _beneficiary2,
        uint128 _allocation,
        uint128 _allocation2,
        bytes32 _salt
    ) public {
        vm.assume(_beneficiary != address(0));
        vm.assume(_beneficiary2 != address(0));
        vm.assume(_beneficiary2 != _beneficiary);
        vm.assume(_allocation2 != 0 && _allocation != 0 && _allocation2 != _allocation);

        uint64 _start = uint64(block.timestamp + 400 days);
        uint64 _duration = 600 days;
        uint64 _cliff = 200 days;
        address _mgr = address(6);

        bytes32 hash = keccak256(
            abi.encodePacked(
                _beneficiary,
                uint256(_allocation),
                uint256(_start),
                uint256(_duration),
                uint256(_cliff),
                _mgr,
                _salt
            )
        );

        // commit
        assertTrue(vesting.commitments(hash) == 0, "commitment already exists");
        vm.prank(owner);
        vesting.commit(hash);
        assertTrue(vesting.commitments(hash) == type(uint64).max, "commitment does not exist");

        // claim
        vm.expectRevert("invalid-hash");
        vesting.reveal(hash, _allocation, _beneficiary2, _start, _cliff, _duration, isMintable, _salt);

        vm.expectRevert("invalid-hash");
        vesting.reveal(hash, _allocation2, _beneficiary, _start, _cliff, _duration, isMintable, _salt);
    }

    function checkVestingPlanDetails(
        uint64 _id,
        address _beneficiary,
        uint256 _allocation,
        uint64 _start,
        uint64 _duration,
        uint64 _cliff,
        bool _isMintable,
        Vesting _vesting
    ) public {
        assertEq(_vesting.beneficiary(_id), _beneficiary, "wrong beneficiary");
        assertEq(_vesting.allocation(_id), _allocation, "wrong allocation");
        assertEq(_vesting.start(_id), _start, "wrong start");
        assertEq(_vesting.cliff(_id), _cliff, "wrong cliff");
        assertEq(_vesting.duration(_id), _duration, "wrong duration");
        assertEq(_vesting.isMintable(_id), _isMintable, "wrong mintable");
    }
}
