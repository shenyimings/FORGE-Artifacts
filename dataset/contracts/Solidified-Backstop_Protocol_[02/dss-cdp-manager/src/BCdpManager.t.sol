pragma solidity ^0.5.12;

import { DssDeployTestBase, Vat } from "dss-deploy/DssDeploy.t.base.sol";
import { GetCdps } from "./GetCdps.sol";
import { BCdpManager } from "./BCdpManager.sol";
import { LiquidationMachine } from "./LiquidationMachine.sol";
import { Pool } from "./pool/Pool.sol";
import { BCdpScore } from "./BCdpScore.sol";
import { BCdpScoreLike } from "./BCdpScoreConnector.sol";
import { BudConnector, OSMLike } from "./bud/BudConnector.sol";
import { ChainLogConnector } from "./ChainLogConnector.sol";
import { GovernanceExecutor } from "./governance/GovernanceExecutor.sol";

contract Hevm {
    function warp(uint256) public;
}


contract FakeUser {

    function doCdpAllow(
        BCdpManager manager,
        uint cdp,
        address usr,
        uint ok
    ) public {
        manager.cdpAllow(cdp, usr, ok);
    }

    function doUrnAllow(
        BCdpManager manager,
        address usr,
        uint ok
    ) public {
        manager.urnAllow(usr, ok);
    }

    function doGive(
        BCdpManager manager,
        uint cdp,
        address dst
    ) public {
        manager.give(cdp, dst);
    }

    function doFrob(
        BCdpManager manager,
        uint cdp,
        int dink,
        int dart
    ) public {
        manager.frob(cdp, dink, dart);
    }

    function doHope(
        Vat vat,
        address usr
    ) public {
        vat.hope(usr);
    }

    function doVatFrob(
        Vat vat,
        bytes32 i,
        address u,
        address v,
        address w,
        int dink,
        int dart
    ) public {
        vat.frob(i, u, v, w, dink, dart);
    }

    function doTopup(
        Pool pool,
        uint cdp
    ) public {
        pool.topup(cdp);
    }

    function doBite(
        Pool pool,
        uint cdp,
        uint tab,
        uint minInk
    ) public {
        pool.bite(cdp, tab, minInk);
    }

    function doDeposit(
        Pool pool,
        uint radVal
    ) public {
        pool.deposit(radVal);
    }

    function doSetPool(
        BCdpManager manager,
        address pool
    ) public {
        manager.setPoolContract(pool);
    }

    function doSetScore(
        BCdpManager manager,
        BCdpScoreLike score
    ) public {
        manager.setScoreContract(score);
    }

    function doSetPoolExec(
        GovernanceExecutor exec,
        address pool
    ) public {
        exec.setPool(pool);
    }

    function doSetScoreExec(
        GovernanceExecutor exec,
        address score
    ) public {
        exec.setScore(score);
    }

    function doTransferAdmin(
        GovernanceExecutor exec,
        address newAdmin
    ) public {
        exec.doTransferAdmin(newAdmin);
    }    
}

contract FakeOSM {
    bytes32 price;
    bool valid = true;
    uint z = 0;
    uint h = 0;

    function setPrice(uint price_) public {
        price = bytes32(price_);
    }

    function peep() external view returns(bytes32, bool) {
        return (price, valid);
    }

    function hop() external view returns(uint16) {
        return uint16(h);
    }

    function zzz() external view returns(uint64) {
        if(z == 0) return uint64((now / 1 hours) * 1 hours);

        return uint64(z);
    }

    function setH(uint h_) external {
        h = h_;
    }

    function setZ(uint z_) external {
        z = z_;
    }

    function setValid(bool v) external {
        valid = v;
    }
}

contract FakeDaiToUsdPriceFeed {
    uint price = 1e18;
    function setPrice(uint newPrice) public {
        price = newPrice;
    }

    function getMarketPrice(uint marketId) public view returns (uint) {
        require(marketId == 3, "invalid-marketId");
        return price;
    }
}

contract BCdpManagerTestBase is DssDeployTestBase {
    BCdpManager manager;
    GetCdps getCdps;
    FakeUser user;
    FakeUser liquidator;
    Pool pool;
    BCdpScore score;
    FakeUser jar;
    Hevm hevm;
    FakeOSM osm;
    FakeDaiToUsdPriceFeed daiToUsdPriceFeed;
    uint currTime;
    BudConnector bud;

    function setUp() public {
        super.setUp();

        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        deploy();

        jar = new FakeUser();
        user = new FakeUser();
        liquidator = new FakeUser();
        osm = new FakeOSM();
        bud = new BudConnector(OSMLike(address(osm)));
        bud.setPip(address(pipETH), "ETH");
        daiToUsdPriceFeed = new FakeDaiToUsdPriceFeed();

        pool = new Pool(address(vat), address(jar), address(spotter), address(jug), address(daiToUsdPriceFeed));
        bud.authorize(address(pool));
        score = new BCdpScore();
        ChainLog log = new ChainLog();
        ChainLogConnector cc = new ChainLogConnector(address(vat), address(log));
        log.setAddress("MCD_CAT", address(cat));
        cc.setCat();
        manager = new BCdpManager(address(vat), address(cc), address(pool), address(bud), address(score));
        bud.authorize(address(manager));
        pool.setCdpManager(manager);
        address[] memory members = new address[](1);
        members[0] = address(liquidator);
        pool.setMembers(members);
        pool.setProfitParams(99, 100);
        pool.setIlk("ETH", true);
        pool.setOsm("ETH", address(bud));
        getCdps = new GetCdps();

        liquidator.doHope(vat, address(pool));
    }

    function reachTopup(uint cdp) internal {
        address urn = manager.urns(cdp);
        (, uint artPre) = vat.urns("ETH", urn);

        if(artPre == 0) {
            weth.mint(1 ether);
            weth.approve(address(ethJoin), 1 ether);
            ethJoin.join(manager.urns(cdp), 1 ether);
            manager.frob(cdp, 1 ether, 50 ether);
        }

        uint liquidatorCdp = manager.open("ETH", address(this));
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(manager.urns(liquidatorCdp), 1 ether);
        manager.frob(liquidatorCdp, 1 ether, 51 ether);
        manager.move(liquidatorCdp, address(this), 51 ether * RAY);
        vat.move(address(this), address(liquidator), 51 ether * RAY);

        liquidator.doDeposit(pool, 51 ether * RAY);

        osm.setPrice(70 * 1e18); // 1 ETH = 50 DAI
        (uint dart, uint dtab, uint art) = pool.topAmount(cdp);
        art; //shh
        assertEq(uint(dtab) / RAY, 1 ether + 3333333333333333334 /* 3.333 DAI */);
        assertEq(uint(dart), 1 ether + 3333333333333333334 /* 3.333 DAI */);

        liquidator.doTopup(pool, cdp);

        assertEq(manager.cushion(cdp), uint(dart));
    }

    function reachBitePrice(uint cdp) internal {
        reachTopup(cdp);

        // change actual price to enable liquidation
        pipETH.poke(bytes32(uint(70 * 1e18)));
        spotter.poke("ETH");
        pipETH.poke(bytes32(uint(70 * 1e18)));

        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
    }

    function reachBite(uint cdp) internal {
        reachBitePrice(cdp);

        // bite
        address urn = manager.urns(cdp);
        (, uint art) = vat.urns("ETH", urn);
        assertTrue(! canKeepersBite(cdp));
        liquidator.doBite(pool, cdp, art/2, 0);
        assertTrue(! canKeepersBite(cdp));

        assertTrue(LiquidationMachine(manager).bitten(cdp));
    }

    function canKeepersBite(uint cdp) internal view returns (bool) {
        address urn = manager.urns(cdp);
        bytes32 ilk = manager.ilks(cdp);
        (uint ink, uint art) = vat.urns("ETH", urn);
        (,uint currRate,uint currSpot,,) = vat.ilks(ilk);

        return art * currRate > ink * currSpot;
    }

    function deployNewPoolContract() internal returns (Pool) {
        jar = new FakeUser();
        return deployNewPoolContract(address(jar));
    }

    function deployNewPoolContract(address jar_) internal returns (Pool) {
        Pool _pool = new Pool(address(vat), jar_, address(spotter), address(jug), address(daiToUsdPriceFeed));
        _pool.setCdpManager(manager);
        address[] memory members = new address[](1);
        members[0] = address(liquidator);
        _pool.setMembers(members);
        _pool.setProfitParams(99, 100);
        _pool.setIlk("ETH", true);
        _pool.setOsm("ETH", address(bud));
        bud.authorize(address(_pool));
        liquidator.doHope(vat, address(_pool));
        return _pool;
    }

    function deployNewScoreContract() internal returns (BCdpScore) {
        BCdpScore _score = new BCdpScore();
        return _score;
    }

    function timeReset() internal {
        currTime = now;
        hevm.warp(currTime);
    }

    function forwardTime(uint deltaInSec) internal {
        currTime += deltaInSec;
        hevm.warp(currTime);
    }

    function expectScore(uint cdp, bytes32 ilk, uint inkScore, uint artScore, uint slashScore) internal {
        /*assertEq(score.getInkScore(cdp, ilk, currTime, score.start()), inkScore);
        assertEq(score.getArtScore(cdp, ilk, currTime, score.start()), artScore);
        assertEq(score.getSlashScore(cdp, ilk, currTime, score.start()), slashScore);*/
    }

    function expectGlobalScore(bytes32 ilk, uint gInkScore, uint gArtScore, uint gSlashScore) internal {
        /*
        assertEq(score.getInkGlobalScore(ilk, currTime, score.start()), gInkScore);
        assertEq(score.getArtGlobalScore(ilk, currTime, score.start()), gArtScore);
        assertEq(score.getSlashGlobalScore(ilk, currTime, score.start()), gSlashScore);*/
    }
}

contract BCdpManagerTest is BCdpManagerTestBase {
    function testFrobAndTopup() public {
        uint cdp = manager.open("ETH", address(this));
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(manager.urns(cdp), 1 ether);
        manager.frob(cdp, 1 ether, 50 ether);
        assertEq(vat.dai(manager.urns(cdp)), 50 ether * RAY);
        assertEq(vat.dai(address(this)), 0);
        manager.move(cdp, address(this), 50 ether * RAY);
        assertEq(vat.dai(manager.urns(cdp)), 0);
        assertEq(vat.dai(address(this)), 50 ether * RAY);
        assertEq(dai.balanceOf(address(this)), 0);

        vat.move(address(this), address(liquidator), 50 ether * RAY);
        liquidator.doDeposit(pool, 50 ether * RAY);

        assertEq(vat.dai(address(pool)), 50 ether * RAY);

        //address urn = manager.urns(cdp);
        //(, uint artPre) = vat.urns("ETH", urn);

        osm.setPrice(70 * 1e18); // 1 ETH = 50 DAI
        (uint dart, uint dtab, uint art) = pool.topAmount(cdp);
        assertEq(uint(dtab) / RAY, 1 ether + 3333333333333333334 /* 3.333 DAI */);
        assertEq(uint(dart), 1 ether + 3333333333333333334 /* 3.333 DAI */);

        liquidator.doTopup(pool, cdp);

        assertEq(manager.cushion(cdp), uint(dart));

        manager.frob(cdp, 0, 1 ether);

        assertEq(manager.cushion(cdp), 0);

        manager.frob(cdp, 0, -1 ether);

        liquidator.doTopup(pool, cdp);

        assertEq(manager.cushion(cdp), uint(dart));


        // change actual price to enable liquidation
        //(,, uint rate1,,) = vat.ilks("ETH");
        pipETH.poke(bytes32(uint(70 * 1e18)));
        spotter.poke("ETH");
        //(,, uint rate2,,) = vat.ilks("ETH");
        //assertEq(rate1, rate2);

        //(, uint artPost) = vat.urns("ETH", urn);

        pipETH.poke(bytes32(uint(70 * 1e18)));

        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        assertEq(art, 50 ether);
        // bite
        liquidator.doBite(pool, cdp, art/2, 0);

        assertTrue(vat.gem("ETH", address(liquidator)) > 77e16/2);
        assertTrue(vat.gem("ETH", address(jar)) > 77e14/2);
    }

    function testOpenCDP() public {
        uint cdp = manager.open("ETH", address(this));
        assertEq(cdp, 1);
        assertEq(vat.can(address(bytes20(manager.urns(cdp))), address(manager)), 1);
        assertEq(manager.owns(cdp), address(this));
    }

    function testOpenCDPOtherAddress() public {
        uint cdp = manager.open("ETH", address(123));
        assertEq(manager.owns(cdp), address(123));
    }

    function testFailOpenCDPZeroAddress() public {
        manager.open("ETH", address(0));
    }

    function testGiveCDP() public {
        testGiveCDP(false, false);
    }

    function testGiveCDPWithTopup() public {
        testGiveCDP(true, false);
    }

    function testGiveCDPWithBite() public {
        testGiveCDP(false, true);
    }

    function testGiveCDP(bool withTopup, bool withBite) internal {
        uint cdp = manager.open("ETH", address(this));
        if(withTopup) reachTopup(cdp);
        if(withBite) reachBite(cdp);
        uint cushion = LiquidationMachine(manager).cushion(cdp);
        manager.give(cdp, address(123));
        assertEq(manager.owns(cdp), address(123));
        assertEq(cushion, LiquidationMachine(manager).cushion(cdp));
    }

    function testAllowAllowed() public {
        uint cdp = manager.open("ETH", address(this));
        manager.cdpAllow(cdp, address(user), 1);
        user.doCdpAllow(manager, cdp, address(123), 1);
        assertEq(manager.cdpCan(address(this), cdp, address(123)), 1);
    }

    function testFailAllowNotAllowed() public {
        uint cdp = manager.open("ETH", address(this));
        user.doCdpAllow(manager, cdp, address(123), 1);
    }

    function testGiveAllowed() public {
        uint cdp = manager.open("ETH", address(this));
        manager.cdpAllow(cdp, address(user), 1);
        user.doGive(manager, cdp, address(123));
        assertEq(manager.owns(cdp), address(123));
    }

    function testFailGiveNotAllowed() public {
        uint cdp = manager.open("ETH", address(this));
        user.doGive(manager, cdp, address(123));
    }

    function testFailGiveNotAllowed2() public {
        uint cdp = manager.open("ETH", address(this));
        manager.cdpAllow(cdp, address(user), 1);
        manager.cdpAllow(cdp, address(user), 0);
        user.doGive(manager, cdp, address(123));
    }

    function testFailGiveNotAllowed3() public {
        uint cdp = manager.open("ETH", address(this));
        uint cdp2 = manager.open("ETH", address(this));
        manager.cdpAllow(cdp2, address(user), 1);
        user.doGive(manager, cdp, address(123));
    }

    function testFailGiveToZeroAddress() public {
        uint cdp = manager.open("ETH", address(this));
        manager.give(cdp, address(0));
    }

    function testFailGiveToSameOwner() public {
        uint cdp = manager.open("ETH", address(this));
        manager.give(cdp, address(this));
    }

    function testDoubleLinkedList() public {
        uint cdp1 = manager.open("ETH", address(this));
        uint cdp2 = manager.open("ETH", address(this));
        uint cdp3 = manager.open("ETH", address(this));

        uint cdp4 = manager.open("ETH", address(user));
        uint cdp5 = manager.open("ETH", address(user));
        uint cdp6 = manager.open("ETH", address(user));
        uint cdp7 = manager.open("ETH", address(user));

        assertEq(manager.count(address(this)), 3);
        assertEq(manager.first(address(this)), cdp1);
        assertEq(manager.last(address(this)), cdp3);
        (uint prev, uint next) = manager.list(cdp1);
        assertEq(prev, 0);
        assertEq(next, cdp2);
        (prev, next) = manager.list(cdp2);
        assertEq(prev, cdp1);
        assertEq(next, cdp3);
        (prev, next) = manager.list(cdp3);
        assertEq(prev, cdp2);
        assertEq(next, 0);

        assertEq(manager.count(address(user)), 4);
        assertEq(manager.first(address(user)), cdp4);
        assertEq(manager.last(address(user)), cdp7);
        (prev, next) = manager.list(cdp4);
        assertEq(prev, 0);
        assertEq(next, cdp5);
        (prev, next) = manager.list(cdp5);
        assertEq(prev, cdp4);
        assertEq(next, cdp6);
        (prev, next) = manager.list(cdp6);
        assertEq(prev, cdp5);
        assertEq(next, cdp7);
        (prev, next) = manager.list(cdp7);
        assertEq(prev, cdp6);
        assertEq(next, 0);

        manager.give(cdp2, address(user));

        assertEq(manager.count(address(this)), 2);
        assertEq(manager.first(address(this)), cdp1);
        assertEq(manager.last(address(this)), cdp3);
        (prev, next) = manager.list(cdp1);
        assertEq(next, cdp3);
        (prev, next) = manager.list(cdp3);
        assertEq(prev, cdp1);

        assertEq(manager.count(address(user)), 5);
        assertEq(manager.first(address(user)), cdp4);
        assertEq(manager.last(address(user)), cdp2);
        (prev, next) = manager.list(cdp7);
        assertEq(next, cdp2);
        (prev, next) = manager.list(cdp2);
        assertEq(prev, cdp7);
        assertEq(next, 0);

        user.doGive(manager, cdp2, address(this));

        assertEq(manager.count(address(this)), 3);
        assertEq(manager.first(address(this)), cdp1);
        assertEq(manager.last(address(this)), cdp2);
        (prev, next) = manager.list(cdp3);
        assertEq(next, cdp2);
        (prev, next) = manager.list(cdp2);
        assertEq(prev, cdp3);
        assertEq(next, 0);

        assertEq(manager.count(address(user)), 4);
        assertEq(manager.first(address(user)), cdp4);
        assertEq(manager.last(address(user)), cdp7);
        (prev, next) = manager.list(cdp7);
        assertEq(next, 0);

        manager.give(cdp1, address(user));
        assertEq(manager.count(address(this)), 2);
        assertEq(manager.first(address(this)), cdp3);
        assertEq(manager.last(address(this)), cdp2);

        manager.give(cdp2, address(user));
        assertEq(manager.count(address(this)), 1);
        assertEq(manager.first(address(this)), cdp3);
        assertEq(manager.last(address(this)), cdp3);

        manager.give(cdp3, address(user));
        assertEq(manager.count(address(this)), 0);
        assertEq(manager.first(address(this)), 0);
        assertEq(manager.last(address(this)), 0);
    }

    function testGetCdpsAsc() public {
        uint cdp1 = manager.open("ETH", address(this));
        uint cdp2 = manager.open("REP", address(this));
        uint cdp3 = manager.open("GOLD", address(this));

        (uint[] memory ids,, bytes32[] memory ilks) = getCdps.getCdpsAsc(address(manager), address(this));
        assertEq(ids.length, 3);
        assertEq(ids[0], cdp1);
        assertEq32(ilks[0], bytes32("ETH"));
        assertEq(ids[1], cdp2);
        assertEq32(ilks[1], bytes32("REP"));
        assertEq(ids[2], cdp3);
        assertEq32(ilks[2], bytes32("GOLD"));

        manager.give(cdp2, address(user));
        (ids,, ilks) = getCdps.getCdpsAsc(address(manager), address(this));
        assertEq(ids.length, 2);
        assertEq(ids[0], cdp1);
        assertEq32(ilks[0], bytes32("ETH"));
        assertEq(ids[1], cdp3);
        assertEq32(ilks[1], bytes32("GOLD"));
    }

    function testGetCdpsDesc() public {
        uint cdp1 = manager.open("ETH", address(this));
        uint cdp2 = manager.open("REP", address(this));
        uint cdp3 = manager.open("GOLD", address(this));

        (uint[] memory ids,, bytes32[] memory ilks) = getCdps.getCdpsDesc(address(manager), address(this));
        assertEq(ids.length, 3);
        assertEq(ids[0], cdp3);
        assertTrue(ilks[0] == bytes32("GOLD"));
        assertEq(ids[1], cdp2);
        assertTrue(ilks[1] == bytes32("REP"));
        assertEq(ids[2], cdp1);
        assertTrue(ilks[2] == bytes32("ETH"));

        manager.give(cdp2, address(user));
        (ids,, ilks) = getCdps.getCdpsDesc(address(manager), address(this));
        assertEq(ids.length, 2);
        assertEq(ids[0], cdp3);
        assertTrue(ilks[0] == bytes32("GOLD"));
        assertEq(ids[1], cdp1);
        assertTrue(ilks[1] == bytes32("ETH"));
    }

    function testFrob() public {
        testFrob(false, false);
    }

    function testFrobWithTopup() public {
        testFrob(true, false);
    }

    function testFailedFrobWithBite() public {
        testFrob(false, true);
    }

    function testFrob(bool withTopup, bool withBite) internal {
        uint cdp = manager.open("ETH", address(this));
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(manager.urns(cdp), 1 ether);

        if(withTopup) reachTopup(cdp);
        if(withBite) reachBite(cdp);

        (, uint artPre) = vat.urns("ETH", manager.urns(cdp));
        artPre += LiquidationMachine(manager).cushion(cdp);

        if(! withTopup && ! withBite) assertEq(artPre, 0);

        manager.frob(cdp, 1 ether, 50 ether);

        assertEq(LiquidationMachine(manager).cushion(cdp), 0);

        assertEq(vat.dai(manager.urns(cdp)), (50 ether + artPre)* RAY);
        assertEq(vat.dai(address(this)), 0);
        manager.move(cdp, address(this), 50 ether * RAY);
        assertEq(vat.dai(manager.urns(cdp)), artPre * RAY);
        assertEq(vat.dai(address(this)), 50 ether * RAY);
        assertEq(dai.balanceOf(address(this)), 0);
        vat.hope(address(daiJoin));
        daiJoin.exit(address(this), 50 ether);
        assertEq(dai.balanceOf(address(this)), 50 ether);
    }

    function testFrobRepayFullDebtWithCushion() public {
        uint cdp = manager.open("ETH", address(this));
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(manager.urns(cdp), 1 ether);

        manager.frob(cdp, 1 ether, 50 ether);
        reachTopup(cdp);
        assertTrue(LiquidationMachine(manager).cushion(cdp) > 0);

        manager.frob(cdp, 0 ether, -50 ether);
        (, uint art) = vat.urns("ETH", manager.urns(cdp));

        assertEq(art, 0);
    }

    function testFrobAllowed() public {
        uint cdp = manager.open("ETH", address(this));
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(manager.urns(cdp), 1 ether);
        manager.cdpAllow(cdp, address(user), 1);
        user.doFrob(manager, cdp, 1 ether, 50 ether);
        assertEq(vat.dai(manager.urns(cdp)), 50 ether * RAY);
    }

    function testFailFrobNotAllowed() public {
        uint cdp = manager.open("ETH", address(this));
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(manager.urns(cdp), 1 ether);
        user.doFrob(manager, cdp, 1 ether, 50 ether);
    }

    function testFrobGetCollateralBack() public {
        testFrobGetCollateralBack(false, false);
    }

    function testFrobGetCollateralBackWithTopup() public {
        testFrobGetCollateralBack(true, false);
    }

    function testFrobGetCollateralBackWithBite() public {
        testFrobGetCollateralBack(false, true);
    }

    function testFrobGetCollateralBack(bool withTopup, bool withBite) internal {
        uint cdp = manager.open("ETH", address(this));
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(manager.urns(cdp), 1 ether);
        manager.frob(cdp, 1 ether, 50 ether);
        manager.frob(cdp, -int(1 ether), -int(50 ether));
        assertEq(vat.dai(address(this)), 0);
        assertEq(vat.gem("ETH", manager.urns(cdp)), 1 ether);
        assertEq(vat.gem("ETH", address(this)), 0);
        if(withTopup) reachTopup(cdp);
        if(withBite) reachBite(cdp);
        uint cushion = LiquidationMachine(manager).cushion(cdp);
        manager.flux(cdp, address(this), 1 ether);
        assertEq(cushion, LiquidationMachine(manager).cushion(cdp));
        assertEq(vat.gem("ETH", manager.urns(cdp)), 0);
        assertEq(vat.gem("ETH", address(this)), 1 ether);
        uint prevBalance = weth.balanceOf(address(this));
        ethJoin.exit(address(this), 1 ether);
        assertEq(weth.balanceOf(address(this)), prevBalance + 1 ether);
    }

    function testGetWrongCollateralBack() public {
        testGetWrongCollateralBack(false, false);
    }

    function testGetWrongCollateralBackWithTopup() public {
        testGetWrongCollateralBack(true, false);
    }

    function testGetWrongCollateralBackWithBite() public {
        testGetWrongCollateralBack(false, true);
    }

    function testGetWrongCollateralBack(bool withTopup, bool withBite) internal {
        uint cdp = manager.open("ETH", address(this));
        col.mint(1 ether);
        col.approve(address(colJoin), 1 ether);
        colJoin.join(manager.urns(cdp), 1 ether);
        assertEq(vat.gem("COL", manager.urns(cdp)), 1 ether);
        assertEq(vat.gem("COL", address(this)), 0);
        if(withTopup) reachTopup(cdp);
        if(withBite) reachBite(cdp);
        uint cushion = LiquidationMachine(manager).cushion(cdp);
        manager.flux("COL", cdp, address(this), 1 ether);
        assertEq(cushion, LiquidationMachine(manager).cushion(cdp));
        assertEq(vat.gem("COL", manager.urns(cdp)), 0);
        assertEq(vat.gem("COL", address(this)), 1 ether);
    }

    function testMove() public {
        testMove(false, false);
    }

    function testMoveWithTopup() public {
        testMove(true, false);
    }

    function testMoveWithBite() public {
        testMove(false, true);
    }

    function testMove(bool withTopup, bool withBite) internal {
        uint cdp = manager.open("ETH", address(this));
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(manager.urns(cdp), 1 ether);

        manager.frob(cdp, 1 ether, 50 ether);

        if(withTopup) reachTopup(cdp);
        if(withBite) reachBite(cdp);
        uint cushion = LiquidationMachine(manager).cushion(cdp);

        manager.move(cdp, address(this), 50 ether * RAY);

        assertEq(vat.dai(address(this)), 50 ether * RAY);
        assertEq(LiquidationMachine(manager).cushion(cdp), cushion);
    }

    function testQuit() public {
        testQuit(false, false, false);
    }

    function testQuitWithTopup() public {
        testQuit(true, false, false);
    }

    function testFailQuitWithBite() public {
        testQuit(false, true, false);
    }

    function testFailQuitWithBitePrice() public {
        testQuit(false, false, true);
    }

    function testQuit(bool withTopup, bool withBite, bool withBitePrice) internal {
        uint cdp = manager.open("ETH", address(this));
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(manager.urns(cdp), 1 ether);
        manager.frob(cdp, 1 ether, 50 ether);

        (uint ink, uint art) = vat.urns("ETH", manager.urns(cdp));
        assertEq(ink, 1 ether);
        assertEq(art, 50 ether);
        (ink, art) = vat.urns("ETH", address(this));
        assertEq(ink, 0);
        assertEq(art, 0);

        vat.hope(address(manager));
        if(withTopup) reachTopup(cdp);
        if(withBite) reachBite(cdp);
        if(withBitePrice) reachBitePrice(cdp);
        manager.quit(cdp, address(this));
        assertEq(LiquidationMachine(manager).cushion(cdp), 0);
        (ink, art) = vat.urns("ETH", manager.urns(cdp));
        assertEq(ink, 0);
        assertEq(art, 0);
        (ink, art) = vat.urns("ETH", address(this));
        assertEq(ink, 1 ether);
        assertEq(art, 50 ether);
    }

    function testQuitOtherDst() public {
        testQuitOtherDst(false, false);
    }

    function testQuitOtherDstWithTopup() public {
        testQuitOtherDst(true, false);
    }

    function testFailQuitOtherDstWithBite() public {
        testQuitOtherDst(false, true);
    }

    function testQuitOtherDst(bool withTopup, bool withBite) internal {
        uint cdp = manager.open("ETH", address(this));
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(manager.urns(cdp), 1 ether);
        manager.frob(cdp, 1 ether, 50 ether);

        (uint ink, uint art) = vat.urns("ETH", manager.urns(cdp));
        assertEq(ink, 1 ether);
        assertEq(art, 50 ether);
        (ink, art) = vat.urns("ETH", address(this));
        assertEq(ink, 0);
        assertEq(art, 0);

        user.doHope(vat, address(manager));
        user.doUrnAllow(manager, address(this), 1);
        if(withTopup) reachTopup(cdp);
        if(withBite) reachBite(cdp);
        manager.quit(cdp, address(user));
        assertEq(LiquidationMachine(manager).cushion(cdp), 0);
        (ink, art) = vat.urns("ETH", manager.urns(cdp));
        assertEq(ink, 0);
        assertEq(art, 0);
        (ink, art) = vat.urns("ETH", address(user));
        assertEq(ink, 1 ether);
        assertEq(art, 50 ether);
    }

    function testFailQuitOtherDst() public {
        uint cdp = manager.open("ETH", address(this));
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(manager.urns(cdp), 1 ether);
        manager.frob(cdp, 1 ether, 50 ether);

        (uint ink, uint art) = vat.urns("ETH", manager.urns(cdp));
        assertEq(ink, 1 ether);
        assertEq(art, 50 ether);
        (ink, art) = vat.urns("ETH", address(this));
        assertEq(ink, 0);
        assertEq(art, 0);

        user.doHope(vat, address(manager));
        manager.quit(cdp, address(user));
    }

    function testEnter() public {
        testEnter(false, false);
    }

    function testEnterWithtopup() public {
        testEnter(true, false);
    }

    function testFailedEnterWithBite() public {
        testEnter(false, true);
    }

    function testEnter(bool withTopup, bool withBite) internal {
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(address(this), 1 ether);
        vat.frob("ETH", address(this), address(this), address(this), 1 ether, 50 ether);
        uint cdp = manager.open("ETH", address(this));

        (uint ink, uint art) = vat.urns("ETH", manager.urns(cdp));
        assertEq(ink, 0);
        assertEq(art, 0);

        (ink, art) = vat.urns("ETH", address(this));
        assertEq(ink, 1 ether);
        assertEq(art, 50 ether);

        vat.hope(address(manager));

        if(withTopup) reachTopup(cdp);
        if(withBite) reachBite(cdp);

        (uint inkPre, uint artPre) = vat.urns("ETH", manager.urns(cdp));
        artPre += LiquidationMachine(manager).cushion(cdp);

        manager.enter(address(this), cdp);
        assertEq(LiquidationMachine(manager).cushion(cdp), 0);

        (ink, art) = vat.urns("ETH", manager.urns(cdp));
        assertEq(ink, 1 ether + inkPre);
        assertEq(art, 50 ether + artPre);

        (ink, art) = vat.urns("ETH", address(this));
        assertEq(ink, 0);
        assertEq(art, 0);
    }

    function testEnterOtherSrc() public {
        testEnter(false, false);
    }

    function testEnterOtherSrcWithtopup() public {
        testEnter(true, false);
    }

    function testFailedEnterOtherSrcWithBite() public {
        testEnter(false, true);
    }

    function testEnterOtherSrc(bool withTopup, bool withBite) internal {
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(address(user), 1 ether);
        user.doVatFrob(vat, "ETH", address(user), address(user), address(user), 1 ether, 50 ether);

        uint cdp = manager.open("ETH", address(this));

        (uint ink, uint art) = vat.urns("ETH", manager.urns(cdp));
        assertEq(ink, 0);
        assertEq(art, 0);

        (ink, art) = vat.urns("ETH", address(user));
        assertEq(ink, 1 ether);
        assertEq(art, 50 ether);

        user.doHope(vat, address(manager));
        user.doUrnAllow(manager, address(this), 1);

        if(withTopup) reachTopup(cdp);
        if(withBite) reachBite(cdp);

        (uint inkPre, uint artPre) = vat.urns("ETH", manager.urns(cdp));
        artPre += LiquidationMachine(manager).cushion(cdp);

        manager.enter(address(user), cdp);

        assertEq(LiquidationMachine(manager).cushion(cdp), 0);

        (ink, art) = vat.urns("ETH", manager.urns(cdp));
        assertEq(ink, 1 ether + inkPre);
        assertEq(art, 50 ether + artPre);

        (ink, art) = vat.urns("ETH", address(user));
        assertEq(ink, 0);
        assertEq(art, 0);
    }

    function testFailEnterOtherSrc() public {
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(address(user), 1 ether);
        user.doVatFrob(vat, "ETH", address(user), address(user), address(user), 1 ether, 50 ether);

        uint cdp = manager.open("ETH", address(this));

        user.doHope(vat, address(manager));
        manager.enter(address(user), cdp);
    }

    function testFailEnterOtherSrc2() public {
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(address(user), 1 ether);
        user.doVatFrob(vat, "ETH", address(user), address(user), address(user), 1 ether, 50 ether);

        uint cdp = manager.open("ETH", address(this));

        user.doUrnAllow(manager, address(this), 1);
        manager.enter(address(user), cdp);
    }

    function testEnterOtherCdp() public {
        testEnterOtherCdp(false, false);
    }

    function testEnterOtherCdpWithTopup() public {
        testEnterOtherCdp(true, false);
    }

    function testFailedEnterOtherCdpWithBite() public {
        testEnterOtherCdp(false, true);
    }

    function testEnterOtherCdp(bool withTopup, bool withBite) internal {
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(address(this), 1 ether);
        vat.frob("ETH", address(this), address(this), address(this), 1 ether, 50 ether);
        uint cdp = manager.open("ETH", address(this));
        manager.give(cdp, address(user));

        (uint ink, uint art) = vat.urns("ETH", manager.urns(cdp));
        assertEq(ink, 0);
        assertEq(art, 0);

        (ink, art) = vat.urns("ETH", address(this));
        assertEq(ink, 1 ether);
        assertEq(art, 50 ether);

        vat.hope(address(manager));
        user.doCdpAllow(manager, cdp, address(this), 1);

        if(withTopup) reachTopup(cdp);
        if(withBite) reachBite(cdp);
        (uint inkPre, uint artPre) = vat.urns("ETH", manager.urns(cdp));
        artPre += LiquidationMachine(manager).cushion(cdp);

        manager.enter(address(this), cdp);

        assertEq(LiquidationMachine(manager).cushion(cdp), 0);

        (ink, art) = vat.urns("ETH", manager.urns(cdp));
        assertEq(ink, 1 ether + inkPre);
        assertEq(art, 50 ether + artPre);

        (ink, art) = vat.urns("ETH", address(this));
        assertEq(ink, 0);
        assertEq(art, 0);
    }

    function testFailEnterOtherCdp() public {
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(address(this), 1 ether);
        vat.frob("ETH", address(this), address(this), address(this), 1 ether, 50 ether);
        uint cdp = manager.open("ETH", address(this));
        manager.give(cdp, address(user));

        vat.hope(address(manager));
        manager.enter(address(this), cdp);
    }

    function testFailEnterOtherCdp2() public {
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        ethJoin.join(address(this), 1 ether);
        vat.frob("ETH", address(this), address(this), address(this), 1 ether, 50 ether);
        uint cdp = manager.open("ETH", address(this));
        manager.give(cdp, address(user));

        user.doCdpAllow(manager, cdp, address(this), 1);
        manager.enter(address(this), cdp);
    }

    function testShift() public {
        testShift(false, false, false, false);
    }

    function testShiftSrcTopup() public {
        testShift(true, false, false, false);
    }

    function testShiftDstTopup() public {
        testShift(false, true, false, false);
    }

    function testShiftSrcDstTopup() public {
        testShift(true, true, false, false);
    }

    function testFailedShiftSrcBite() public {
        testShift(false, false, true, false);
    }

    function testFailedShiftDstBite() public {
        testShift(false, false, false, true);
    }

    function testFailedShiftSrcDstBite() public {
        testShift(false, false, true, true);
    }

    function testShift(bool srcTopup, bool dstTopup, bool srcBite, bool dstBite) internal {
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        uint cdpSrc = manager.open("ETH", address(this));
        ethJoin.join(address(manager.urns(cdpSrc)), 1 ether);
        manager.frob(cdpSrc, 1 ether, 50 ether);
        uint cdpDst = manager.open("ETH", address(this));

        (uint ink, uint art) = vat.urns("ETH", manager.urns(cdpDst));
        assertEq(ink, 0);
        assertEq(art, 0);

        (ink, art) = vat.urns("ETH", manager.urns(cdpSrc));
        assertEq(ink, 1 ether);
        assertEq(art, 50 ether);

        if(srcTopup) reachTopup(cdpSrc);
        if(dstTopup) reachTopup(cdpDst);
        if(srcBite) reachBite(cdpSrc);
        if(dstBite) reachBite(cdpDst);

        (uint inkPre, uint artPre) = vat.urns("ETH", manager.urns(cdpDst));
        artPre += LiquidationMachine(manager).cushion(cdpDst);

        manager.shift(cdpSrc, cdpDst);

        assertEq(LiquidationMachine(manager).cushion(cdpSrc), 0);
        assertEq(LiquidationMachine(manager).cushion(cdpDst), 0);

        (ink, art) = vat.urns("ETH", manager.urns(cdpDst));
        assertEq(ink, 1 ether + inkPre);
        assertEq(art, 50 ether + artPre);

        (ink, art) = vat.urns("ETH", manager.urns(cdpSrc));
        assertEq(ink, 0);
        assertEq(art, 0);
    }

    function testShiftOtherCdpDst() public {
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        uint cdpSrc = manager.open("ETH", address(this));
        ethJoin.join(address(manager.urns(cdpSrc)), 1 ether);
        manager.frob(cdpSrc, 1 ether, 50 ether);
        uint cdpDst = manager.open("ETH", address(this));
        manager.give(cdpDst, address(user));

        (uint ink, uint art) = vat.urns("ETH", manager.urns(cdpDst));
        assertEq(ink, 0);
        assertEq(art, 0);

        (ink, art) = vat.urns("ETH", manager.urns(cdpSrc));
        assertEq(ink, 1 ether);
        assertEq(art, 50 ether);

        user.doCdpAllow(manager, cdpDst, address(this), 1);
        manager.shift(cdpSrc, cdpDst);

        (ink, art) = vat.urns("ETH", manager.urns(cdpDst));
        assertEq(ink, 1 ether);
        assertEq(art, 50 ether);

        (ink, art) = vat.urns("ETH", manager.urns(cdpSrc));
        assertEq(ink, 0);
        assertEq(art, 0);
    }

    function testFailShiftOtherCdpDst() public {
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        uint cdpSrc = manager.open("ETH", address(this));
        ethJoin.join(address(manager.urns(cdpSrc)), 1 ether);
        manager.frob(cdpSrc, 1 ether, 50 ether);
        uint cdpDst = manager.open("ETH", address(this));
        manager.give(cdpDst, address(user));

        manager.shift(cdpSrc, cdpDst);
    }

    function testShiftOtherCdpSrc() public {
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        uint cdpSrc = manager.open("ETH", address(this));
        ethJoin.join(address(manager.urns(cdpSrc)), 1 ether);
        manager.frob(cdpSrc, 1 ether, 50 ether);
        uint cdpDst = manager.open("ETH", address(this));
        manager.give(cdpSrc, address(user));

        (uint ink, uint art) = vat.urns("ETH", manager.urns(cdpDst));
        assertEq(ink, 0);
        assertEq(art, 0);

        (ink, art) = vat.urns("ETH", manager.urns(cdpSrc));
        assertEq(ink, 1 ether);
        assertEq(art, 50 ether);

        user.doCdpAllow(manager, cdpSrc, address(this), 1);
        manager.shift(cdpSrc, cdpDst);

        (ink, art) = vat.urns("ETH", manager.urns(cdpDst));
        assertEq(ink, 1 ether);
        assertEq(art, 50 ether);

        (ink, art) = vat.urns("ETH", manager.urns(cdpSrc));
        assertEq(ink, 0);
        assertEq(art, 0);
    }

    function testFailShiftOtherCdpSrc() public {
        weth.mint(1 ether);
        weth.approve(address(ethJoin), 1 ether);
        uint cdpSrc = manager.open("ETH", address(this));
        ethJoin.join(address(manager.urns(cdpSrc)), 1 ether);
        manager.frob(cdpSrc, 1 ether, 50 ether);
        uint cdpDst = manager.open("ETH", address(this));
        manager.give(cdpSrc, address(user));

        manager.shift(cdpSrc, cdpDst);
    }


    function testChangePoolContract() public {
        FakeUser newJar = new FakeUser();
        pool = deployNewPoolContract(address(newJar));

        manager.setPoolContract(address(pool));

        uint cdp = manager.open("ETH", address(this));

        // expect zero gem before bite
        assertEq(vat.gem("ETH", address(newJar)), 0);
        reachBite(cdp);
        // expect some balance after bite
        assertTrue(vat.gem("ETH", address(newJar)) > 0);

    }

    function testChangeScoreContract() public {
        timeReset();

        score = deployNewScoreContract();

        manager.setScoreContract(BCdpScoreLike(address(score)));

        uint cdp = manager.open("ETH", address(this));

        reachTopup(cdp);

        uint fwdTimeBy = 10;
        forwardTime(fwdTimeBy);

        uint expectedInkScore = 1 ether * fwdTimeBy;
        uint exoectedArtScore = 50 ether * fwdTimeBy;
        expectScore(cdp, "ETH", expectedInkScore, exoectedArtScore, 0);

        // user ink + liquidator ink
        uint expectedInkGlobalScore = (1 ether + 1 ether) * fwdTimeBy;
        // uint art + liquidator art
        uint expectedArtGlobalScore = (50 ether + 51 ether) * fwdTimeBy;
        expectGlobalScore("ETH", expectedInkGlobalScore, expectedArtGlobalScore, 0);

    }

    function testChangePoolAndScoreContracts() public {
        timeReset();
        pool = deployNewPoolContract();
        score = deployNewScoreContract();

        manager.setPoolContract(address(pool));
        manager.setScoreContract(BCdpScoreLike(address(score)));

        uint cdp = manager.open("ETH", address(this));
        reachTopup(cdp);

        uint fwdTimeBy = 10;
        forwardTime(fwdTimeBy);

        uint expectedInkScore = 1 ether * fwdTimeBy;
        uint exoectedArtScore = 50 ether * fwdTimeBy;
        expectScore(cdp, "ETH", expectedInkScore, exoectedArtScore, 0);

        // user ink + liquidator ink
        uint expectedInkGlobalScore = (1 ether + 1 ether) * fwdTimeBy;
        // uint art + liquidator art
        uint expectedArtGlobalScore = (50 ether + 51 ether) * fwdTimeBy;
        expectGlobalScore("ETH", expectedInkGlobalScore, expectedArtGlobalScore, 0);

    }

    function testFailNonAuthSetPool() public {
        pool = deployNewPoolContract();

        user.doSetPool(manager, address(pool));
    }

    function testFailNonAuthSetScoreContract() public {
        score = deployNewScoreContract();

        user.doSetScore(manager, BCdpScoreLike(address(score)));
    }
}

contract ChainLog {

    event Rely(address usr);
    event Deny(address usr);
    event UpdateVersion(string version);
    event UpdateSha256sum(string sha256sum);
    event UpdateIPFS(string ipfs);
    event UpdateAddress(bytes32 key, address addr);
    event RemoveAddress(bytes32 key);

    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) external auth { wards[usr] = 1; emit Rely(usr); }
    function deny(address usr) external auth { wards[usr] = 0; emit Deny(usr); }
    modifier auth {
        require(wards[msg.sender] == 1, "ChainLog/not-authorized");
        _;
    }

    struct Location {
        uint256  pos;
        address  addr;
    }
    mapping (bytes32 => Location) location;

    bytes32[] public keys;

    string public version;
    string public sha256sum;
    string public ipfs;

    constructor() public {
        wards[msg.sender] = 1;
        setVersion("0.0.0");
        setAddress("CHANGELOG", address(this));
    }

    /// @notice Set the "version" of the current changelog
    /// @param _version The version string (optional)
    function setVersion(string memory _version) public auth {
        version = _version;
        emit UpdateVersion(_version);
    }

    /// @notice Set the "sha256sum" of some current external changelog
    /// @dev designed to store sha256 of changelog.makerdao.com hosted log
    /// @param _sha256sum The sha256 sum (optional)
    function setSha256sum(string memory _sha256sum) public auth {
        sha256sum = _sha256sum;
        emit UpdateSha256sum(_sha256sum);
    }

    /// @notice Set the IPFS hash of a pinned changelog
    /// @dev designed to store IPFS pin hash that can retreive changelog json
    /// @param _ipfs The ipfs pin hash of an ipfs hosted log (optional)
    function setIPFS(string memory _ipfs) public auth {
        ipfs = _ipfs;
        emit UpdateIPFS(_ipfs);
    }

    /// @notice Set the key-value pair for a changelog item
    /// @param _key  the changelog key (ex. MCD_VAT)
    /// @param _addr the address to the contract
    function setAddress(bytes32 _key, address _addr) public auth {
        if (count() > 0 && _key == keys[location[_key].pos]) {
            location[_key].addr = _addr;   // Key exists in keys (update)
        } else {
            _addAddress(_key, _addr);      // Add key to keys array
        }
        emit UpdateAddress(_key, _addr);
    }

    /// @notice Removes the key from the keys list()
    /// @dev removes the item from the array but moves the last element to it's place
    //   WARNING: To save the expense of shifting an array on-chain,
    //     this will replace the key to be deleted with the last key
    //     in the array, and can therefore result in keys being out
    //     of order. Use this only if you intend to reorder the list(),
    //     otherwise consider using `setAddress("KEY", address(0));`
    /// @param _key the key to be removed
    function removeAddress(bytes32 _key) public auth {
        _removeAddress(_key);
        emit RemoveAddress(_key);
    }

    /// @notice Returns the number of keys being tracked in the keys array
    /// @return the number of keys as uint256
    function count() public view returns (uint256) {
        return keys.length;
    }

    /// @notice Returns the key and address of an item in the changelog array (for enumeration)
    /// @dev _index is 0-indexed to the underlying array
    /// @return a tuple containing the key and address associated with that key
    function get(uint256 _index) public view returns (bytes32, address) {
        return (keys[_index], location[keys[_index]].addr);
    }

    /// @notice Returns the list of keys being tracked by the changelog
    /// @dev May fail if keys is too large, if so, call count() and iterate with get()
    function list() public view returns (bytes32[] memory) {
        return keys;
    }

    /// @notice Returns the address for a particular key
    /// @param _key a bytes32 key (ex. MCD_VAT)
    /// @return addr the contract address associated with the key
    function getAddress(bytes32 _key) public view returns (address addr) {
        addr = location[_key].addr;
        require(addr != address(0), "dss-chain-log/invalid-key");
    }

    function _addAddress(bytes32 _key, address _addr) internal {
        keys.push(_key);
        location[keys[keys.length - 1]] = Location(
            keys.length - 1,
            _addr
        );
    }

    function _removeAddress(bytes32 _key) internal {
        uint256 index = location[_key].pos;       // Get pos in array
        require(keys[index] == _key, "dss-chain-log/invalid-key");
        bytes32 move  = keys[keys.length - 1];    // Get last key
        keys[index] = move;                       // Replace
        location[move].pos = index;               // Update array pos
        keys.pop();                               // Trim last key
        delete location[_key];                    // Delete struct data
    }
}
