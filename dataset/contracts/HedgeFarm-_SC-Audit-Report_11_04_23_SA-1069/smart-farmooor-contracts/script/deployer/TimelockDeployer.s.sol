// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../DataLoader.s.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

contract TimelockDeployer is DataLoader {
    TimelockController public timelock;

    function setTimelock() internal {
        timelock = TimelockController(payable(TIMELOCK));
    }

    function deployTimelock() internal {
        timelock = new TimelockController(TIMELOCK_MIN_DELAY, TIMELOCK_PROPOSERS, TIMELOCK_EXECUTORS, TIMELOCK_ADMIN);
    }

    function verifyTimelock() internal {
        assertEq(
            address(timelock) != 0x0000000000000000000000000000000000000000,
            true
        );
        assertEq(timelock.getMinDelay(), TIMELOCK_MIN_DELAY);
        assertEq(timelock.getRoleAdmin(keccak256("TIMELOCK_ADMIN_ROLE")), keccak256("TIMELOCK_ADMIN_ROLE"));
        assertEq(timelock.hasRole(keccak256("TIMELOCK_ADMIN_ROLE"), address(timelock)), true);
        assertEq(timelock.hasRole(keccak256("TIMELOCK_ADMIN_ROLE"), OWNER), false);
        assertEq(timelock.hasRole(keccak256("TIMELOCK_ADMIN_ROLE"), MANAGER), false);
        assertEq(timelock.hasRole(keccak256("TIMELOCK_ADMIN_ROLE"), DEPLOYER), false);
        assertEq(timelock.getRoleAdmin(keccak256("PROPOSER_ROLE")), keccak256("TIMELOCK_ADMIN_ROLE"));
        assertEq(timelock.hasRole(keccak256("PROPOSER_ROLE"), address(timelock)), false);
        assertEq(timelock.hasRole(keccak256("PROPOSER_ROLE"), OWNER), true);
        assertEq(timelock.hasRole(keccak256("PROPOSER_ROLE"), MANAGER), false);
        assertEq(timelock.hasRole(keccak256("PROPOSER_ROLE"), DEPLOYER), false);
        assertEq(timelock.getRoleAdmin(keccak256("EXECUTOR_ROLE")), keccak256("TIMELOCK_ADMIN_ROLE"));
        assertEq(timelock.hasRole(keccak256("EXECUTOR_ROLE"), address(timelock)), false);
        assertEq(timelock.hasRole(keccak256("EXECUTOR_ROLE"), OWNER), true);
        assertEq(timelock.hasRole(keccak256("EXECUTOR_ROLE"), MANAGER), true);
        assertEq(timelock.hasRole(keccak256("EXECUTOR_ROLE"), DEPLOYER), false);
        assertEq(timelock.getRoleAdmin(keccak256("CANCELLER_ROLE")), keccak256("TIMELOCK_ADMIN_ROLE"));
        assertEq(timelock.hasRole(keccak256("CANCELLER_ROLE"), address(timelock)), false);
        assertEq(timelock.hasRole(keccak256("CANCELLER_ROLE"), OWNER), true);
        assertEq(timelock.hasRole(keccak256("CANCELLER_ROLE"), MANAGER), false);
        assertEq(timelock.hasRole(keccak256("CANCELLER_ROLE"), DEPLOYER), false);
    }
}