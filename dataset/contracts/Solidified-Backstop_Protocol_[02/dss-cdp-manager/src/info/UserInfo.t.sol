pragma solidity ^0.5.12;
//pragma experimental ABIEncoderV2;

import { Vat, Spotter } from "dss-deploy/DssDeploy.t.base.sol";
import { BCdpManagerTestBase, Hevm, FakeUser, BCdpScoreLike } from "./../BCdpManager.t.sol";
import { BCdpManager } from "./../BCdpManager.sol";
import { DssCdpManager } from "./../DssCdpManager.sol";
import { GetCdps } from "./../GetCdps.sol";
import { UserInfo, UserInfoStorage, VatLike, DSProxyLike, ProxyRegistryLike, SpotLike, JarConnectorLike } from "./UserInfo.sol";
import { Jar } from "./../../user-rating/contracts/jar/Jar.sol";
import { Pool } from "./../pool/Pool.sol";

contract FakeProxy is FakeUser {
    address public owner;
    function setOwner(address newOwner) public {
        owner = newOwner;
    }

    function execute(address _target, bytes memory _data)
        public
        payable
        returns (bytes32 response)
    {
        // call contract in current context
        assembly {
            let succeeded := delegatecall(sub(gas, 5000), _target, add(_data, 0x20), mload(_data), 0, 32)
            response := mload(0)      // load delegatecall output
            switch iszero(succeeded)
            case 1 {
                // throw if delegatecall failed
                revert(0, 0)
            }
        }
    }
}

contract FakeERC20 {
    function balanceOf(address u) public pure returns(uint) {
        return 123;
    }

    function allowance(address guy, address spender) public pure returns(uint) {
        return 456;
    }
}

contract FakeGemJoin {
    FakeERC20 f = new FakeERC20();

    function dec() public pure returns(uint) {
        return 8;
    }

    function gem() public view returns(address) {
        return address(f);
    }
}

contract FakeRegistry {
      mapping(address=>FakeProxy) public proxies;

      function build() public returns(FakeProxy){
          proxies[msg.sender] = new FakeProxy();
          proxies[msg.sender].setOwner(msg.sender);

          return proxies[msg.sender];
      }
}

contract UserInfoTest is BCdpManagerTestBase {
    DssCdpManager dsManager;
    GetCdps       getCdps;
    FakeRegistry  registry;
    UserInfo      userInfo;

    VatLike vatLike;
    ProxyRegistryLike registryLike;
    SpotLike spotterLike;
    address jarConnector;
    Jar jar;

    function setUp() public {

        super.setUp();

        dsManager = new DssCdpManager(address(vat));
        getCdps = new GetCdps();
        registry = new FakeRegistry();
        userInfo = new UserInfo(address(dai), address(weth));
        bytes32[] memory ilks = new bytes32[](1);
        ilks[0] = "ETH";

        address[] memory gemJoins = new address[](1);
        gemJoins[0] = address(ethJoin);

        jarConnector = address(0x1);
        jar = new Jar(uint(1), uint(now + 30 days), address(jarConnector), address(vat), ilks, gemJoins);

        vatLike = VatLike(address(vat));
        registryLike = ProxyRegistryLike(address(registry));
        spotterLike = SpotLike(address(spotter));

    }

    function openCdp(address man, uint ink, uint art) internal returns(uint){
        uint cdp = DssCdpManager(man).open("ETH", address(this));

        weth.mint(ink);
        weth.approve(address(ethJoin), ink);
        ethJoin.join(DssCdpManager(man).urns(cdp), ink);

        DssCdpManager(man).frob(cdp, int(ink), int(art));

        return cdp;
    }

    function timeReset() internal {
        hevm.warp(now);
    }

    function forwardTime(uint deltaInSec) internal {
        hevm.warp(now + deltaInSec);
    }

    function testProxyInfo() public {
        FakeProxy proxy = registry.build();

        dai.approve(address(proxy), 456);

        userInfo.setInfo(address(this), "ETH", manager, dsManager, getCdps, vatLike,
                         spotterLike, registryLike, address(jar), address(ethJoin));
        assertEq(userInfo.hasProxy() ? uint(1) : uint(0), uint(1));
        assertEq(address(userInfo.userProxy()), address(proxy));
        assertTrue(! userInfo.hasCdp());
        assertTrue(! userInfo.makerdaoHasCdp());

        assertEq(address(this).balance, userInfo.ethBalance());
        assertEq(456, userInfo.daiAllowance());

        userInfo.setInfo(address(this), "ETH", manager, dsManager, getCdps, vatLike,
                         spotterLike, registryLike, address(jar), address(new FakeGemJoin()));

        assertEq(123, userInfo.gemBalance());
        assertEq(456, userInfo.gemAllowance());    
    }

    function testDaiBalanceAndDustInfo() public {
        //FakeProxy proxy = registry.build();

        uint cdp = openCdp(address(manager), 1 ether, 100 ether);
        manager.move(cdp, address(this), 50 ether * RAY);
        vat.hope(address(daiJoin));
        daiJoin.exit(address(this), 50 ether);
        assertEq(dai.balanceOf(address(this)), 50 ether);

        this.file(address(vat), "ETH", "dust", 20 ether * RAY);

        userInfo.setInfo(address(this), "ETH", manager, dsManager, getCdps, vatLike,
                         spotterLike, registryLike, address(jar), address(ethJoin));

        assertEq(userInfo.daiBalance(), 50 ether);
        assertEq(userInfo.dustInWei(), 20 ether);
    }

    function testNoProxy() public {
        userInfo.setInfo(address(this), "ETH", manager, dsManager, getCdps, vatLike,
                         spotterLike, registryLike, address(jar), address(ethJoin));
        assertEq(userInfo.hasProxy() ? uint(1) : uint(0), uint(0));
        assertEq(address(userInfo.userProxy()), address(0));
    }

    function testBCdp() public {
        FakeProxy proxy = registry.build();
        uint bCdp = openCdp(address(manager), 1 ether, 20 ether);
        manager.give(bCdp, address(proxy));
        userInfo.setInfo(address(this), "ETH", manager, dsManager, getCdps, vatLike,
                         spotterLike, registryLike, address(jar), address(ethJoin));
        assertEq(userInfo.hasProxy() ? uint(1) : uint(0), uint(1));
        assertEq(address(userInfo.userProxy()), address(proxy));
        assertEq(userInfo.cdp(), bCdp);
        assertTrue(userInfo.hasCdp());
        assertTrue(userInfo.bitten() == false);
        assertEq(userInfo.unlockedEth(), 0);
        assertTrue(! userInfo.expectedDebtMissmatch());
        assertEq(userInfo.ethDeposit(), 1 ether);
        assertEq(userInfo.daiDebt(), 20 ether);
        assertEq(userInfo.maxDaiDebt(), 200 ether); // 150% with spot price of $300
        assertEq(userInfo.spotPrice(), 300e18);
        assertTrue(! userInfo.makerdaoHasCdp());
    }

    function testMakerDaoCdp() public {
        FakeProxy proxy = registry.build();
        uint bCdp = openCdp(address(dsManager), 1 ether, 20 ether);
        dsManager.give(bCdp, address(proxy));
        userInfo.setInfo(address(this), "ETH", manager, dsManager, getCdps, vatLike,
                         spotterLike, registryLike, address(jar), address(ethJoin));
        assertEq(userInfo.hasProxy() ? uint(1) : uint(0), uint(1));
        assertEq(address(userInfo.userProxy()), address(proxy));
        assertEq(userInfo.makerdaoCdp(), bCdp);
        assertTrue(userInfo.makerdaoHasCdp());
        assertEq(userInfo.makerdaoEthDeposit(), 1 ether);
        assertEq(userInfo.makerdaoDaiDebt(), 20 ether);
        assertEq(userInfo.makerdaoMaxDaiDebt(), 200 ether); // 150% with spot price of $300
        assertEq(userInfo.spotPrice(), 300e18);
        assertTrue(! userInfo.hasCdp());
    }

    function testBothHaveCdp() public {
        FakeProxy proxy = registry.build();
        uint bCdp = openCdp(address(manager), 1 ether, 20 ether);
        uint mCdp = openCdp(address(dsManager), 2 ether, 30 ether);
        manager.give(bCdp, address(proxy));
        dsManager.give(mCdp, address(proxy));
        userInfo.setInfo(address(this), "ETH", manager, dsManager, getCdps, vatLike,
                         spotterLike, registryLike, address(jar), address(ethJoin));

        assertEq(userInfo.hasProxy() ? uint(1) : uint(0), uint(1));
        assertEq(address(userInfo.userProxy()), address(proxy));
        assertEq(userInfo.cdp() , bCdp);
        assertTrue(userInfo.hasCdp());
        assertEq(userInfo.ethDeposit(), 1 ether);
        assertEq(userInfo.daiDebt(), 20 ether);
        assertEq(userInfo.maxDaiDebt(), 200 ether); // 150% with spot price of $300
        assertEq(userInfo.spotPrice(), 300e18);

        assertEq(userInfo.makerdaoCdp(), mCdp);
        assertTrue(userInfo.makerdaoHasCdp());
        assertEq(userInfo.makerdaoEthDeposit(), 2 ether);
        assertEq(userInfo.makerdaoDaiDebt(), 30 ether);
        assertEq(userInfo.makerdaoMaxDaiDebt(), 400 ether); // 150% with spot price of $300
        assertEq(userInfo.spotPrice(), 300e18);
    }

    function testBothHaveCdpWithRate() public {
        FakeProxy proxy = registry.build();
        uint bCdp = openCdp(address(manager), 1 ether, 20 ether);
        uint mCdp = openCdp(address(dsManager), 2 ether, 30 ether);

        setRateTo1p1();

        manager.give(bCdp, address(proxy));
        dsManager.give(mCdp, address(proxy));
        userInfo.setInfo(address(this), "ETH", manager, dsManager, getCdps, vatLike,
                         spotterLike, registryLike, address(jar), address(ethJoin));

        assertEq(userInfo.hasProxy() ? uint(1) : uint(0), uint(1));
        assertEq(address(userInfo.userProxy()), address(proxy));
        assertEq(userInfo.cdp(), bCdp);
        assertTrue(userInfo.hasCdp());
        assertEq(userInfo.ethDeposit(), 1 ether);
        assertEq(userInfo.daiDebt(), 22 ether);
        // -1 is a rounding error
        assertEq(userInfo.maxDaiDebt(), 200 ether - 1); // 150% with spot price of $300
        assertEq(userInfo.spotPrice(), 300e18);

        assertEq(userInfo.makerdaoCdp(), mCdp);
        assertTrue(userInfo.makerdaoHasCdp());
        assertEq(userInfo.makerdaoEthDeposit(), 2 ether);
        assertEq(userInfo.makerdaoDaiDebt(), 33 ether);
        // -1 is a rounding error
        assertEq(userInfo.makerdaoMaxDaiDebt(), 400 ether - 1); // 150% with spot price of $300
        assertEq(userInfo.spotPrice(), 300e18);

        assertEq(userInfo.gemDecimals(), 18);        
    }

    function testBothHaveCdpWithGem() public {
        FakeProxy proxy = registry.build();
        uint bCdp = openCdp(address(manager), 1 ether, 20 ether);
        uint mCdp = openCdp(address(dsManager), 2 ether, 30 ether);

        setRateTo1p1();

        manager.give(bCdp, address(proxy));
        dsManager.give(mCdp, address(proxy));
        userInfo.setInfo(address(this), "ETH", manager, dsManager, getCdps, vatLike,
                         spotterLike, registryLike, address(jar), address(new FakeGemJoin()));

        assertTrue(userInfo.hasCdp());
        assertEq(userInfo.ethDeposit(), 1 ether / 10**10);

        assertEq(userInfo.makerdaoCdp(), mCdp);
        assertTrue(userInfo.makerdaoHasCdp());
        assertEq(userInfo.makerdaoEthDeposit(), 2 ether / 10**10);

        assertEq(userInfo.gemDecimals(), 8);        
    }    

    function testBothHaveCdpWithRateAndDifferentPrice() public {
        FakeProxy proxy = registry.build();

        for(uint i = 0 ; i < 10 ; i++) {
            uint cdp1 = dsManager.open("ETH-B", address(this));
            uint cdp2 = manager.open("ETH-B", address(this));

            dsManager.give(cdp1, address(proxy));
            manager.give(cdp2, address(proxy));
        }

        uint bCdp = openCdp(address(manager), 1 ether, 20 ether);
        uint mCdp = openCdp(address(dsManager), 2 ether, 30 ether);
        uint mCdp2 = openCdp(address(dsManager), 3 ether, 40 ether);

        for(uint i = 0 ; i < 10 ; i++) {
            uint cdp1 = dsManager.open("ETH-B", address(this));
            uint cdp2 = manager.open("ETH-B", address(this));

            dsManager.give(cdp1, address(proxy));
            manager.give(cdp2, address(proxy));
        }

        pipETH.poke(bytes32(uint(123 * 1e18)));
        spotter.poke("ETH");


        setRateTo1p1();
        manager.give(bCdp, address(proxy));
        dsManager.give(mCdp, address(proxy));
        dsManager.give(mCdp2, address(proxy));

        userInfo.setInfo(address(this), "ETH", manager, dsManager, getCdps, vatLike,
                         spotterLike, registryLike, address(jar), address(ethJoin));

        assertEq(userInfo.hasProxy() ? uint(1) : uint(0), uint(1));
        assertEq(address(userInfo.userProxy()), address(proxy));
        assertEq(userInfo.cdp(), bCdp);
        assertTrue(userInfo.hasCdp());
        assertEq(userInfo.ethDeposit(), 1 ether);
        assertEq(userInfo.daiDebt(), 22 ether);
        // -1 is a rounding error
        assertEq(userInfo.maxDaiDebt(), 82 ether - 1); // 150% with spot price of $123
        assertEq(userInfo.spotPrice(), 123e18);

        assertEq(userInfo.makerdaoCdp(), mCdp);
        assertTrue(userInfo.makerdaoHasCdp());
        assertEq(userInfo.makerdaoEthDeposit(), 2 ether);
        assertEq(userInfo.makerdaoDaiDebt(), 33 ether);
        // -1 is a rounding error
        assertEq(userInfo.makerdaoMaxDaiDebt(), 164 ether - 1); // 150% with spot price of $123
        assertEq(userInfo.spotPrice(), 123e18);
    }

    function testCushion() public {
        FakeProxy proxy = registry.build();
        uint bCdp = openCdp(address(manager), 0 ether, 0 ether);
        reachTopup(bCdp);
        manager.give(bCdp, address(proxy));

        address urn = manager.urns(bCdp);
        (uint ink, uint art) = vat.urns("ETH", urn);
        ink; //shh
        assertTrue(art < 50 ether); // make sure there is a cushion

        userInfo.setInfo(address(this), "ETH", manager, dsManager, getCdps, vatLike,
                         spotterLike, registryLike, address(jar), address(ethJoin));

        assertTrue(userInfo.hasCdp());
        assertEq(userInfo.daiDebt(), 50 ether);
    }

    function testGetCdpInfoBitten() public {
        timeReset();
        FakeProxy proxy = registry.build();

        uint cdp = manager.open("ETH", address(this));

        userInfo.setInfo(address(this), "ETH", manager, dsManager, getCdps, vatLike,
                         spotterLike, registryLike, address(jar), address(ethJoin));

        assertTrue(userInfo.bitten() == false);

        reachBite(cdp);

        manager.give(cdp, address(proxy));
        userInfo.setInfo(address(this), "ETH", manager, dsManager, getCdps, vatLike,
                         spotterLike, registryLike, address(jar), address(ethJoin));

        assertTrue(userInfo.cdp() > 0);
        assertTrue(userInfo.hasCdp());
        assertTrue(userInfo.bitten());
    }

    function testGetCdpInfoUnlockedEth() public {
        timeReset();
        FakeProxy proxy = registry.build();

        uint cdp = openCdp(address(manager), 1 ether, 20 ether);

        manager.give(cdp, address(proxy));

        userInfo.setInfo(address(this), "ETH", manager, dsManager, getCdps, vatLike,
                         spotterLike, registryLike, address(jar), address(ethJoin));

        assertEq(userInfo.unlockedEth(), 0);

        weth.mint(7);
        weth.approve(address(ethJoin), 7);
        ethJoin.join(DssCdpManager(manager).urns(cdp), 7);

        userInfo.setInfo(address(this), "ETH", manager, dsManager, getCdps, vatLike,
                         spotterLike, registryLike, address(jar), address(ethJoin));

        assertTrue(userInfo.hasCdp());
        assertEq(userInfo.unlockedEth(), 7);
    }
/*
    function testGetDebtMissmatch() public {
        timeReset();
        FakeProxy proxy = registry.build();

        uint cdp = openCdp(address(manager), 1 ether, 20 ether);

        // move 1 dai to urn, and call frob
        manager.move(cdp, address(this), 1e45);
        vat.frob(manager.ilks(cdp),manager.urns(cdp),address(this),address(this),0,-1 ether);

        manager.give(cdp, address(proxy));

        userInfo.setInfo(address(this), "ETH", manager, dsManager, getCdps, vatLike,
                         spotterLike, registryLike, address(jar));

        assertTrue(userInfo.hasCdp());

        assertTrue(userInfo.expectedDebtMissmatch());
    }*/

    function testGetCdpInfoMakerDao() public {
        FakeProxy proxy1 = registry.build();
        FakeProxy proxy2 = registry.build();
        FakeProxy proxy3 = registry.build();

        uint bCdp1 = openCdp(address(dsManager), 0, 0);
        uint bCdp2 = openCdp(address(dsManager), 0, 0);
        uint bCdp3 = openCdp(address(dsManager), 1 ether, 20 ether);

        dsManager.give(bCdp1, address(proxy1));
        dsManager.give(bCdp2, address(proxy2));
        dsManager.give(bCdp3, address(proxy3));

        userInfo.setInfo(address(this), "ETH", manager, dsManager, getCdps, vatLike,
                         spotterLike, registryLike, address(jar), address(ethJoin));

        assertTrue(userInfo.hasProxy());
        assertEq(address(userInfo.userProxy()), address(proxy3));
        assertEq(userInfo.makerdaoCdp(), bCdp3);
        assertTrue(userInfo.makerdaoHasCdp());
        assertEq(userInfo.makerdaoEthDeposit(), 1 ether);
        assertEq(userInfo.makerdaoDaiDebt(), 20 ether);
        assertEq(userInfo.makerdaoMaxDaiDebt(), 200 ether); // 150% with spot price of $300
        assertEq(userInfo.spotPrice(), 300e18);
        assertTrue(! userInfo.hasCdp());
    }

    // todo - test cushion


    function setRateTo1p1() internal {
        uint duty;
        uint rho;
        (duty,) = jug.ilks("ETH");
        assertEq(RAY, duty);
        assertEq(uint(address(vat)), uint(address(jug.vat())));
        jug.drip("ETH");
        forwardTime(1);
        jug.drip("ETH");
        this.file(address(jug), "ETH", "duty", RAY + RAY/10);
        (duty,) = jug.ilks("ETH");
        assertEq(RAY + RAY / 10, duty);
        forwardTime(1);
        jug.drip("ETH");
        (, rho) = jug.ilks("ETH");
        assertEq(rho, now);
        (, uint rate,,,) = vat.ilks("ETH");
        assertEq(RAY + RAY/10, rate);
    }

    function almostEqual(uint a, uint b) internal returns(bool) {
        assertTrue(a < uint(1) << 200 && b < uint(1) << 200);

        if(a > b) return almostEqual(b, a);
        if(a * (1e6 + 1) < b * 1e6) return false;

        return true;
    }

}
