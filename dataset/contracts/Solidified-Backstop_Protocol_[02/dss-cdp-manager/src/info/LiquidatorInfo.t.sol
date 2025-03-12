pragma solidity ^0.5.12;

import { BCdpManagerTestBase, Hevm, FakeUser, FakeDaiToUsdPriceFeed } from "./../BCdpManager.t.sol";
import { BCdpScore } from "./../BCdpScore.sol";
import { Pool } from "./../pool/Pool.sol";
import { Math } from "./../Math.sol";
import { LiquidationMachine } from "./../LiquidationMachine.sol";
import { FlatLiquidatorInfo, LiquidatorBalanceInfo } from "./LiquidatorInfo.sol";


contract FakeDaiToUsdPriceFeedLike {
    function setPrice(uint newPrice) public;
}

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
    function latestAnswer(bytes32 ilk) external pure returns(int) { return 100e18; }
}

contract FakePool {
    mapping(address => uint) public rad;

    function setRad(address usr, uint val) public {
        rad[usr] = val;
    }
}

contract FakeToken {
    mapping(address => uint) public balanceOf;

    function setBalance(address usr, uint val) public {
        balanceOf[usr] = val;
    }
}

contract LiquidatorInfoTest is BCdpManagerTestBase, Math {
    uint currTime;
    FakeMember member;
    FakeMember[] members;
    FakeMember nonMember;
    FlatLiquidatorInfo info;
    address constant JAR = address(0x1234567890);

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

        info = new FlatLiquidatorInfo(LiquidationMachine(address(manager)), address(new FakeOracle()),address(new FakeChainLink()));

        assertEq(address(LiquidationMachine(address(manager)).pool()),address(pool));

        FakeDaiToUsdPriceFeedLike(address(pool.dai2usd())).setPrice(100e16); // 1.00 USD per DAI
        this.file(address(cat), "ETH", "chop", WAD + WAD/10 + 3*WAD/100); // 13%
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

        pool.setProfitParams(965,1000); // 96.5
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

    function testNumMembers() public {
        uint numMembers = info.getNumMembers();
        assertEq(numMembers, 4);
    }

    function testGetExpectedEthReturn() public {
        uint currentPrice = 12345e16; // 123.45 usd per ether
        pool.setProfitParams(965,1000); // 96.5
        this.file(address(cat), "ETH", "chop", WAD + WAD/10 + 3*WAD/100); // 13%

        FakeDaiToUsdPriceFeedLike(address(pool.dai2usd())).setPrice(100e16); // 1.00 USD per DAI
        uint returnValue = info.getExpectedEthReturn("ETH", 100 ether, currentPrice);
        // for 100 dai debt, 113 is bitten. this is 0.9153503442689348 ETH
        // 96.5% of it goes to liquidator = 0.8833130822195221 ETH = 8833130822195221e2 wei
        assertEq(returnValue / uint(1000), uint(8833130822195221e2) / 1000); // give up some precision

        FakeDaiToUsdPriceFeedLike(address(pool.dai2usd())).setPrice(101e16); // 1.01 USD per DAI
        returnValue = info.getExpectedEthReturn("ETH", 100 ether, currentPrice);
        // for 100 dai debt, 113 is bitten. this is 0.9153503442689348 ETH
        // 96.5% of it goes to liquidator = 0.8921462130417174 ETH = 8921462130417174e2 wei
        // liquidator get 1% extra, because of dai/usd price =
        assertEq(returnValue / uint(1000), uint(8921462130417174e2) / 1000); // give up some precision
    }

    function testVaultInfo() public {
        uint cdp = openCdp(1 ether, 50 ether);
        (bytes32 collateralType, uint collateralInWei, uint debtInDaiWei, uint liquidationPrice, uint ethReturn,) = info.getVaultInfoFlat(cdp);

        assertEq(collateralType, bytes32("ETH"));
        assertEq(collateralInWei, 1 ether);
        assertEq(debtInDaiWei, 50 ether);
        assertEq(liquidationPrice, 75 ether);
        assertTrue(ethReturn > 0);

        setRateTo1p1();
        forwardTime(100 minutes);
        (, uint rate,,,) = vat.ilks("ETH");
        uint newDaiDebt = rate * 50 ether / 1e27;

        assertTrue(newDaiDebt > 50 ether);

        (collateralType, collateralInWei, debtInDaiWei, liquidationPrice, ethReturn,) = info.getVaultInfoFlat(cdp);
        assertEq(collateralType, bytes32("ETH"));
        assertEq(collateralInWei, 1 ether);
        assertEq(debtInDaiWei, newDaiDebt);
        assertEq(liquidationPrice, newDaiDebt * 15 / 10);
        assertTrue(ethReturn > 0);
    }

    function testVaultInfoForEmptyCdp() public {
        uint cdp = openCdp(0, 0);
        (bytes32 collateralType, uint collateralInWei, uint debtInDaiWei, uint liquidationPrice, uint ethReturn, bool betterThanChainlink) = info.getVaultInfoFlat(cdp);

        assertEq(collateralType, bytes32("ETH"));
        assertEq(collateralInWei, 0);
        assertEq(debtInDaiWei, 0);
        assertEq(liquidationPrice, 0);
        assertEq(ethReturn, 0);
        assertTrue(! betterThanChainlink);

    }

    function testBiteInfoNotInBite() public {
        uint cdp = openCdp(1 ether, 50 ether);
        address firstMember = getMembers()[0];

        timeReset();
        osm.setH(60 * 60);
        osm.setZ(currTime - 24 * 60); // now it is 00:24

        (uint availableBiteInArt, uint availableBiteInDaiWei, bool canCallBiteNow, uint timeTillBite) = info.getBiteInfoFlat(cdp, firstMember);

        assertEq(timeTillBite, 36 * 60);
        assertEq(availableBiteInArt, 0);
        assertEq(availableBiteInDaiWei, 0);
        assertTrue(! canCallBiteNow);
    }

    function testTimeToTopup() public {
        uint cdp = openCdp(1 ether, 50 ether);
        osm.setH(60 * 60);
        osm.setZ(currTime - 24 * 60); // now it is 00:24
        osm.setPrice(60 * 1e18);

        (,,,,,,,,uint timeToTopup,) = info.getCushionInfoFlat(cdp,getMembers()[0], 4);
        assertEq(timeToTopup, 6 * 60);
    }

    function testTopupBiggerThanArt() public {
        uint cdp = openCdp(1 ether, 50 ether);
        osm.setH(60 * 60);
        osm.setZ(currTime - 24 * 60); // now it is 00:24
        osm.setPrice(0 * 1e18);

        (,,,,bool shouldProvideCushion,bool shouldProvideCushionIfAllHaveBalance,bool canCallTopupNow,bool shouldCallUntop,uint timeToTopup,) = info.getCushionInfoFlat(cdp,getMembers()[0], 4);

        assertTrue(! shouldProvideCushion);
        assertTrue(! shouldProvideCushionIfAllHaveBalance);
        assertTrue(! canCallTopupNow);
        assertTrue(! shouldCallUntop);

        assertEq(timeToTopup, 6 * 60);
    }

    function testTopupLeadsToDust() public {
        uint cdp = openCdp(1 ether, 50 ether);
        osm.setH(60 * 60);
        osm.setZ(currTime - 34 * 60); // now it is 00:34
        osm.setPrice(60 * 1e18);

        members[1].doDeposit(Pool(address(info.pool())), 100e45);

        (,,,,bool shouldProvideCushion,bool shouldProvideCushionIfAllHaveBalance,bool canCallTopupNow,bool shouldCallUntop,uint timeToTopup,) = info.getCushionInfoFlat(cdp,getMembers()[1], 4);

        assertTrue(shouldProvideCushion);
        assertTrue(shouldProvideCushionIfAllHaveBalance);
        assertTrue(canCallTopupNow);
        assertTrue(!shouldCallUntop);
        assertEq(timeToTopup, 0 * 60);

        // change dust value
        this.file(address(vat), "ETH", "dust", 200e45);
        (,,,,shouldProvideCushion,shouldProvideCushionIfAllHaveBalance,canCallTopupNow,shouldCallUntop,timeToTopup,) = info.getCushionInfoFlat(cdp,getMembers()[1], 4);

        assertTrue(! shouldProvideCushion);
        assertTrue(! shouldProvideCushionIfAllHaveBalance);
        assertTrue(! canCallTopupNow);
        assertTrue(! shouldCallUntop);
        assertEq(timeToTopup, 0 * 60);
    }

    function testBalanceInfoFlat() public {
        address payable me = address(0x123);
        FakePool fPool = new FakePool();
        FakeToken fDai = new FakeToken();
        FakeToken fWeth = new FakeToken();
        FakeToken fWbtc = new FakeToken();        
        LiquidatorBalanceInfo balanceInfo = new LiquidatorBalanceInfo();

        {
            fPool.setRad(me, 123 * 1e27);
            fDai.setBalance(me, 567);
            fWeth.setBalance(me, 789);
            fWbtc.setBalance(me, 666);

            uint cdp = openCdp(1 ether, 50 ether);
            manager.move(cdp, me, 3e27);
            assertEq(vat.dai(me), 3e27);
            (bool succ,) = me.call.value(7)("");
            assertTrue(succ);

            weth.mint(8);
            weth.approve(address(ethJoin), 8);
            ethJoin.join(me, 8);
        }

        {
            (uint blockNumber, uint[3] memory balances, /* ethBalance, uint wethBalance, uint wbtcBalance,*/ uint daiBalance, uint vatDaiBalanceInWei,
            uint vatEthBalanceInWei, uint poolDaiBalanceInWei) =
            balanceInfo.getBalanceInfoFlat(me, address(fPool), address(vat), "ETH", address(fDai), address(fWeth), address(fWbtc));

            assertEq(blockNumber, block.number);
            assertEq(balances[0], 7);
            assertEq(balances[1], 789);
            assertEq(balances[2], 666e10);            
            assertEq(daiBalance, 567);
            assertEq(vatDaiBalanceInWei, 3);
            assertEq(vatEthBalanceInWei, 8);
            assertEq(poolDaiBalanceInWei, 123);
        }
    }

    function testBalanceInfoCdpi() public {
        LiquidatorBalanceInfo balanceInfo = new LiquidatorBalanceInfo();
        uint expectedCdpi = pool.man().cdpi();
        assertEq(balanceInfo.cdpi(address(pool)), expectedCdpi);

        openCdp(1 ether, 104 ether);
        openCdp(1 ether, 104 ether);

        assertEq(balanceInfo.cdpi(address(pool)), expectedCdpi + 2);
    }
}
