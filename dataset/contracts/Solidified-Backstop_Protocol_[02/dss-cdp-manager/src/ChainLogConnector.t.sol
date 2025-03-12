pragma solidity ^0.5.12;

import { BCdpManagerTestBase, Hevm, FakeUser, ChainLog } from "./BCdpManager.t.sol";
import { ChainLogConnector } from "./ChainLogConnector.sol";

contract ChainLogConnectorTest is BCdpManagerTestBase {
    ChainLogConnector cc;
    ChainLog cl;


    function setUp() public {
        super.setUp();
        cl = new ChainLog();
        cc = new ChainLogConnector(address(vat), address(cl));
        this.rely(address(vat), address(this));
    }

    function testCat() public {
        cl.setAddress("MCD_CAT", address(cat));
        cl.setAddress("MCD_DOG", address(jug));
        cc.setCat();
        assertEq(cc.cat(), address(cat));
    }

    function testDogKeyRemoved() public {
        cl.setAddress("MCD_CAT", address(jug));
        cl.removeAddress("MCD_CAT");
        DogLike d = new DogLike();
        cl.setAddress("MCD_DOG", address(d));
        vat.rely(address(d));
        cc.setCat();
        assertEq(cc.cat(), address(d));
        (,uint chop,) = CatLike(cc.cat()).ilks("ETH");
        assertEq(chop, 112e16);
    }

    function testDogKeyReset() public {
        cl.setAddress("MCD_CAT", address(jug));
        cl.setAddress("MCD_CAT", address(0x0));
        cl.setAddress("MCD_DOG", address(cat));
        cc.setCat();
        assertEq(cc.cat(), address(cat));
    }

    function testFailedSetUnApprovedCat() public {
        cl.setAddress("MCD_CAT", address(0x1));
        cc.setCat();
    }

    function testUpgrade() public {
        cl.setAddress("MCD_CAT", address(cat));
        cc.setCat();
        assertEq(cc.cat(), address(cat));
        vat.deny(address(cat));
        cl.setAddress("MCD_CAT", address(flop));
        cc.setCat();
        assertEq(cc.cat(), address(flop));
        vat.deny(address(flop));
        cl.removeAddress("MCD_CAT");
        cl.setAddress("MCD_DOG", address(jug));
        cc.setCat();
        assertEq(cc.cat(), address(jug));
        vat.deny(address(jug));
        cl.setAddress("MCD_DOG", address(flap));
        vat.rely(address(flap));
        cc.setCat();
        assertEq(cc.cat(), address(flap));
    }

    function testUpgradeChainLog() public {
        ChainLog newCl = new ChainLog();
        newCl.setAddress("MCD_CAT", address(cat));
        cl.setAddress("MCD_CAT", address(jug));
        cc.setCat();
        assertEq(cc.cat(), address(jug));
        vat.deny(address(jug));
        cl.setAddress("CHANGELOG", address(newCl));
        cc.upgradeChainLog();
        cc.setCat();
        assertEq(cc.cat(), address(cat));
        assertEq(address(cc.chainLog()), address(newCl));
    }

    function testFailedUpgradeWithoutChangeCat() public {
        cl.setAddress("MCD_CAT", address(cat));
        cc.setCat();
        cl.setAddress("MCD_CAT", address(jug));
        cc.setCat();
    }

    function testFailedUpgradeWithoutChangeDog() public {
        cl.setAddress("MCD_DOG", address(cat));
        cc.setCat();
        cl.setAddress("MCD_DOG", address(jug));
        cc.setCat();
    }

    function testFailedUpgadeChageNoAuth() public {
        cc.setOwner(address(0x12));
        cl.setAddress("CHANGELOG", address(0x45));
        cc.upgradeChainLog();
    }
}

contract DogLike {
    struct Ilk {
        address clip;  // Liquidator
        uint256 chop;  // Liquidation Penalty  [wad]
        uint256 hole;  // Max DAI needed to cover debt+fees of active auctions per ilk [rad]
        uint256 dirt;  // Amt DAI needed to cover debt+fees of active auctions per ilk [rad]
    }

    mapping (bytes32 => Ilk) public ilks;

    constructor() public {
        ilks["ETH"].clip = address(0x123);
        ilks["ETH"].chop = 112 ether / 100; // 1.12
        ilks["ETH"].hole = 124;
        ilks["ETH"].dirt = 999;
    }
}

contract CatLike {
    struct Ilk {
        address flip;  // Liquidator
        uint256 chop;  // Liquidation Penalty  [wad]
        uint256 dunk;  // Liquidation Quantity [rad]
    }

    mapping (bytes32 => Ilk) public ilks;

    constructor() public {
        ilks["ETH"].flip = address(0x123);
        ilks["ETH"].chop = 113 ether / 100; // 1.13
        ilks["ETH"].dunk = 124;
    }
}
