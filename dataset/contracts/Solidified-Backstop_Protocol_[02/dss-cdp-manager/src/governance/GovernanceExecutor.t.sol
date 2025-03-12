pragma solidity ^0.5.12;

import { BCdpManagerTestBase, FakeUser, BCdpScoreLike } from "../BCdpManager.t.sol";
import { GovernanceExecutor } from "./GovernanceExecutor.sol";

contract MigrateTest is BCdpManagerTestBase {

    GovernanceExecutor executor;
    FakeUser dao;

    function setUp() public {
        super.setUp();

        dao = new FakeUser();

        executor = new GovernanceExecutor(address(manager));
        executor.setGovernance(address(dao));
    }

    function testValidateSetup() public {
        assertEq(executor.governance(), address(dao));
    }

    function testUpgradeContracts() public {
        FakeUser pool = new FakeUser();
        FakeUser score = new FakeUser();

        manager.setOwner(address(executor));

        executor.setPool(address(pool));
        executor.setScore(address(score));


        assertEq(address(manager.pool()), address(pool));
        assertEq(address(manager.score()), address(score));
    }

    function testUpgradeManagerAdmin() public {
        manager.setOwner(address(executor));

        FakeUser newAdmin = new FakeUser();

        dao.doTransferAdmin(executor, address(newAdmin));

        assertEq(manager.owner(), address(newAdmin));
    }

    function testFailedSetPoolFromNonAdmin() public {
        manager.setOwner(address(executor));        
        executor.setOwner(address(0x1));

        FakeUser pool = new FakeUser();
        executor.setPool(address(pool));
    }

    function testFailedSetScoreFromNonAdmin() public {
        manager.setOwner(address(executor));        
        executor.setOwner(address(0x1));

        FakeUser score = new FakeUser();
        executor.setScore(address(pool));
    }        
}