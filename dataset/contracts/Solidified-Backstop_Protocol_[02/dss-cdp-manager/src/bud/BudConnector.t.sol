pragma solidity ^0.5.12;

import { DSTest } from "ds-test/test.sol";
import { BudConnector, OSMLike } from "./BudConnector.sol";

contract MockOSM {
    function peep() external view returns (bytes32, bool) {
        return ("0x11", true);
    }
}

contract MockPip {
    function read() external view returns (bytes32) {
        return "0x22";
    }
}

contract FakeUser {
    function doAuthorize(BudConnector target, address addr) public {
        target.authorize(addr);
    }

    function doPeep(BudConnector target) public returns (bytes32, bool) {
        return target.peep();
    }

    function doRead(BudConnector target, bytes32 ilk) public returns (bytes32) {
        return target.read(ilk);
    }

    function doSetPip(BudConnector target, bytes32 ilk, address pip) public {
        target.setPip(pip, ilk);
    }
}

contract BudConnectorTest is DSTest {

    MockOSM osm;
    BudConnector budConnector;

    function setUp() public {
        osm = new MockOSM();
        budConnector = new BudConnector(OSMLike(address(osm)));
        budConnector.setPip(address(new MockPip()), "ETH");
    }

    function testAuthToAuthorize() public {
        FakeUser user = new FakeUser();
        budConnector.authorize(address(user));

        assertTrue(budConnector.authorized(address(user)));
    }

    function testFailNonAuthToAuthorize() public {
        FakeUser user = new FakeUser();
        assertTrue(budConnector.authorized(address(user)) == false);

        // call must revert
        user.doAuthorize(budConnector, address(user));
    }

    function testAuthorizedToCallPeep() public {
        FakeUser user = new FakeUser();
        budConnector.authorize(address(user));
        assertTrue(budConnector.authorized(address(user)));

        (bytes32 price, bool flag) = user.doPeep(budConnector);
        assertEq32(price, "0x11");
        assertTrue(flag);
    }

    function testFailNonAuthorizedToCallPeep() public {
        FakeUser user = new FakeUser();
        assertTrue(budConnector.authorized(address(user)) == false);

        // call must revert
        user.doPeep(budConnector);
    }

    function testAuthorizedToCallRead() public {
        FakeUser user = new FakeUser();
        budConnector.authorize(address(user));
        assertTrue(budConnector.authorized(address(user)));

        bytes32 price = user.doRead(budConnector, "ETH");
        assertEq32(price, "0x22");
    }

    function testFailNonAuthorizedToCallRead() public {
        FakeUser user = new FakeUser();
        assertTrue(budConnector.authorized(address(user)) == false);

        // call must revert
        user.doRead(budConnector, "ETH");
    }

    function testFailExistingPip() public {
        budConnector.setPip(address(new MockPip()), "ETH");
    }

    function testFailSetPipFromNonAuth() public {
        FakeUser user = new FakeUser();
        user.doSetPip(budConnector, "ETH-B", address(new MockPip()));
    }
}
