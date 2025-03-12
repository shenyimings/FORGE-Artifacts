pragma solidity ^0.5.12;

import { BCdpManagerTestBase, Hevm, FakeUser, FakeDaiToUsdPriceFeed } from "./../BCdpManager.t.sol";
import { BCdpScore } from "./../BCdpScore.sol";
import { Pool } from "./Pool.sol";
import { LiquidationMachine } from "./../LiquidationMachine.sol";
import { FlatLiquidatorInfo, LiquidatorBalanceInfo } from "./../info/LiquidatorInfo.sol";

contract FakeMember is FakeUser {
    function doDeposit(Pool pool, uint rad) public {
        pool.deposit(rad);
    }

    function doWithdraw(Pool pool, uint rad) public {
        pool.withdraw(rad);
    }

    function doTopup(Pool pool, uint cdp) public {
        pool.topup(cdp);
    }

    function doUntop(Pool pool, uint cdp) public {
        pool.untop(cdp);
    }

    function doPoolBite(Pool pool, uint cdp, uint dart, uint minInk) public returns(uint){
        return pool.bite(cdp, dart, minInk);
    }
}

contract FakeChainLink {
    function latestAnswer(bytes32 ilk) external pure returns(int) { return 2549152947092904; }
}

contract FakeOracle {
    function latestAnswer(bytes32 ilk) external pure returns(int) { return 130e18; }
}

contract PoolTest is BCdpManagerTestBase {
    uint currTime;
    FakeMember member;
    FakeMember[] members;
    FakeMember nonMember;
    address constant JAR = address(0x1234567890);
    FlatLiquidatorInfo info;
    LiquidatorBalanceInfo balInfo;

    function setUp() public {
        super.setUp();

        currTime = now;
        hevm.warp(currTime);

        address[] memory memoryMembers = new address[](4);
        for(uint i = 0 ; i < 5 ; i++) {
            FakeMember m = new FakeMember();
            seedMember(m);
            m.doHope(vat, address(pool));

            if(i < 4) {
                members.push(m);
                memoryMembers[i] = address(m);
            }
            else nonMember = m;
        }

        pool.setMembers(memoryMembers);
        pool.setProfitParams(99, 100);
        pool.setIlk("ETH", true);

        member = members[0];

        info = new FlatLiquidatorInfo(LiquidationMachine(manager), address(new FakeOracle()), address(new FakeChainLink()));
        balInfo = new LiquidatorBalanceInfo();
    }

    function getMembers() internal view returns(address[] memory) {
        address[] memory memoryMembers = new address[](members.length);
        for(uint i = 0 ; i < members.length ; i++) {
            memoryMembers[i] = address(members[i]);
        }

        return memoryMembers;
    }

    function radToWei(uint rad) pure internal returns(uint) {
        return rad/RAY;
    }

    function openCdp(uint ink, uint art) internal returns(uint){
        uint cdp = manager.open("ETH", address(this));

        weth.mint(ink);
        weth.approve(address(ethJoin), ink);
        ethJoin.join(manager.urns(cdp), ink);

        manager.frob(cdp, int(ink), int(art));

        return cdp;
    }

    function seedMember(FakeMember m) internal {
        uint cdp = openCdp(1e3 ether, 1e3 ether);
        manager.move(cdp, address(m), 1e3 ether * RAY);
    }

    function timeReset() internal {
        currTime = now;
        hevm.warp(currTime);
    }

    function forwardTime(uint deltaInSec) internal {
        currTime += deltaInSec;
        hevm.warp(currTime);
    }

    // 10% per hour = 1.00002648 = 100002648 / 100000000
    function setRateTo1p1() internal {
        uint duty;
        uint rho;
        (duty,) = jug.ilks("ETH");
        assertEq(RAY, duty);
        assertEq(uint(address(vat)), uint(address(jug.vat())));
        jug.drip("ETH");
        forwardTime(1);
        jug.drip("ETH");
        this.file(address(jug), "ETH", "duty", RAY * 100002648 / 100000000);
        (duty,) = jug.ilks("ETH");
        assertEq(RAY * 100002648 / 100000000, duty);
        forwardTime(1);
        jug.drip("ETH");
        (, rho) = jug.ilks("ETH");
        assertEq(rho, now);
        (, uint rate,,,) = vat.ilks("ETH");
        assertEq(RAY * 100002648 / 100000000, rate);
    }

    function almostEqual(uint a, uint b) internal returns(bool) {
        assertTrue(a < uint(1) << 200 && b < uint(1) << 200);

        if(a > b) return almostEqual(b, a);
        if(a * (1e6 + 1) < b * 1e6) return false;

        return true;
    }

    function assertAlmostEq(uint a, uint b) internal {
        if(a > b + 1) {
            assertEq(a, b);
            assertEq(uint(1), 2);
        }
        if(b > a + 1) {
            assertEq(a, b);
            assertEq(uint(1), 3);
        }
    }

    function withExtra(uint num) internal pure returns(uint) {
        return num + 1 ether;
    }

    function expectCushionInfo(
        uint cdp,
        address member,
        uint numMembers,
        bool expCanCallTopupNow,
        bool expShouldCallUntop,
        bool expIsToppedUp
    ) internal {
        (,,, ,,, bool canCallTopupNow, bool shouldCallUntop,, bool isToppedUp) 
            = info.getCushionInfoFlat(cdp, member, numMembers);
        assertTrue(canCallTopupNow == expCanCallTopupNow);
        assertTrue(shouldCallUntop == expShouldCallUntop);
        assertTrue(isToppedUp == expIsToppedUp);
    }

    function expectCushionInfoAllMembers(
        uint cdp,
        FakeMember[] memory members,
        bool canCallTopupNow,
        bool shouldCallUntop,
        bool isToppedUp
    ) internal {
        for(uint i = 0; i < members.length; i++) {
            expectCushionInfo(cdp, address(members[i]), members.length, canCallTopupNow, shouldCallUntop, isToppedUp);
        }
    }

    function expectTotalCushionForMembers(
        FakeMember[] memory members,
        uint expectedCushion
    ) internal {
        for(uint i = 0; i < members.length; i++) {
            uint totalCushion = balInfo.getTotalCushion(address(members[i]), address(pool));
            assertEq(totalCushion, expectedCushion);
        }
    }

    function expectTotalCushionForMember(
        FakeMember member,
        uint expectedCushion
    ) internal {
        uint totalCushion = balInfo.getTotalCushion(address(member), address(pool));
        assertEq(totalCushion, expectedCushion);
        
    }

    function expectTotalCushionForMemberInCdps(
        FakeMember member,
        uint expectedCushion,
        uint startCdp,
        uint endCdp
    ) internal {
        uint totalCushion = balInfo.getTotalCushion(address(member), address(pool), startCdp, endCdp);
        assertEq(totalCushion, expectedCushion);   
    }

    function expectTotalCushionForMembersInCdps(
        FakeMember[] memory members,
        uint expectedCushion,
        uint startCdp,
        uint endCdp
    ) internal {
        for(uint i = 0; i < members.length; i++) {
            uint totalCushion = balInfo.getTotalCushion(address(members[i]), address(pool), startCdp, endCdp);
            assertEq(totalCushion, expectedCushion);
        }
    }


    function testDeposit() public {
        uint userBalance = vat.dai(address(member));
        assertEq(pool.rad(address(member)), 0);
        member.doDeposit(pool, 123);
        assertEq(pool.rad(address(member)), 123);
        assertEq(vat.dai(address(member)), userBalance - 123);
    }

    function testFailedDeposit() public {
        nonMember.doDeposit(pool, 123);
    }

    function testWithdraw() public {
        uint userBalance = vat.dai(address(member));
        member.doDeposit(pool, 123);
        member.doWithdraw(pool, 112);
        assertEq(pool.rad(address(member)), 123 - 112);
        assertEq(vat.dai(address(member)), userBalance - 123 + 112);
    }

    function testFailedWithdrawNonMember() public {
        nonMember.doWithdraw(pool, 1);
    }

    function testFailedWithdrawInsufficientFunds() public {
        member.doDeposit(pool, 123);
        members[1].doDeposit(pool, 123);
        member.doWithdraw(pool, 123 + 1);
    }

    // 2 out of 4 are selected
    function testchooseMembers1() public {
        // sufficient
        members[0].doDeposit(pool, 1000);
        members[2].doDeposit(pool, 950);

        // insufficient
        members[1].doDeposit(pool, 100);
        members[3].doDeposit(pool, 95);

        address[] memory winners = pool.chooseMembers(404, getMembers());
        assertEq(winners.length, 2);
        assertEq(winners[0], address(members[0]));
        assertEq(winners[1], address(members[2]));
    }

    // 2 out of 4 are selected, third user has enough when divided by 4, but not by 3.
    function testchooseMembers2() public {
        // sufficient
        members[1].doDeposit(pool, 1000);
        members[3].doDeposit(pool, 950);

        // insufficient
        members[0].doDeposit(pool, 110);
        members[2].doDeposit(pool, 95);

        address[] memory winners = pool.chooseMembers(400, getMembers());
        assertEq(winners.length, 2);
        assertEq(winners[0], address(members[1]));
        assertEq(winners[1], address(members[3]));
    }

    // all are selected
    function testchooseMembers3() public {
        // sufficient
        members[0].doDeposit(pool, 1000);
        members[1].doDeposit(pool, 950);
        members[2].doDeposit(pool, 850);
        members[3].doDeposit(pool, 750);

        address[] memory winners = pool.chooseMembers(400, getMembers());
        assertEq(winners.length, 4);
        assertEq(winners[0], address(members[0]));
        assertEq(winners[1], address(members[1]));
        assertEq(winners[2], address(members[2]));
        assertEq(winners[3], address(members[3]));
    }

    // none are selected
    function testchooseMembers4() public {
        // insufficient
        members[0].doDeposit(pool, 99);
        members[1].doDeposit(pool, 399);
        members[2].doDeposit(pool, 101);
        members[3].doDeposit(pool, 199);

        address[] memory winners = pool.chooseMembers(400, getMembers());
        assertEq(winners.length, 0);
    }

    // test all possibilities
    function testchooseMembers5() public {
        uint rad = 1000;
        for(uint i = 0 ; i < 16 ; i++) {
            uint expectedNum = 0;
            if(i & 0x1 > 0) expectedNum++;
            if(i & 0x2 > 0) expectedNum++;
            if(i & 0x4 > 0) expectedNum++;
            if(i & 0x8 > 0) expectedNum++;

            address[] memory expectedWinners = new address[](expectedNum);
            uint assignedWinners = 0;

            for(uint j = 0 ; j < members.length ; j++) {
                members[j].doWithdraw(pool, pool.rad(address(members[j])));
                if((i >> j) & 0x1 > 0) {
                    members[j].doDeposit(pool, 1 + rad/expectedNum);
                    expectedWinners[assignedWinners++] = address(members[j]);
                }
                else members[j].doDeposit(pool, rad/members.length - 1);
            }

            address[] memory winners = pool.chooseMembers(rad, getMembers());
            assertEq(winners.length, expectedNum);
            for(uint k = 0 ; k < winners.length ; k++) {
                assertEq(winners[k], expectedWinners[k]);
            }
        }
    }

    // todo test real functionallity
    function testSetIlk() public {
        pool.setIlk("ETH-A", true);
        assertTrue(pool.ilks("ETH-A") == true);
        pool.setIlk("ETH-A", false);
        assertTrue(pool.ilks("ETH-A") == false);

        pool.setIlk("ETH-B", false);
        pool.setIlk("ETH-C", true);
        pool.setIlk("ETH-D", false);
        pool.setIlk("ETH-E", true);

        assertTrue(pool.ilks("ETH-B") == false);
        assertTrue(pool.ilks("ETH-C") == true);
        assertTrue(pool.ilks("ETH-D") == false);
        assertTrue(pool.ilks("ETH-E") == true);
    }

    // TODO - test real functionallity
    function testSetProfitParams() public {
        pool.setProfitParams(123, 456);
        assertEq(pool.shrn(), 123);
        assertEq(pool.shrd(), 456);
    }

    function testchooseMember1() public {
        // sufficient
        members[2].doDeposit(pool, 1000);

        address[] memory winners = pool.chooseMember(0, 404, getMembers());
        assertEq(winners.length, 1);
        assertEq(winners[0], address(members[2]));
    }

    function testchooseMember2() public {
        // sufficient
        members[0].doDeposit(pool, 1000);
        members[1].doDeposit(pool, 1000);
        members[2].doDeposit(pool, 1000);
        members[3].doDeposit(pool, 1000);

        bool one = true; bool two = true; bool three = true; bool four = true;
        uint maxNumIter = 1000;

        timeReset();
        while(one || two || three || four) {
            assertTrue(maxNumIter-- > 0);

            address[] memory winners = pool.chooseMember(0, 404, getMembers());
            assertEq(winners.length, 1);
            if(winners[0] == address(members[0])) one = false;
            if(winners[0] == address(members[1])) two = false;
            if(winners[0] == address(members[2])) three = false;
            if(winners[0] == address(members[3])) four = false;

            forwardTime(23 minutes);
        }
    }

    function testTopAmount() public {
        // open cdp with rate  = 1, that hit liquidation state
        uint cdp = openCdp(1 ether, 110 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI
        timeReset();
        osm.setH(60 * 60);
        osm.setZ(currTime - 40*60);

        (uint dart, uint dtab, uint art) = pool.topAmount(cdp);

        assertEq(uint(dtab), withExtra(10 ether) * RAY);
        assertEq(art, 110 ether);
        assertEq(uint(dart) * RAY, uint(dtab));
    }

    function testTopAmountWithRate() public {
        // open cdp with rate  = 1, that hit liquidation state
        uint cdp = openCdp(1 ether, 100 ether); // 1 eth, 100 dai

        // debt increased to 110 dai
        setRateTo1p1();

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI
        //timeReset();
        osm.setH(60 * 60);
        osm.setZ(currTime - 31 * 60);

        assertEq(osm.zzz() + osm.hop(), now + 29 minutes);

        (, uint currentRate,,,) = vat.ilks("ETH");

        (uint dart, uint dtab, uint art) = pool.topAmount(cdp);
        // in 1:29 hours the debt will be 1.15194784 = 115194784 / 100000000
        forwardTime((60 + 29) * 60);
        jug.drip("ETH");
        (, uint futureRate,,,) = vat.ilks("ETH");

        uint maxArtBeforeLiquidation = uint(100 ether * RAY) / futureRate;

        uint expectedDart = withExtra(100 ether - maxArtBeforeLiquidation);

        assertEq(uint(dtab), expectedDart * currentRate);
        assertEq(uint(dart), expectedDart);
        assertEq(art, 100 ether);
    }

    function testTopAmountNoCushion() public {
        // open cdp with rate  = 1, that hit liquidation state
        uint cdp = openCdp(1 ether, 90 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of -10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI
        timeReset();
        osm.setH(60 * 60);
        osm.setZ(currTime - 40*60);

        (uint dart, uint dtab, uint art) = pool.topAmount(cdp);

        assertEq(dtab, 0);
        assertEq(art, 90 ether);
        assertEq(dart, 0);
    }

    function testTopAmountTooEarly() public {
        // open cdp with rate  = 1, that hit liquidation state
        uint cdp = openCdp(1 ether, 90 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of -10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI
        osm.setH(60 * 60);
        osm.setZ(currTime - 10*60);

        (uint dart, uint dtab, uint art) = pool.topAmount(cdp);

        assertEq(dtab, 0);
        assertEq(art, 90 ether);
        assertEq(dart, 0);
    }

    function testTopAmountInvalidIlk() public {
        // open cdp with rate  = 1, that hit liquidation state
        uint cdp = openCdp(1 ether, 90 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of -10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        pool.setIlk("ETH", false);

        (uint dart, uint dtab, uint art) = pool.topAmount(cdp);

        assertEq(dtab, 0);
        assertEq(art, 90 ether);
        assertEq(dart, 0);
    }

    function testTopAmountInvalidOsmPrice() public {
        // open cdp with rate  = 1, that hit liquidation state
        uint cdp = openCdp(1 ether, 90 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of -10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI
        osm.setValid(false);

        (uint dart, uint dtab, uint art) = pool.topAmount(cdp);

        assertEq(dtab, 0);
        assertEq(art, 90 ether);
        assertEq(dart, 0);
    }

    function testHappyTopup() public returns(uint cdp) {
        members[0].doDeposit(pool, 1000 ether * RAY);
        members[1].doDeposit(pool, 950 ether * RAY);
        members[2].doDeposit(pool, 900 ether * RAY);
        members[3].doDeposit(pool, 850 ether * RAY);

        pool.setMinArt(1 ether);

        // open cdp with rate  = 1, that hit liquidation state
        cdp = openCdp(1 ether, 110 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        (uint dart, uint dtab, uint art) = pool.topAmount(cdp);

        assertEq(uint(dtab), withExtra(10 ether) * RAY);
        assertEq(art, 110 ether);
        assertEq(uint(dart) * RAY, uint(dtab));

        {
            (uint cushionSizeInWei, uint numLiquidators, uint cushionSizeInWeiIfAllHaveBalance,
             uint numLiquidatorsIfAllHaveBalance, bool shouldProvideCushion, bool shouldProvideCushionIfAllHaveBalance,
             bool canCallTopupNow, bool shouldUntop,, bool isToppedUp) = info.getCushionInfoFlat(cdp,address(members[0]), 4);

            assertEq(cushionSizeInWei, dtab / RAY);
            assertEq(numLiquidators, 4);
            assertEq(cushionSizeInWeiIfAllHaveBalance, dtab / (4*RAY));
            assertEq(numLiquidatorsIfAllHaveBalance, 4);
            assertTrue(shouldProvideCushion);
            assertTrue(shouldProvideCushionIfAllHaveBalance);
            assertTrue(canCallTopupNow);
            assertTrue(! shouldUntop);
            assertTrue(! isToppedUp);
        }

        expectTotalCushionForMembers(members, 0);

        members[0].doTopup(pool, cdp);

        (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
        bite; //shh
        assertEq(art, cdpArt);
        assertEq(cdpCushion, uint(dtab));
        assertEq(winners.length, 4);
        assertEq(address(winners[0]), address(members[0]));
        assertEq(address(winners[1]), address(members[1]));
        assertEq(address(winners[2]), address(members[2]));
        assertEq(address(winners[3]), address(members[3]));

        expectTotalCushionForMembers(members, 11 ether / 4); // 10 DAI + 1 extra

        // check balances
        assertEq(pool.rad(address(members[0])), uint(1000 ether * RAY) - uint(1+ dtab/4));
        assertEq(pool.rad(address(members[1])), uint(950 ether * RAY) - uint(1+ dtab/4));
        assertEq(pool.rad(address(members[2])), uint(900 ether * RAY) - uint(1+ dtab/4));
        assertEq(pool.rad(address(members[3])), uint(850 ether * RAY) - uint(1+ dtab/4));
    }

    function testTopupWithTwoMembers() public {
        members[0].doDeposit(pool, 1000 ether * RAY);
        members[2].doDeposit(pool, 900 ether * RAY);

        pool.setMinArt(1 ether);

        // open cdp with rate  = 1, that hit liquidation state
        uint cdp = openCdp(1 ether, 110 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        (uint dart, uint dtab, uint art) = pool.topAmount(cdp);

        assertEq(uint(dtab), withExtra(10 ether) * RAY);
        assertEq(art, 110 ether);
        assertEq(uint(dart) * RAY, uint(dtab));

        {
            (uint cushionSizeInWei, uint numLiquidators, uint cushionSizeInWeiIfAllHaveBalance,
             uint numLiquidatorsIfAllHaveBalance, bool shouldProvideCushion, bool shouldProvideCushionIfAllHaveBalance,
             bool canCallTopupNow, bool shouldUntop,,) = info.getCushionInfoFlat(cdp,address(members[0]), 4);

            assertEq(cushionSizeInWei, dtab / RAY);
            assertEq(numLiquidators, 2);
            assertEq(cushionSizeInWeiIfAllHaveBalance, dtab / (4*RAY));
            assertEq(numLiquidatorsIfAllHaveBalance, 4);
            assertTrue(shouldProvideCushion);
            assertTrue(shouldProvideCushionIfAllHaveBalance);
            assertTrue(canCallTopupNow);
            assertTrue(! shouldUntop);

            (cushionSizeInWei, numLiquidators, cushionSizeInWeiIfAllHaveBalance,
             numLiquidatorsIfAllHaveBalance, shouldProvideCushion, shouldProvideCushionIfAllHaveBalance,
             canCallTopupNow, shouldUntop,,) = info.getCushionInfoFlat(cdp,address(members[1]), 4);

            assertEq(cushionSizeInWei, dtab / RAY);
            assertEq(numLiquidators, 2);
            assertEq(cushionSizeInWeiIfAllHaveBalance, dtab / (4*RAY));
            assertEq(numLiquidatorsIfAllHaveBalance, 4);
            assertTrue(shouldProvideCushion);
            assertTrue(shouldProvideCushionIfAllHaveBalance);
            assertTrue(canCallTopupNow);
            assertTrue(! shouldUntop);
        }

        expectTotalCushionForMembers(members, 0);

        members[0].doTopup(pool, cdp);

        expectTotalCushionForMember(members[0], 11 ether / 2);
        expectTotalCushionForMember(members[1], 0);
        expectTotalCushionForMember(members[2], 11 ether / 2);
        expectTotalCushionForMember(members[3], 0);

        (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
        bite; //shh
        assertEq(art, cdpArt);
        assertEq(cdpCushion, uint(dtab));
        assertEq(winners.length, 2);
        assertEq(address(winners[0]), address(members[0]));
        assertEq(address(winners[1]), address(members[2]));

        // check balances
        assertEq(pool.rad(address(members[0])), uint(1000 ether * RAY) - uint(1+ dtab/2));
        assertEq(pool.rad(address(members[2])), uint(900 ether * RAY) - uint(1+ dtab/2));
    }

    function testSingleTopup() public {
        members[0].doDeposit(pool, 1000 ether * RAY);
        members[1].doDeposit(pool, 950 ether * RAY);
        members[2].doDeposit(pool, 900 ether * RAY);
        members[3].doDeposit(pool, 850 ether * RAY);

        pool.setMinArt(10000 ether);

        // open cdp with rate  = 1, that hit liquidation state
        uint cdp = openCdp(1 ether, 110 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        (uint dart, uint dtab, uint art) = pool.topAmount(cdp);

        assertEq(uint(dtab), withExtra(10 ether) * RAY);
        assertEq(art, 110 ether);
        assertEq(uint(dart) * RAY, uint(dtab));

        address[] memory singleMember = pool.chooseMember(cdp, uint(dtab), getMembers());

        {
            (uint cushionSizeInWei, uint numLiquidators, uint cushionSizeInWeiIfAllHaveBalance,
             uint numLiquidatorsIfAllHaveBalance, bool shouldProvideCushion, bool shouldProvideCushionIfAllHaveBalance,
             bool canCallTopupNow, bool shouldUntop,,) = info.getCushionInfoFlat(cdp, singleMember[0], 4);

            assertEq(cushionSizeInWei, dtab / RAY);
            assertEq(numLiquidators, 1);
            assertEq(cushionSizeInWeiIfAllHaveBalance, dtab / (1*RAY));
            assertEq(numLiquidatorsIfAllHaveBalance, 1);
            assertTrue(shouldProvideCushion);
            assertTrue(shouldProvideCushionIfAllHaveBalance);
            assertTrue(canCallTopupNow);
            assertTrue(! shouldUntop);

            address loser = address(members[0]);
            if(singleMember[0] == loser) loser = address(members[1]);

            (cushionSizeInWei, numLiquidators, cushionSizeInWeiIfAllHaveBalance,
             numLiquidatorsIfAllHaveBalance, shouldProvideCushion, shouldProvideCushionIfAllHaveBalance,
             canCallTopupNow, /*shouldUntop*/,,) = info.getCushionInfoFlat(cdp, loser, 4);

            assertEq(cushionSizeInWei, dtab / RAY);
            assertEq(numLiquidators, 1);
            assertEq(cushionSizeInWeiIfAllHaveBalance, dtab / RAY);
            assertEq(numLiquidatorsIfAllHaveBalance, 1);
            assertTrue(! shouldProvideCushion);
            assertTrue(! shouldProvideCushionIfAllHaveBalance);
            assertTrue(! canCallTopupNow);

            /*
            uint winnerBalance = pool.rad(singleMember[0]);
            singleMember[0].doWithdraw(winnerBalance,pool);

            (cushionSizeInWei, numLiquidators, cushionSizeInWeiIfAllHaveBalance,
             numLiquidatorsIfAllHaveBalance, shouldProvideCushion, shouldProvideCushionIfAllHaveBalance,
             canCallTopupNow, bool shouldUntop,) = info.getCushionInfoFlat(cdp, singleMember[0], 4);

             assertEq(cushionSizeInWei, dtab / RAY);
             assertEq(numLiquidators, 1);
             assertEq(cushionSizeInWeiIfAllHaveBalance, dtab / (1*RAY));
             assertEq(numLiquidatorsIfAllHaveBalance, 1);
             assertTrue(shouldProvideCushion);
             assertTrue(shouldProvideCushionIfAllHaveBalance);
             assertTrue(canCallTopupNow);             */
        }

        FakeMember(singleMember[0]).doTopup(pool, cdp);

        (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
        bite; //shh
        assertEq(art, cdpArt);
        assertEq(cdpCushion, uint(dtab));
        assertEq(winners.length, 1);
        assertEq(address(winners[0]), address(singleMember[0]));

        for(uint i = 0 ; i < 4 ; i++) {
            uint expectedRad = (1000 - 50 * i) * 1 ether * RAY;
            if(address(members[i]) == address(singleMember[0])) expectedRad -= (uint(dtab) + 1);

            assertEq(expectedRad, pool.rad(address(members[i])));
        }
    }

    function testFailedSingleTopupWrongMemberTopup() public {
        members[0].doDeposit(pool, 1000 ether * RAY);
        members[1].doDeposit(pool, 950 ether * RAY);
        members[2].doDeposit(pool, 900 ether * RAY);
        members[3].doDeposit(pool, 850 ether * RAY);

        pool.setMinArt(10000 ether);

        // open cdp with rate  = 1, that hit liquidation state
        uint cdp = openCdp(1 ether, 110 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        (uint dart, uint dtab, uint art) = pool.topAmount(cdp);

        assertEq(uint(dtab), 10 ether * RAY);
        assertEq(art, 110 ether);
        assertEq(uint(dart) * RAY, uint(dtab));

        address[] memory singleMember = pool.chooseMember(cdp, uint(dtab), getMembers());

        if(address(singleMember[0]) == address(members[0])) members[1].doTopup(pool, cdp);
        else members[0].doTopup(pool, cdp);
    }

    function testFailedTopupCushionExist() public {
        uint cdp = testHappyTopup();
        members[0].doTopup(pool, cdp);
    }

    function testFailedTopupNoNeed() public {
        members[0].doDeposit(pool, 1000 ether * RAY);
        members[1].doDeposit(pool, 950 ether * RAY);
        members[2].doDeposit(pool, 900 ether * RAY);
        members[3].doDeposit(pool, 850 ether * RAY);

        // open cdp with rate  = 1, that will not hit liquidation state
        uint cdp = openCdp(1 ether, 90 ether); // 1 eth, 900 dai
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        (uint dart, uint dtab, uint art) = pool.topAmount(cdp);

        (,,, bool should,) = pool.topupInfo(cdp);
        assertEq(uint(should ? 1 : 0), 1);

        assertEq(uint(dtab), 0);
        assertEq(art, 90 ether);
        assertEq(uint(dart) * RAY, uint(dtab));

        members[0].doTopup(pool, cdp);
    }

    function testFailedTopupPoorMembers() public {
        // open cdp with rate  = 1, that hit liquidation state
        uint cdp = openCdp(1 ether, 110 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        (uint dart, uint dtab, uint art) = pool.topAmount(cdp);

        assertEq(uint(dtab), 10 ether * RAY);
        assertEq(art, 110 ether);
        assertEq(uint(dart) * RAY, uint(dtab));

        members[0].doTopup(pool, cdp);
    }

    function testUntopSingle() public {
        members[0].doDeposit(pool, 1000 ether * RAY);

        pool.setMinArt(10000 ether);

        // open cdp with rate  = 1, that hit liquidation state
        uint cdp = openCdp(1 ether, 110 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        (uint dart, uint dtab, uint art) = pool.topAmount(cdp);

        assertEq(uint(dtab), withExtra(10 ether) * RAY);
        assertEq(art, 110 ether);
        assertEq(uint(dart) * RAY, uint(dtab));

        expectTotalCushionForMembers(members, 0);

        members[0].doTopup(pool, cdp);

        expectTotalCushionForMember(members[0], 11 ether);
        expectTotalCushionForMember(members[1], 0);
        expectTotalCushionForMember(members[2], 0);
        expectTotalCushionForMember(members[3], 0);

        (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
        bite; //shh
        assertEq(art, cdpArt);
        assertEq(cdpCushion, uint(dtab));
        assertEq(winners.length, 1);
        assertEq(address(winners[0]), address(members[0]));

        assertEq(pool.rad(address(members[0])), 1000 ether * RAY - uint(dtab) - 1);

        {
            (uint dartAfterTopup,,) = pool.topAmount(cdp);
            assertEq(dartAfterTopup, 0);
            (uint cushionSizeInWei, uint numLiquidators,,
            uint numLiquidatorsIfAllHaveBalance,,,, bool shouldUntop,,bool isToppedUp) = info.getCushionInfoFlat(cdp,address(members[0]), 4);
            assertTrue(! shouldUntop);
            assertTrue(isToppedUp);
            assertEq(numLiquidators, 1);
            assertEq(numLiquidatorsIfAllHaveBalance, 1);
            assertEq(cushionSizeInWei, cdpCushion / RAY);
        }

        // do dummy frob, which will call topup
        manager.frob(cdp, -1, 0);

        {
            (uint cushionSizeInWei, uint numLiquidators,,
             uint numLiquidatorsIfAllHaveBalance,,,, bool shouldUntop,,bool isToppedUp) = info.getCushionInfoFlat(cdp,address(members[0]), 4);
            assertTrue(shouldUntop);
            assertTrue(isToppedUp);
            assertEq(numLiquidators, 1);
            assertEq(numLiquidatorsIfAllHaveBalance, 1);
            assertEq(cushionSizeInWei, cdpCushion / RAY + 100 /* 1 wei less eth collateral */);

            (,,,,,,, shouldUntop,, isToppedUp) = info.getCushionInfoFlat(cdp,address(members[1]), 4);
            assertTrue(! shouldUntop); // as member[1] is not winner
            assertTrue(! isToppedUp);
        }

        // do untop
        members[0].doUntop(pool, cdp);

        expectTotalCushionForMembers(members, 0);

        (,,,,,,,bool shouldUntop,, bool isToppedUp) = info.getCushionInfoFlat(cdp,address(members[0]), 4);
        assertTrue(! shouldUntop);
        assertTrue(! isToppedUp);

        (uint cdpArt2, uint cdpCushion2, address[] memory winners2, uint[] memory bite2) = pool.getCdpData(cdp);
        bite2; //shh
        assertEq(0, cdpArt2);
        assertEq(cdpCushion2, 0);
        assertEq(winners2.length, 0);

        assertEq(pool.rad(address(members[0])), 1000 ether * RAY - 1);
    }

    function testUntopHappy() public {
        uint cdp = testHappyTopup();

        // do dummy frob, which will call topup
        manager.frob(cdp, 0, 0);

        for(uint i = 0 ; i < 4 ; i++) {
            (,,,,,,, bool shouldUntop,,bool isToppedUp) = info.getCushionInfoFlat(cdp,address(members[i]), 4);
            assertTrue(shouldUntop);
            assertTrue(isToppedUp);
        }

        // do untop
        members[0].doUntop(pool, cdp);

        expectTotalCushionForMembers(members, 0);

        for(uint i = 0 ; i < 4 ; i++) {
            (,,,,,,, bool shouldUntop,, bool isToppedUp) = info.getCushionInfoFlat(cdp,address(members[i]), 4);
            assertTrue(! shouldUntop);
            assertTrue(! isToppedUp);
        }

        (uint cdpArt2, uint cdpCushion2, address[] memory winners2, uint[] memory bite2) = pool.getCdpData(cdp);
        bite2; //shh
        assertEq(cdpArt2, 0);
        assertEq(cdpCushion2, 0);
        assertEq(winners2.length, 0);

        assertEq(pool.rad(address(members[0])), 1000 ether * RAY - 1);
        assertEq(pool.rad(address(members[1])), 950 ether * RAY - 1);
        assertEq(pool.rad(address(members[2])), 900 ether * RAY - 1);
        assertEq(pool.rad(address(members[3])), 850 ether * RAY - 1);
    }

    function testFailedUntopCushionNotReleased() public {
        uint cdp = testHappyTopup();

        // do untop
        members[0].doUntop(pool, cdp);
    }

    function testSimpleBite() public {
        members[0].doDeposit(pool, 1000 ether * RAY);
        members[1].doDeposit(pool, 950 ether * RAY);
        members[2].doDeposit(pool, 900 ether * RAY);
        members[3].doDeposit(pool, 850 ether * RAY);

        uint cdp = openCdp(1 ether, 110 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        (uint availableBiteInArt, uint availableBiteInDaiWei, bool canCallBiteNow,) =
            info.getBiteInfoFlat(cdp, address(members[0]));
        assertEq(availableBiteInArt ,0);
        assertEq(availableBiteInDaiWei ,0);
        assertTrue(! canCallBiteNow);

        expectTotalCushionForMembers(members, 0);

        members[0].doTopup(pool, cdp);

        expectTotalCushionForMembers(members, 11 ether / 4);

        (availableBiteInArt, availableBiteInDaiWei, canCallBiteNow,) = info.getBiteInfoFlat(cdp, address(members[0]));
        assertEq(availableBiteInArt, 110 ether / 4);
        assertEq(availableBiteInDaiWei, 110 ether / 4);
        assertTrue(! canCallBiteNow);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        pipETH.poke(bytes32(uint(130 * 1e18)));

        (availableBiteInArt, availableBiteInDaiWei, canCallBiteNow,) = info.getBiteInfoFlat(cdp, address(members[0]));
        assertEq(availableBiteInArt, 110 ether / 4);
        assertEq(availableBiteInDaiWei, 110 ether / 4);
        assertTrue(canCallBiteNow);

        //uint ethBefore = vat.gem("ETH", address(members[0]));
        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(99, 100); // 1% goes to jar
        // for 10 ether we expect 10/130 * 1.1 = 11/130, from which 99% goes to member
        uint _100Percent = 11 ether / uint(130);
        uint expectedEth = _100Percent * uint(99) / 100;
        uint expectedEthInJar = _100Percent - expectedEth;

        assertTrue(_100Percent >= expectedEth);

        (,,uint debtInDaiWei,,uint expectedEthReturn,) = info.getVaultInfoFlat(cdp);
        assertEq(debtInDaiWei, 110 ether);
        assertEq(expectedEth * 11 / 1e3, expectedEthReturn / 1e3);
        assertEq(expectedEth, info.getExpectedEthReturn("ETH",10 ether,130e18));

        assertTrue(! canKeepersBite(cdp));
        uint dink = members[0].doPoolBite(pool, cdp, 10 ether, expectedEth);
        assertTrue(! canKeepersBite(cdp));
        assertEq(uint(dink), expectedEth);
        assertEq(vat.gem("ETH", address(members[0])), expectedEth);
        assertEq(vat.gem("ETH", address(jar)), expectedEthInJar);

        expectTotalCushionForMember(members[0], 11 ether / 4 - 1 ether);
        expectTotalCushionForMember(members[1], 11 ether / 4);
        expectTotalCushionForMember(members[2], 11 ether / 4);
        expectTotalCushionForMember(members[3], 11 ether / 4);

        (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
        cdpArt; //shh
        winners; //shh
        assertEq(bite[0], 10 ether);

        uint userRemainingCushion = 1 + cdpCushion / 4 - 10 * cdpCushion / 110; // 10/110 of the debt is being bitten
        uint userPoolBalance = radToWei(pool.rad(address(members[0])));
        uint userExpectedPoolBalance = radToWei(990 ether * RAY - userRemainingCushion); // TODO - check why -1?
        assertEq(userPoolBalance, userExpectedPoolBalance);
    }

    function testFullBite() public {
        bool canCallTopupNow;
        bool shouldCallUntop;
        bool isToppedUp;

        members[0].doDeposit(pool, 1000 ether * RAY);
        members[1].doDeposit(pool, 950 ether * RAY);
        members[2].doDeposit(pool, 900 ether * RAY);
        members[3].doDeposit(pool, 850 ether * RAY);

        uint cdp = openCdp(1 ether, 104 ether); // 1 eth, 104 dai

        // set next price to 150, which means a cushion of 5 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        expectTotalCushionForMembers(members, 0);

        members[0].doTopup(pool, cdp);

        expectTotalCushionForMembers(members, 5 ether / 4); // 4+1 DAI cushion

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        pipETH.poke(bytes32(uint(130 * 1e18)));

        //uint ethBefore = vat.gem("ETH", address(members[0]));
        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(98, 100); // 2% goes to jar
        // for 26 ether we expect 26/130 * 1.1 = 28.6/130, from which 98% goes to member
        uint expectedEth = uint(98) * 286 ether / (130 * 100 * 10);
        for(uint i = 0 ; i < 4 ; i++) {
            (,,, ,,, canCallTopupNow, shouldCallUntop,, isToppedUp) = 
                info.getCushionInfoFlat(cdp, address(members[i]), 4);
            assertTrue(! canCallTopupNow);
            assertTrue(isToppedUp);
            assertTrue(! shouldCallUntop);
        
            assertTrue(! canKeepersBite(cdp));
            uint dink = members[i].doPoolBite(pool, cdp, 26 ether, expectedEth);
            assertTrue(! canKeepersBite(cdp));
            assertEq(uint(dink), expectedEth);
            assertEq(vat.gem("ETH", address(members[i])), expectedEth);
            (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
            cdpArt; //shh
            cdpCushion; //shh
            winners; //shh
            assertEq(bite[i], 26 ether);
            assertEq(pool.rad(address(members[i])), (1000 ether - 50 ether * i - 26 ether) * RAY - 1);

            expectTotalCushionForMember(members[i], 0);

            for(uint j = i ; j < 4 ; j++) {
                (,,, ,,, canCallTopupNow, shouldCallUntop,, isToppedUp) = 
                    info.getCushionInfoFlat(cdp, address(members[j]), 4);
            
                if(j == i) {
                    // full bitten case by first j member
                    assertTrue(! canCallTopupNow);         
                    assertTrue(! isToppedUp);
                    assertTrue(! shouldCallUntop);
                } else {
                    // not bitten by rest members
                    assertTrue(! canCallTopupNow);
                    assertTrue(isToppedUp);
                    assertTrue(! shouldCallUntop);
                }
            }
        }

        expectTotalCushionForMembers(members, 0);

        // jar should get 2% from 104 * 1.1 / 130
        assertEq(vat.gem("ETH", address(jar)), (104 ether * 11 / 1300)/50);

        // before untop
        for(uint i = 0 ; i < 4 ; i++) {
            (,,, ,,, canCallTopupNow, shouldCallUntop,, isToppedUp) = 
                info.getCushionInfoFlat(cdp, address(members[i]), 4);
            assertTrue(! canCallTopupNow);
            assertTrue(! isToppedUp);
            assertTrue(! shouldCallUntop); // as full bitten
        }

        // untop
        members[0].doUntop(pool, cdp);

        // after untop
        for(uint i = 0 ; i < 4 ; i++) {
            (,,, ,,, canCallTopupNow, shouldCallUntop,, isToppedUp) = 
                info.getCushionInfoFlat(cdp, address(members[i]), 4);
            assertTrue(! canCallTopupNow);
            assertTrue(! isToppedUp);
            assertTrue(! shouldCallUntop);
        }
    }

    function doBite(FakeMember m, Pool pool, uint cdp, uint dart, bool rate) internal {
        (bytes32 price32) = pipETH.read();
        uint price = uint(price32);

        uint shrn = pool.shrn();
        uint shrd = pool.shrd();

        // 10% chop
        uint expectedInk = (dart * 1e18 * 110 / (price*100)) * shrn / shrd;
        uint expectedJar = (dart * 1e18 * 110 / (price*100)) - expectedInk;

        if(rate) {
            (, uint currentRate,,,) = vat.ilks("ETH");
            expectedJar = expectedJar * currentRate / RAY;
            expectedInk = expectedInk * currentRate / RAY;
        }

        uint mInkBefore = vat.gem("ETH", address(m));
        uint jarInkBefore = vat.gem("ETH", address(jar));

        assertTrue(! canKeepersBite(cdp));
        m.doBite(pool, cdp, dart, expectedInk);
        assertTrue(! canKeepersBite(cdp));

        uint mInkAfter = vat.gem("ETH", address(m));
        uint jarInkAfter = vat.gem("ETH", address(jar));

        //assertEq(mInkAfter - mInkBefore,expectedInk);
        //assertEq(jarInkAfter - jarInkBefore,expectedJar);

        assertTrue(mInkAfter - mInkBefore <= expectedInk + 2 && expectedInk <= 2 + mInkAfter - mInkBefore);
        assertTrue(jarInkAfter - jarInkBefore <= expectedJar + 2 && expectedJar <= 2 + jarInkAfter - jarInkBefore);
    }

    function testMultiCDPBiteInPartsThenUntop() public {
        timeReset();

        members[0].doDeposit(pool, 1000 ether * RAY);
        members[1].doDeposit(pool, 950 ether * RAY);
        members[2].doDeposit(pool, 900 ether * RAY);
        members[3].doDeposit(pool, 850 ether * RAY);

        uint cdp = openCdp(1 ether, 104 ether); // 1 eth, 104 dai
        uint cdp2 = openCdp(1 ether, 104 ether); // 1 eth, 104 dai

        // set next price to 150, which means a cushion of 5 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        expectTotalCushionForMembers(members, 0);

        members[3].doTopup(pool, cdp);

        expectTotalCushionForMembers(members, 5 ether / 4);
        expectTotalCushionForMembersInCdps(members, 5 ether / 4, cdp, cdp);
        expectTotalCushionForMembersInCdps(members, 0, cdp2, cdp2);
        expectTotalCushionForMembersInCdps(members, 5 ether / 4, cdp, cdp2);

        members[0].doTopup(pool, cdp2);

        expectTotalCushionForMembers(members, 5 ether * 2 / 4);
        expectTotalCushionForMembersInCdps(members, 5 ether / 4, cdp, cdp);
        expectTotalCushionForMembersInCdps(members, 5 ether / 4, cdp2, cdp2);
        expectTotalCushionForMembersInCdps(members, 5 ether * 2/ 4, cdp, cdp2);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        pipETH.poke(bytes32(uint(130 * 1e18)));

        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(935, 1000); // 6.5% goes to jar

        /* expectCushionInfoAllMembers(cdp, members, canCallTopupNow, shoulCallUntop, isToppedUp) */
        expectCushionInfoAllMembers(cdp, members, false, false, true);
        
        doBite(members[1], pool, cdp, 15 ether, false);
        // no change in cushionInfo, as member[1] bite partially 
        expectCushionInfoAllMembers(cdp, members, false, false, true);
        uint perMemberCushion = 5 ether * 2 / 4;
        uint expCushionMem0 = perMemberCushion;
        // (5 DAI / 4) - (5 * 15/104) - 1 :: (-1 is for rounding error)
        uint expCushionMem1 = perMemberCushion - (uint(5 ether) * uint(15 ether) / uint(104 ether)) - 1;
        uint expCushionMem2 = perMemberCushion;
        uint expCushionMem3 = perMemberCushion;
        expectTotalCushionForMember(members[0], expCushionMem0);        
        expectTotalCushionForMember(members[1], expCushionMem1);
        expectTotalCushionForMember(members[2], expCushionMem2);
        expectTotalCushionForMember(members[3], expCushionMem3);

        doBite(members[0], pool, cdp, 13 ether, false);
        // no change in cushionInfo, as member[0] bite partially 
        expectCushionInfoAllMembers(cdp, members, false, false, true);
        expCushionMem0 = expCushionMem0 - (uint(5 ether) * uint(13 ether) / uint(104 ether));
        expectTotalCushionForMember(members[0], expCushionMem0);        
        expectTotalCushionForMember(members[1], expCushionMem1);
        expectTotalCushionForMember(members[2], expCushionMem2);
        expectTotalCushionForMember(members[3], expCushionMem3);
        
        doBite(members[2], pool, cdp, 17 ether, false);
        // no change in cushionInfo, as member[2] bite partially 
        expectCushionInfoAllMembers(cdp, members, false, false, true);
        expCushionMem2 = expCushionMem2 - (uint(5 ether) * uint(17 ether) / uint(104 ether)) - 1;
        expectTotalCushionForMember(members[0], expCushionMem0);
        expectTotalCushionForMember(members[1], expCushionMem1);
        expectTotalCushionForMember(members[2], expCushionMem2);
        expectTotalCushionForMember(members[3], expCushionMem3);

        doBite(members[1], pool, cdp, 9 ether, false);
        // no change in cushionInfo, as member[1] bite partially 
        expectCushionInfoAllMembers(cdp, members, false, false, true);
        expCushionMem1 = expCushionMem1 - (uint(5 ether) * uint(9 ether) / uint(104 ether)) - 1;
        expectTotalCushionForMember(members[0], expCushionMem0);
        expectTotalCushionForMember(members[1], expCushionMem1);
        expectTotalCushionForMember(members[2], expCushionMem2);
        expectTotalCushionForMember(members[3], expCushionMem3);

        doBite(members[0], pool, cdp, 10 ether, false);
        // no change in cushionInfo, as member[0] bite partially 
        expectCushionInfoAllMembers(cdp, members, false, false, true);
        expCushionMem0 = expCushionMem0 - (uint(5 ether) * uint(10 ether) / uint(104 ether)) - 1;
        expectTotalCushionForMember(members[0], expCushionMem0);
        expectTotalCushionForMember(members[1], expCushionMem1);
        expectTotalCushionForMember(members[2], expCushionMem2);
        expectTotalCushionForMember(members[3], expCushionMem3);

        doBite(members[0], pool, cdp, 3 ether, false);
        // change in cushionInfo, as members[0] bite full
        expectCushionInfo(cdp, address(members[0]), 4, false, false, false);
        // but no change in members - 1,2,3
        expectCushionInfo(cdp, address(members[1]), 4, false, false, true);
        expectCushionInfo(cdp, address(members[2]), 4, false, false, true);
        expectCushionInfo(cdp, address(members[3]), 4, false, false, true);
        expCushionMem0 = expCushionMem0 - (uint(5 ether) * uint(3 ether) / uint(104 ether));
        expectTotalCushionForMember(members[0], expCushionMem0);
        expectTotalCushionForMember(members[1], expCushionMem1);
        expectTotalCushionForMember(members[2], expCushionMem2);
        expectTotalCushionForMember(members[3], expCushionMem3);

        assertTrue(LiquidationMachine(manager).bitten(cdp));

        // fast forward until no longer bitten
        forwardTime(60*60 + 1);
        assertTrue(! LiquidationMachine(manager).bitten(cdp));

        // do dummy operation to untop
        manager.frob(cdp, 0, 0);

        // member[0] bitten full
        expectCushionInfo(cdp, address(members[0]), 4, false, false, false);
        // rest members bitten partially
        expectCushionInfo(cdp, address(members[1]), 4, false, true, true);
        expectCushionInfo(cdp, address(members[2]), 4, false, true, true);
        expectCushionInfo(cdp, address(members[3]), 4, false, true, true);

        members[3].doUntop(pool, cdp);

        uint cdp2TopUpAmt = 5 ether / 4;
        expectTotalCushionForMembers(members, cdp2TopUpAmt);
        expectTotalCushionForMembersInCdps(members, 0, cdp, cdp);
        expectTotalCushionForMembersInCdps(members, 5 ether / 4, cdp2, cdp2);
        expectTotalCushionForMembersInCdps(members, 5 ether / 4, cdp, cdp2);

        // after untop
        expectCushionInfoAllMembers(cdp, members, false, false, false);

        // check balances
        // 0 consumed 26 ether
        assertEq(radToWei(pool.rad(address(members[0]))), radToWei((1000 ether - 26 ether - cdp2TopUpAmt) * RAY - 1));
        // 1 consumed 24 ether
        assertEq(radToWei(pool.rad(address(members[1]))), radToWei((950 ether - 24 ether - cdp2TopUpAmt) * RAY - 1));
        // 2 consumed 17 ether
        assertEq(radToWei(pool.rad(address(members[2]))), radToWei((900 ether - 17 ether - cdp2TopUpAmt) * RAY - 1));
        // 3 consumed 0 ether
        assertEq(radToWei(pool.rad(address(members[3]))), radToWei((850 ether - 0 ether - cdp2TopUpAmt) * RAY - 1));

        // check that cdp was reset
        (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
        assertEq(cdpArt, 0);
        assertEq(cdpCushion, 0);
        assertEq(winners.length, 0);
        assertEq(bite.length, 0);
    }

    function testBiteInPartsThenUntop() public {
        timeReset();

        members[0].doDeposit(pool, 1000 ether * RAY);
        members[1].doDeposit(pool, 950 ether * RAY);
        members[2].doDeposit(pool, 900 ether * RAY);
        members[3].doDeposit(pool, 850 ether * RAY);

        uint cdp = openCdp(1 ether, 104 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 5 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        expectTotalCushionForMembers(members, 0);

        members[3].doTopup(pool, cdp);

        expectTotalCushionForMembers(members, 5 ether / 4);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        pipETH.poke(bytes32(uint(130 * 1e18)));

        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(935, 1000); // 6.5% goes to jar

        /* expectCushionInfoAllMembers(cdp, members, canCallTopupNow, shoulCallUntop, isToppedUp) */
        expectCushionInfoAllMembers(cdp, members, false, false, true);
        
        doBite(members[1], pool, cdp, 15 ether, false);
        // no change in cushionInfo, as member[1] bite partially 
        expectCushionInfoAllMembers(cdp, members, false, false, true);
        uint perMemberCushion = 5 ether / 4;
        uint expCushionMem0 = perMemberCushion;
        // (5 DAI / 4) - (5 * 15/104) - 1 :: (-1 is for rounding error)
        uint expCushionMem1 = perMemberCushion - (uint(5 ether) * uint(15 ether) / uint(104 ether)) - 1;
        uint expCushionMem2 = perMemberCushion;
        uint expCushionMem3 = perMemberCushion;
        expectTotalCushionForMember(members[0], expCushionMem0);        
        expectTotalCushionForMember(members[1], expCushionMem1);
        expectTotalCushionForMember(members[2], expCushionMem2);
        expectTotalCushionForMember(members[3], expCushionMem3);

        doBite(members[0], pool, cdp, 13 ether, false);
        // no change in cushionInfo, as member[0] bite partially 
        expectCushionInfoAllMembers(cdp, members, false, false, true);
        expCushionMem0 = expCushionMem0 - (uint(5 ether) * uint(13 ether) / uint(104 ether));
        expectTotalCushionForMember(members[0], expCushionMem0);        
        expectTotalCushionForMember(members[1], expCushionMem1);
        expectTotalCushionForMember(members[2], expCushionMem2);
        expectTotalCushionForMember(members[3], expCushionMem3);
        
        doBite(members[2], pool, cdp, 17 ether, false);
        // no change in cushionInfo, as member[2] bite partially 
        expectCushionInfoAllMembers(cdp, members, false, false, true);
        expCushionMem2 = expCushionMem2 - (uint(5 ether) * uint(17 ether) / uint(104 ether)) - 1;
        expectTotalCushionForMember(members[0], expCushionMem0);
        expectTotalCushionForMember(members[1], expCushionMem1);
        expectTotalCushionForMember(members[2], expCushionMem2);
        expectTotalCushionForMember(members[3], expCushionMem3);

        doBite(members[1], pool, cdp, 9 ether, false);
        // no change in cushionInfo, as member[1] bite partially 
        expectCushionInfoAllMembers(cdp, members, false, false, true);
        expCushionMem1 = expCushionMem1 - (uint(5 ether) * uint(9 ether) / uint(104 ether)) - 1;
        expectTotalCushionForMember(members[0], expCushionMem0);
        expectTotalCushionForMember(members[1], expCushionMem1);
        expectTotalCushionForMember(members[2], expCushionMem2);
        expectTotalCushionForMember(members[3], expCushionMem3);

        doBite(members[0], pool, cdp, 10 ether, false);
        // no change in cushionInfo, as member[0] bite partially 
        expectCushionInfoAllMembers(cdp, members, false, false, true);
        expCushionMem0 = expCushionMem0 - (uint(5 ether) * uint(10 ether) / uint(104 ether)) - 1;
        expectTotalCushionForMember(members[0], expCushionMem0);
        expectTotalCushionForMember(members[1], expCushionMem1);
        expectTotalCushionForMember(members[2], expCushionMem2);
        expectTotalCushionForMember(members[3], expCushionMem3);

        doBite(members[0], pool, cdp, 3 ether, false);
        // change in cushionInfo, as members[0] bite full
        expectCushionInfo(cdp, address(members[0]), 4, false, false, false);
        // but no change in members - 1,2,3
        expectCushionInfo(cdp, address(members[1]), 4, false, false, true);
        expectCushionInfo(cdp, address(members[2]), 4, false, false, true);
        expectCushionInfo(cdp, address(members[3]), 4, false, false, true);
        expCushionMem0 = expCushionMem0 - (uint(5 ether) * uint(3 ether) / uint(104 ether));
        expectTotalCushionForMember(members[0], expCushionMem0);
        expectTotalCushionForMember(members[1], expCushionMem1);
        expectTotalCushionForMember(members[2], expCushionMem2);
        expectTotalCushionForMember(members[3], expCushionMem3);

        assertTrue(LiquidationMachine(manager).bitten(cdp));

        // fast forward until no longer bitten
        forwardTime(60*60 + 1);
        assertTrue(! LiquidationMachine(manager).bitten(cdp));

        // do dummy operation to untop
        manager.frob(cdp, 0, 0);

        // member[0] bitten full
        expectCushionInfo(cdp, address(members[0]), 4, false, false, false);
        // rest members bitten partially
        expectCushionInfo(cdp, address(members[1]), 4, false, true, true);
        expectCushionInfo(cdp, address(members[2]), 4, false, true, true);
        expectCushionInfo(cdp, address(members[3]), 4, false, true, true);

        members[3].doUntop(pool, cdp);

        expectTotalCushionForMembers(members, 0);

        // after untop
        expectCushionInfoAllMembers(cdp, members, false, false, false);

        // check balances
        // 0 consumed 26 ether
        assertEq(radToWei(pool.rad(address(members[0]))), radToWei((1000 ether - 26 ether) * RAY - 1));
        // 1 consumed 24 ether
        assertEq(radToWei(pool.rad(address(members[1]))), radToWei((950 ether - 24 ether) * RAY - 1));
        // 2 consumed 17 ether
        assertEq(radToWei(pool.rad(address(members[2]))), radToWei((900 ether - 17 ether) * RAY - 1));
        // 3 consumed 0 ether
        assertEq(radToWei(pool.rad(address(members[3]))), radToWei((850 ether - 0 ether) * RAY - 1));

        // check that cdp was reset
        (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
        assertEq(cdpArt, 0);
        assertEq(cdpCushion, 0);
        assertEq(winners.length, 0);
        assertEq(bite.length, 0);
    }

    function testBiteInPartsThenUserRepayViaVat() public {
        timeReset();

        members[0].doDeposit(pool, 1000 ether * RAY);
        members[1].doDeposit(pool, 950 ether * RAY);
        members[2].doDeposit(pool, 900 ether * RAY);
        members[3].doDeposit(pool, 850 ether * RAY);

        uint cdp = openCdp(1 ether, 101 ether); // 1 eth, 100 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 149 DAI

        members[3].doTopup(pool, cdp);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        pipETH.poke(bytes32(uint(130 * 1e18)));

        uint cushion = 1 ether + 1 ether; // additional ether for safty
        assertEq(LiquidationMachine(manager).cushion(cdp), cushion);

        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(935, 1000); // 6.5% goes to jar

        doBite(members[0], pool, cdp, 10 ether, false);

        cushion = uint(2 ether) * 91 / 101 + 1;
        assertEq(LiquidationMachine(manager).cushion(cdp), cushion);

        address urn = LiquidationMachine(manager).urns(cdp);
        (, uint art) = vat.urns("ETH", urn);

        LiquidationMachine(manager).move(cdp,address(this),101 ether * RAY);

        vat.frob("ETH",urn,urn,address(this),0,-int(art));

        assertEq(pool.availBite(cdp,address(members[1])), cushion);

        doBite(members[1], pool, cdp, cushion, false);

        assertTrue(LiquidationMachine(manager).bitten(cdp));

        // fast forward until no longer bitten
        forwardTime(60*60 + 1);
        assertTrue(! LiquidationMachine(manager).bitten(cdp));

        assertEq(LiquidationMachine(manager).cushion(cdp), 0);
        members[3].doUntop(pool, cdp);

        // check balances
        // 0 consumed 10 ether
        assertEq(radToWei(pool.rad(address(members[0]))), radToWei((1000 ether - 10 ether) * RAY - 1));
        // 1 consumed 1.8... ether
        assertEq(radToWei(pool.rad(address(members[1]))), radToWei((950 ether - cushion) * RAY - 1));
        // 2 consumed 0 ether
        assertEq(radToWei(pool.rad(address(members[2]))), radToWei((900 ether - 0 ether) * RAY - 1));
        // 3 consumed 0 ether
        assertEq(radToWei(pool.rad(address(members[3]))), radToWei((850 ether - 0 ether) * RAY - 1));

        uint balanceSum = pool.rad(address(members[0])) + pool.rad(address(members[1]))
              + pool.rad(address(members[2])) + pool.rad(address(members[3]));

        assertEq(radToWei(balanceSum) + 1, radToWei(vat.dai(address(pool))));

        // check that cdp was reset
        (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
        assertEq(cdpArt, 0);
        assertEq(cdpCushion, 0);
        assertEq(winners.length, 0);
        assertEq(bite.length, 0);
    }

    function testFailedBiteTooMuch() public {
        members[0].doDeposit(pool, 1000 ether * RAY);
        members[1].doDeposit(pool, 950 ether * RAY);
        members[2].doDeposit(pool, 900 ether * RAY);
        members[3].doDeposit(pool, 850 ether * RAY);

        uint cdp = openCdp(1 ether, 104 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(935, 1000); // 6.5% goes to jar

        members[0].doTopup(pool, cdp);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        pipETH.poke(bytes32(uint(130 * 1e18)));

        members[0].doBite(pool, cdp, 15 ether, 1);
        members[0].doBite(pool, cdp, 11 ether + 1, 1);
    }

    function testFailedBiteInvalidMember() public {
        members[0].doDeposit(pool, 1000 ether * RAY);
        members[1].doDeposit(pool, 950 ether * RAY);
        members[2].doDeposit(pool, 900 ether * RAY);
        members[3].doDeposit(pool, 0 ether * RAY);

        uint cdp = openCdp(1 ether, 104 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(935, 1000); // 6.5% goes to jar

        members[0].doTopup(pool, cdp);

        members[3].doDeposit(pool, 850 ether * RAY);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        pipETH.poke(bytes32(uint(130 * 1e18)));

        members[3].doBite(pool, cdp, 15 ether, 1);
    }

    function testFailedBiteLowDink() public {
        members[0].doDeposit(pool, 1000 ether * RAY);
        members[1].doDeposit(pool, 950 ether * RAY);
        members[2].doDeposit(pool, 900 ether * RAY);

        uint cdp = openCdp(1 ether, 104 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(935, 1000); // 6.5% goes to jar

        members[0].doTopup(pool, cdp);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        pipETH.poke(bytes32(uint(130 * 1e18)));

        members[0].doBite(pool, cdp, 15 ether, 1 ether);
    }

    function testBiteInPartsThenUntopNonOneRate() public {
        timeReset();

        members[0].doDeposit(pool, 1000 ether * RAY);
        members[1].doDeposit(pool, 950 ether * RAY);
        members[2].doDeposit(pool, 900 ether * RAY);
        members[3].doDeposit(pool, 850 ether * RAY);

        uint cdp = openCdp(1 ether, 104 ether); // 1 eth, 110 dai

        setRateTo1p1(); // debt is 10% up

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI
        osm.setH(60 * 60);
        osm.setZ(currTime - 31 minutes);

        (,,,uint timeTillBite) = info.getBiteInfoFlat(cdp, address(members[3]));
        assertEq(timeTillBite, 29 * 60);

        members[3].doTopup(pool, cdp);

        (,,,timeTillBite) = info.getBiteInfoFlat(cdp, address(members[3]));
        assertEq(timeTillBite, 29 * 60);

        forwardTime(30 minutes);

        (,,,timeTillBite) = info.getBiteInfoFlat(cdp, address(members[3]));
        assertEq(timeTillBite, 0);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        pipETH.poke(bytes32(uint(149 * 1e18)));

        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(935, 1000); // 6.5% goes to jar

        jug.drip("ETH");
        (, uint currentRate,,,) = vat.ilks("ETH");

        doBite(members[1], pool, cdp, 15 ether, true);
        doBite(members[0], pool, cdp, 13 ether, true);
        doBite(members[2], pool, cdp, 17 ether, true);
        doBite(members[1], pool, cdp, 9 ether, true);
        doBite(members[0], pool, cdp, 10 ether, true);
        doBite(members[0], pool, cdp, 3 ether, true);

        assertTrue(LiquidationMachine(manager).bitten(cdp));

        // fast forward until no longer bitten
        forwardTime(60*60 + 1);
        assertTrue(! LiquidationMachine(manager).bitten(cdp));

        // do dummy operation to untop
        manager.frob(cdp, 0, 0);

        members[3].doUntop(pool, cdp);

        // check balances
        // 0 consumed 26 ether
        assertEq(radToWei(pool.rad(address(members[0]))), 1000 ether - 26 ether * currentRate / RAY - 1); //radToWei((1000 ether - 26 ether * 11/10) * RAY - 1)-1);
        // 1 consumed 24 ether
        assertEq(radToWei(pool.rad(address(members[1]))), 950 ether - 24 ether * currentRate / RAY - 1);
        // 2 consumed 17 ether
        assertEq(radToWei(pool.rad(address(members[2]))), 900 ether - 17 ether * currentRate / RAY -1);
        // 3 consumed 0 ether
        assertEq(radToWei(pool.rad(address(members[3]))), 850 ether - 1);

        // check that cdp was reset
        (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
        assertEq(cdpArt, 0);
        assertEq(cdpCushion, 0);
        assertEq(winners.length, 0);
        assertEq(bite.length, 0);
    }

    function testFullBiteWithRate() public {
        members[0].doDeposit(pool, 1000 ether * RAY);
        members[1].doDeposit(pool, 950 ether * RAY);
        members[2].doDeposit(pool, 900 ether * RAY);
        members[3].doDeposit(pool, 850 ether * RAY);

        uint cdp = openCdp(1 ether, 104 ether); // 1 eth, 104 dai

        setRateTo1p1(); // debt is 10% up per hour

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI
        osm.setH(60 * 60);
        osm.setZ(currTime - 31 minutes);
        
        expectTotalCushionForMembers(members, 0);

        members[0].doTopup(pool, cdp);

        (uint topupArt, uint cushion, , ) = pool.getCdpData(cdp);
        expectTotalCushionForMembers(members, (topupArt / 4) * cushion / topupArt / RAY);

        forwardTime(31 minutes);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        pipETH.poke(bytes32(uint(140 * 1e18)));
        jug.drip("ETH");
        (, uint currRate,,,) = vat.ilks("ETH");

        // uint ethBefore = vat.gem("ETH", address(members[0]));
        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(98, 100); // 2% goes to jar

        // for 26 ether we expect 26/140 * rate * 1.1 = 28.6/140 * rate, from which 98% goes to member
        uint _100Percent = 286 ether * currRate / (1400 * RAY);
        uint expectedEth = _100Percent * uint(98) / 100;
        assertTrue(_100Percent >= expectedEth);
        uint expectedInJar = _100Percent - expectedEth;

        for(uint i = 0 ; i < 4 ; i++) {
            {
                (uint availableBiteInArt, uint availableBiteInDaiWei, bool canCallBiteNow,) = info.getBiteInfoFlat(cdp, address(members[i]));
                assertEq(availableBiteInArt, 26 ether);
                assertEq(availableBiteInDaiWei, 26 ether * currRate / RAY);
                assertTrue(canCallBiteNow);
                uint memberEstimatedInk = info.getExpectedEthReturn("ETH", availableBiteInDaiWei, 140e18);
                assertEq(expectedEth, memberEstimatedInk);

                if(i > 0) {
                    (availableBiteInArt, availableBiteInDaiWei, canCallBiteNow,) = info.getBiteInfoFlat(cdp, address(members[i - 1]));
                    assertEq(availableBiteInArt, 0);
                    assertEq(availableBiteInDaiWei, 0);
                }
            }

            assertTrue(! canKeepersBite(cdp));
            uint dink = members[i].doPoolBite(pool, cdp, 26 ether, expectedEth);
            assertTrue(! canKeepersBite(cdp));
            assertEq(uint(dink), expectedEth);
            assertEq(vat.gem("ETH", address(members[i])), expectedEth);
            (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
            cdpArt;//shh
            cdpCushion;//shh
            winners;//shh
            assertEq(bite[i], 26 ether);
            assertAlmostEq(pool.rad(address(members[i]))/RAY, 1000 ether - 50 ether * i - (26 ether * currRate)/RAY);
            expectTotalCushionForMember(members[i], 0);
        }

        expectTotalCushionForMembers(members, 0);

        // jar should get 2%
        assertEq(vat.gem("ETH", address(jar)), expectedInJar * 4);
    }

    function testAvailBiteWithDust() public {
        timeReset();

        members[0].doDeposit(pool, 1000 ether * RAY);
        members[1].doDeposit(pool, 950 ether * RAY);
        members[2].doDeposit(pool, 900 ether * RAY);
        members[3].doDeposit(pool, 850 ether * RAY);

        uint oddAmt = 111111111111111111; // 0.11 DAI
        uint daiAmt = 104 ether + oddAmt; // 104.11 dai
        uint cdp = openCdp(1 ether, daiAmt); // 1 eth

        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        expectTotalCushionForMembers(members, 0);

        members[3].doTopup(pool, cdp);

        uint expectedAvailBite = daiAmt / members.length;
        uint expectedDust = daiAmt % members.length;
        assertEq(pool.availBite(cdp, address(members[0])), expectedAvailBite + expectedDust);
        assertEq(pool.availBite(cdp, address(members[1])), expectedAvailBite);
        assertEq(pool.availBite(cdp, address(members[2])), expectedAvailBite);
        assertEq(pool.availBite(cdp, address(members[3])), expectedAvailBite);

        expectTotalCushionForMember(members[0], (5 ether + oddAmt) / 4); // we don't expect dust (rounding err) in cushionTotal
        expectTotalCushionForMember(members[1], (5 ether + oddAmt) / 4);
        expectTotalCushionForMember(members[2], (5 ether + oddAmt) / 4);
        expectTotalCushionForMember(members[3], (5 ether + oddAmt) / 4);

        assertEq(members.length * expectedAvailBite + expectedDust, daiAmt);
    }

    function testAvailBiteWithoutDust() public {
        timeReset();

        members[0].doDeposit(pool, 1000 ether * RAY);
        members[1].doDeposit(pool, 950 ether * RAY);
        members[2].doDeposit(pool, 900 ether * RAY);
        members[3].doDeposit(pool, 850 ether * RAY);

        uint daiAmt = 104 ether;
        uint cdp = openCdp(1 ether, daiAmt); // 1 eth, 104 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        expectTotalCushionForMembers(members, 0);

        members[3].doTopup(pool, cdp);

        uint expectedAvailBite = daiAmt / members.length;
        uint expectedDust = daiAmt % members.length;
        assertEq(expectedDust, 0);

        assertEq(pool.availBite(cdp, address(members[0])), expectedAvailBite);
        assertEq(pool.availBite(cdp, address(members[1])), expectedAvailBite);
        assertEq(pool.availBite(cdp, address(members[2])), expectedAvailBite);
        assertEq(pool.availBite(cdp, address(members[3])), expectedAvailBite);

        expectTotalCushionForMember(members[0], 5 ether / 4);
        expectTotalCushionForMember(members[1], 5 ether / 4);
        expectTotalCushionForMember(members[2], 5 ether / 4);
        expectTotalCushionForMember(members[3], 5 ether / 4);

        assertEq(members.length * expectedAvailBite, daiAmt);
    }


    function testFullBiteWithRateAndDust() public {
        members[0].doDeposit(pool, 1000 ether * RAY);
        members[1].doDeposit(pool, 950 ether * RAY);
        members[2].doDeposit(pool, 900 ether * RAY);
        members[3].doDeposit(pool, 850 ether * RAY);

        uint extraDust = 111111111111111111;
        uint _1p1 = WAD + WAD/10;
        uint daiAmt = 104 ether + extraDust; // 104.11 dai
        uint cdp = openCdp(1 ether, daiAmt); // 1 eth

        setRateTo1p1(); // debt is 10% up per hour

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI
        osm.setH(60 * 60);
        osm.setZ(currTime - 31 minutes);

        members[0].doTopup(pool, cdp);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        pipETH.poke(bytes32(uint(140 * 1e18)));
        jug.drip("ETH");

        // uint ethBefore = vat.gem("ETH", address(members[0]));
        this.file(address(cat), "ETH", "chop", _1p1);
        pool.setProfitParams(98, 100); // 2% goes to jar

        uint expectedAvailBite = daiAmt / members.length;
        uint expectedDust = daiAmt % members.length;
        assertEq(expectedDust, 3);

        assertEq(pool.availBite(cdp, address(members[0])), expectedAvailBite + expectedDust);
        assertEq(pool.availBite(cdp, address(members[1])), expectedAvailBite);
        assertEq(pool.availBite(cdp, address(members[2])), expectedAvailBite);
        assertEq(pool.availBite(cdp, address(members[3])), expectedAvailBite);

        uint amt = daiAmt / members.length;

        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(98, 100); // 2% goes to jar

        // for 26 ether we expect 26/140 * rate * 1.1 = 28.6/140 * rate, from which 98% goes to member
        jug.drip("ETH");
        (, uint currRate,,,) = vat.ilks("ETH");
        uint _100Percent = amt * 11 * currRate / (1400 * RAY);
        uint expectedEth = _100Percent * uint(98) / 100;
        uint expectedEthInJar = _100Percent - expectedEth;

        assertTrue(! canKeepersBite(cdp));
        members[0].doPoolBite(pool, cdp, amt + expectedDust, expectedEth);
        assertTrue(! canKeepersBite(cdp));
        members[1].doPoolBite(pool, cdp, amt, expectedEth);
        assertTrue(! canKeepersBite(cdp));
        members[2].doPoolBite(pool, cdp, amt, expectedEth);
        assertTrue(! canKeepersBite(cdp));
        members[3].doPoolBite(pool, cdp, amt, expectedEth);
        assertTrue(! canKeepersBite(cdp));

        assertEq(pool.availBite(cdp, address(members[0])), 0);
        assertEq(pool.availBite(cdp, address(members[1])), 0);
        assertEq(pool.availBite(cdp, address(members[2])), 0);
        assertEq(pool.availBite(cdp, address(members[3])), 0);

        // jar should get 2%
        assertEq(vat.gem("ETH", address(jar)), expectedEthInJar * 4);
    }

    function testCalcCushionHigherSpot() public {
        (uint dart, uint dtab) = pool.calcCushion("ETH", 1 ether, 10000000 ether, 1000 ether);
        assertEq(dart, 0);
        assertEq(dtab, 0);
    }

    function testCalcCushionLAttack() public {
        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        (,, uint currSpot,,) = vat.ilks("ETH");
        (uint dart, uint dtab) = pool.calcCushion("ETH", 1 ether, 10000000 ether, currSpot / 2);
        assertEq(dart, 0);
        assertEq(dtab, 0);
    }

    function testCalcNoCushion() public {
        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        (,, uint currSpot,,) = vat.ilks("ETH");
        (uint dart, uint dtab) = pool.calcCushion("ETH", 1 ether, 10 ether, currSpot / 2);
        assertEq(dart, 0);
        assertEq(dtab, 0);
    }

    function testCalcCushion() public {
        pipETH.poke(bytes32(uint(300 * 1e18)));
        spotter.poke("ETH");
        (,, uint currSpot,,) = vat.ilks("ETH");

        jug.drip("ETH");
        this.file(address(jug), "ETH", "duty", RAY * 10000264755 / 10000000000);

        forwardTime(1);
        jug.drip("ETH");

        osm.setH(30 * 60); // half an hour
        osm.setZ(currTime - 1);
        (uint dart, uint dtab) = pool.calcCushion("ETH", 1 ether, 100 ether, currSpot / 2); // spot is 150

        forwardTime(60 * 60 - 1);
        jug.drip("ETH");

        (,uint currRate,,,) = vat.ilks("ETH");

        // make sure cushion is enough
        assertTrue((100 ether - dart) * currRate * 15 / 10 < 1 ether * 150 ether * 1e9);

        // make sure cushion is precise
        assertEq(1 + radToWei((100 ether - dart + 1 ether) * currRate * 15 / 10), radToWei(1 ether * 150 ether * 1e9));

        assertEq(radToWei(dtab), dart * 10000264755 / 10000000000);
    }

    function setX(uint val) external pure returns(bytes memory) {
        val; // shhhh
        return msg.data;
    }

    function testEmergencyExecute() public {
        bytes memory data = this.setX(123);
        Dummy d = new Dummy();

        pool.emergencyExecute(address(d), data);

        assertEq(d.x(), 123);
    }

    function testFailedEmergencyExecuteNonAdmin() public {
        bytes memory data = this.setX(123);
        Dummy d = new Dummy();

        pool.setOwner(address(0x123));

        pool.emergencyExecute(address(d), data);
    }

    function testSetDaiToUsdPriceFeed() public {
        address oldPriceFeed = address(pool.dai2usd());

        FakeDaiToUsdPriceFeed dai2usdPriceFeed = new FakeDaiToUsdPriceFeed();
        pool.setDaiToUsdPriceFeed(address(dai2usdPriceFeed));

        address newPriceFeed = address(pool.dai2usd());
        assertTrue(oldPriceFeed != address(0));
        assertTrue(oldPriceFeed != newPriceFeed);
        assertTrue(address(dai2usdPriceFeed) == newPriceFeed);
    }

    function testDaiToUsdSetPrice() public {
        address priceFeedAddr = address(pool.dai2usd());

        FakeDaiToUsdPriceFeed dai2usdPriceFeed = FakeDaiToUsdPriceFeed(priceFeedAddr);
        assertEq(dai2usdPriceFeed.getMarketPrice(3), 1 ether);

        dai2usdPriceFeed.setPrice(2 ether);

        assertEq(dai2usdPriceFeed.getMarketPrice(3), 2 ether);
    }

    function testDaiToUsdMarketPrice() public {
        address priceFeedAddr = address(pool.dai2usd());
        FakeDaiToUsdPriceFeed dai2usdPriceFeed = FakeDaiToUsdPriceFeed(priceFeedAddr);
        assertEq(dai2usdPriceFeed.getMarketPrice(3), 1 ether);
    }

    function testFailDaiToUsdMarketPriceInvalidMarketId() public view {
        address priceFeedAddr = address(pool.dai2usd());
        FakeDaiToUsdPriceFeed dai2usdPriceFeed = FakeDaiToUsdPriceFeed(priceFeedAddr);
        // must revert
        dai2usdPriceFeed.getMarketPrice(2);
    }

    // 1 DAI = 1.03 USD
    function testHighDaiRateInUsd() public {
        members[0].doDeposit(pool, 1000 ether * RAY);
        members[1].doDeposit(pool, 950 ether * RAY);
        members[2].doDeposit(pool, 900 ether * RAY);
        members[3].doDeposit(pool, 850 ether * RAY);

        uint cdp = openCdp(1 ether, 104 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        members[0].doTopup(pool, cdp);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        pipETH.poke(bytes32(uint(130 * 1e18)));

        // Update DAI to USD rate
        FakeDaiToUsdPriceFeed dai2usd = FakeDaiToUsdPriceFeed(address(pool.dai2usd()));
        dai2usd.setPrice(1.03 * 1e18); // 1 DAI = 1.03 USD

        //uint ethBefore = vat.gem("ETH", address(members[0]));
        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(93, 100); // 7% goes to jar
        // for 26 ether we expect 26/130 * 1.1 = 28.6/130, from which 93% goes to member
        uint _100Percent = 286 ether / (130 * 10);
        // _100Percent * 93% * 1.03
        uint expectedEth = _100Percent * uint(93) * 103 / (100 * 100);
        uint expectedInJar = _100Percent - expectedEth;

        for(uint i = 0 ; i < 4 ; i++) {
            assertTrue(! canKeepersBite(cdp));
            uint dink = members[i].doPoolBite(pool, cdp, 26 ether, expectedEth);
            assertTrue(! canKeepersBite(cdp));
            assertEq(uint(dink), expectedEth);
            assertEq(vat.gem("ETH", address(members[i])), expectedEth);
            (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
            cdpArt; //shh
            cdpCushion; //shh
            winners; //shh
            assertEq(bite[i], 26 ether);
            assertEq(pool.rad(address(members[i])), (1000 ether - 50 ether * i - 26 ether) * RAY - 1);
        }

        // jar should get 2% from 104 * 1.1 / 130
        assertEq(vat.gem("ETH", address(jar)), expectedInJar * 4);
    }

    // 1 DAI = 0.97 USD
    function testLowDaiRateInUsd() public {
        members[0].doDeposit(pool, 1000 ether * RAY);
        members[1].doDeposit(pool, 950 ether * RAY);
        members[2].doDeposit(pool, 900 ether * RAY);
        members[3].doDeposit(pool, 850 ether * RAY);

        uint cdp = openCdp(1 ether, 104 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        members[0].doTopup(pool, cdp);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        pipETH.poke(bytes32(uint(130 * 1e18)));

        // Update DAI to USD rate
        FakeDaiToUsdPriceFeed dai2usd = FakeDaiToUsdPriceFeed(address(pool.dai2usd()));
        dai2usd.setPrice(0.97 * 1e18); // 1 DAI = 0.97 USD

        //uint ethBefore = vat.gem("ETH", address(members[0]));
        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(93, 100); // 7% goes to jar
        // for 26 ether we expect 26/130 * 1.1 = 28.6/130, from which 93% goes to member
        uint _100Percent = 286 ether / (130 * 10);
        // _100Percent * 93% * 0.97
        uint expectedEth = _100Percent * uint(93) * 97 / (100 * 100);
        uint expectedInJar = _100Percent - expectedEth;

        for(uint i = 0 ; i < 4 ; i++) {
            assertTrue(! canKeepersBite(cdp));
            uint dink = members[i].doPoolBite(pool, cdp, 26 ether, expectedEth);
            assertTrue(! canKeepersBite(cdp));
            assertEq(uint(dink), expectedEth);
            assertEq(vat.gem("ETH", address(members[i])), expectedEth);
            (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
            cdpArt; //shh
            cdpCushion; //shh
            winners; //shh
            assertEq(bite[i], 26 ether);
            assertEq(pool.rad(address(members[i])), (1000 ether - 50 ether * i - 26 ether) * RAY - 1);
        }

        // jar should get 2% from 104 * 1.1 / 130
        assertEq(vat.gem("ETH", address(jar)), expectedInJar * 4);
    }

    // 1 DAI = 1.15 USD
    function testVeryHighDaiRateInUsd() public {
        members[0].doDeposit(pool, 1000 ether * RAY);
        members[1].doDeposit(pool, 950 ether * RAY);
        members[2].doDeposit(pool, 900 ether * RAY);
        members[3].doDeposit(pool, 850 ether * RAY);

        uint cdp = openCdp(1 ether, 104 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        members[0].doTopup(pool, cdp);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        pipETH.poke(bytes32(uint(130 * 1e18)));

        // Update DAI to USD rate
        FakeDaiToUsdPriceFeed dai2usd = FakeDaiToUsdPriceFeed(address(pool.dai2usd()));
        dai2usd.setPrice(1.15 * 1e18); // 1 DAI = 1.15 USD

        //uint ethBefore = vat.gem("ETH", address(members[0]));
        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(93, 100); // 7% goes to jar
        // for 26 ether we expect 26/130 * 1.1 = 28.6/130, from which 93% goes to member
        uint _100Percent = 286 ether / (130 * 10);
        // _100Percent * 93% * 1.15
        uint expectedEth = _100Percent * uint(93) * 115 / (100 * 100);

        assertTrue(_100Percent < expectedEth);
        expectedEth = (expectedEth > _100Percent) ? _100Percent : expectedEth;
        uint expectedInJar = 0;

        for(uint i = 0 ; i < 4 ; i++) {
            assertTrue(! canKeepersBite(cdp));
            uint dink = members[i].doPoolBite(pool, cdp, 26 ether, expectedEth);
            assertTrue(! canKeepersBite(cdp));
            assertEq(uint(dink), expectedEth);
            assertEq(vat.gem("ETH", address(members[i])), expectedEth);
            (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
            cdpArt; //shh
            cdpCushion; //shh
            winners; //shh
            assertEq(bite[i], 26 ether);
            assertEq(pool.rad(address(members[i])), (1000 ether - 50 ether * i - 26 ether) * RAY - 1);
        }

        // jar should get 2% from 104 * 1.1 / 130
        assertEq(vat.gem("ETH", address(jar)), expectedInJar);
    }

    // 1 DAI = 0.8 USD
    function testVeryLowDaiRateInUsd() public {
        members[0].doDeposit(pool, 1000 ether * RAY);
        members[1].doDeposit(pool, 950 ether * RAY);
        members[2].doDeposit(pool, 900 ether * RAY);
        members[3].doDeposit(pool, 850 ether * RAY);

        uint cdp = openCdp(1 ether, 104 ether); // 1 eth, 110 dai

        // set next price to 150, which means a cushion of 10 dai is expected
        osm.setPrice(150 * 1e18); // 1 ETH = 150 DAI

        members[0].doTopup(pool, cdp);

        pipETH.poke(bytes32(uint(150 * 1e18)));
        spotter.poke("ETH");
        pipETH.poke(bytes32(uint(130 * 1e18)));

        // Update DAI to USD rate
        FakeDaiToUsdPriceFeed dai2usd = FakeDaiToUsdPriceFeed(address(pool.dai2usd()));
        dai2usd.setPrice(0.8 * 1e18); // 1 DAI = 0.8 USD

        //uint ethBefore = vat.gem("ETH", address(members[0]));
        this.file(address(cat), "ETH", "chop", WAD + WAD/10);
        pool.setProfitParams(93, 100); // 7% goes to jar
        // for 26 ether we expect 26/130 * 1.1 = 28.6/130, from which 93% goes to member
        uint _100Percent = 286 ether / (130 * 10);
        // _100Percent * 93% * 0.8
        uint expectedEth = _100Percent * uint(93) * 8 / (100 * 10);
        assertTrue(_100Percent > expectedEth);
        uint expectedInJar = _100Percent - expectedEth;

        for(uint i = 0 ; i < 4 ; i++) {
            assertTrue(! canKeepersBite(cdp));
            uint dink = members[i].doPoolBite(pool, cdp, 26 ether, expectedEth);
            assertTrue(! canKeepersBite(cdp));
            assertEq(uint(dink), expectedEth);
            assertEq(vat.gem("ETH", address(members[i])), expectedEth);
            (uint cdpArt, uint cdpCushion, address[] memory winners, uint[] memory bite) = pool.getCdpData(cdp);
            cdpArt; //shh
            cdpCushion; //shh
            winners; //shh
            assertEq(bite[i], 26 ether);
            assertEq(pool.rad(address(members[i])), (1000 ether - 50 ether * i - 26 ether) * RAY - 1);
        }

        // jar should get 2% from 104 * 1.1 / 130
        assertEq(vat.gem("ETH", address(jar)), expectedInJar * 4);
    }

    function testTopupAndRepay() public {
        uint cdp = testHappyTopup();

        (,,, ,,, bool canCallTopupNow, bool shouldCallUntop,, bool isToppedUp) 
            = info.getCushionInfoFlat(cdp,address(members[0]), 4);
        assertTrue(! canCallTopupNow);
        assertTrue(! shouldCallUntop);
        assertTrue(isToppedUp);

        // repay 50 DAI debt
        manager.frob(cdp, 0, -50 ether);

        (,,, ,,, canCallTopupNow, shouldCallUntop,, isToppedUp) 
            = info.getCushionInfoFlat(cdp,address(members[0]), 4);
        
        assertTrue(! canCallTopupNow);
        assertTrue(shouldCallUntop);
        assertTrue(isToppedUp);
    }

    // tests to do

    // topup - during bite
    // untop - sad (during bite), untop after partial bite
}

contract Dummy {
    uint public x;

    function setX(uint val) public {
        x = val;
    }
}
