//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

import "../src/TLC.1.sol";
import "../src/TUPProxy.sol";
import "forge-std/Test.sol";

abstract contract TLCTestBase is Test {
    TLCV1 internal tlcImplem;
    TLCV1 internal tlc;

    address internal escrowImplem;
    address internal initAccount;
    address internal bob;
    address internal joe;
    address internal admin;
}

contract TLCInitializationTest is TLCTestBase {
    function setUp() public {
        initAccount = makeAddr("init");
        bob = makeAddr("bob");
        joe = makeAddr("joe");
        admin = makeAddr("admin");

        tlcImplem = new TLCV1();
    }

    function testInitialization() external {
        tlc = TLCV1(
            address(
                new TUPProxy(
                    address(tlcImplem), admin, abi.encodeWithSelector(tlcImplem.initTLCV1.selector, initAccount)
                )
            )
        );

        assertEq(1_000_000_000e18, tlc.totalSupply());
    }
}

contract TLCTests is TLCTestBase {
    function setUp() public {
        initAccount = makeAddr("init");
        bob = makeAddr("bob");
        joe = makeAddr("joe");
        admin = makeAddr("admin");

        tlcImplem = new TLCV1();
        tlc = TLCV1(
            address(
                new TUPProxy(
                    address(tlcImplem), admin, abi.encodeWithSelector(tlcImplem.initTLCV1.selector, initAccount)
                )
            )
        );
        tlc.migrateVestingSchedules();
    }

    function testImplementationInitialization() public {
        vm.expectRevert("Initializable: contract is already initialized");
        tlcImplem.initTLCV1(initAccount);
    }

    function testName() public view {
        assert(keccak256(bytes(tlc.name())) == keccak256("Liquid Collective"));
    }

    function testSymbol() public view {
        assert(keccak256(bytes(tlc.symbol())) == keccak256("TLC"));
    }

    function testInitialSupplyAndBalance() public view {
        assert(tlc.totalSupply() == 1_000_000_000e18);
        assert(tlc.balanceOf(initAccount) == tlc.totalSupply());
    }
}
