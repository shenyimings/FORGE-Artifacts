pragma solidity ^0.5.12;

import { BCdpManagerTestBase, Hevm, FakeUser, FakeOSM, BCdpManager, FakeDaiToUsdPriceFeed } from "./../BCdpManager.t.sol";
import { DssDeployTestBase, Vat, Cat, Spotter, DSValue } from "dss-deploy/DssDeploy.t.base.sol";
import { BCdpScore } from "./../BCdpScore.sol";
import { Pool } from "./../pool/Pool.sol";
import { LiquidatorInfo } from "./../info/LiquidatorInfo.sol";
import { LiquidationMachine, PriceFeedLike } from "./../LiquidationMachine.sol";
import { DSToken } from "ds-token/token.sol";
import { GemJoin } from "dss/join.sol";
import { Dai } from "dss/dai.sol";
import { DaiJoin } from "dss/join.sol";
import { OSMLike, BudConnector } from "./../bud/BudConnector.sol";

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

    function doAllowance(Dai dai, address guy, uint wad) public {
        dai.approve(guy, wad);
    }

    function doJoin(DaiJoin join, uint wad) public {
        join.join(address(this), wad);
    }

    function doExit(GemJoin join, uint wad) public {
        join.exit(address(this), wad);
    }
}

contract PriceFeed is DSValue {
    function read(bytes32 ilk) external view returns(bytes32) {
        ilk; //shh
        return read();
    }
}

contract FakeCat {
    function ilks(bytes32 ilk) external pure returns(uint flip, uint chop, uint dunk) {
        ilk; //shh
        return (0, 1130000000000000000, 0);
    }
}

contract FakeJug {
    function ilks(bytes32 ilk) public view returns(uint duty, uint rho) {
        duty = 1e27;
        rho = (now / 1 hours) * 1 hours - 10 minutes;
        ilk; // shhhh
    }
    function base() public pure returns(uint) {
        return 0;
    }
}

contract FakeEnd {
    FakeCat public cat;
    constructor() public {
        cat = new FakeCat();
    }
}

contract FakeScore {
    function updateScore(uint cdp, bytes32 ilk, int dink, int dart, uint time) external {

    }
}

contract FakeChainLink {
    PriceFeed price;
    constructor(PriceFeed p) public {
        price = p;
    }
    function latestAnswer(bytes32 ilk) external view returns(int) { return int(uint(price.read(ilk))); }
}

contract WETH is DSToken("WETH") {
    function setDecimals(uint dec) external {
        decimals = dec;
    }
}

contract FakeDssDeployer {
    Vat public vat;
    Spotter public spotter;
    PriceFeed public pipETH;
    FakeOSM public osm;
    Dai public dai;
    DaiJoin public daiJoin;
    mapping(bytes32 => WETH) public weth;
    FakeEnd public end;
    mapping(bytes32 => GemJoin) public ethJoin;
    FakeDaiToUsdPriceFeed public dai2usdPriceFeed;
    Pool public pool;

    constructor() public {
        vat = new Vat();
        vat.rely(msg.sender);
        end = new FakeEnd();
        spotter = new Spotter(address(vat));
        spotter.rely(msg.sender);

        vat.rely(address(spotter));
        vat.file("Line", 568000000000000000000000000000000000000000000000000000);
        spotter.file("par", 1000000000000000000000000000);
        
        dai = new Dai(0);
        daiJoin = new DaiJoin(address(vat), address(dai));
        dai.rely(address(daiJoin));
        vat.hope(address(daiJoin));

        pipETH = new PriceFeed();
        pipETH.poke(bytes32(uint(300 * 10 ** 18))); // Price 300 DAI = 1 ETH (precision 18)        

        osm = new FakeOSM();
        osm.setPrice(uint(300 * 10 ** 18));        

        dai2usdPriceFeed = new FakeDaiToUsdPriceFeed();
        pool = new Pool(address(vat), address(0x12345678), address(spotter), address(new FakeJug()), address(dai2usdPriceFeed));        
    }

    function setIlk(bytes32 _ilk, uint decimals) public {
        bytes32 ilk = _ilk;
        //vat.deny(address(this));

        vat.file(ilk, "spot", 260918853648800000000000000000);
        vat.file(ilk, "line", 340000000000000000000000000000000000000000000000000000);
        vat.file(ilk, "dust", 20000000000000000000000000000000000000000000000);        

        weth[ilk] = new WETH();
        weth[ilk].setDecimals(decimals);
        weth[ilk].mint(2**128);
        ethJoin[ilk] = GemJoin(address(new GemJoin5(address(vat), ilk, address(weth[ilk]))));
        vat.rely(address(ethJoin[ilk]));

        weth[ilk].approve(address(ethJoin[ilk]), uint(-1));
        ethJoin[ilk].join(address(this), 1e18 * 1e6);
        uint vatBalance = vat.gem(ilk,address(this));
        assert(vatBalance == (1e18 * 1e6) * (10**(18 - decimals)));

        //pipETH.setOwner(msg.sender);
        spotter.file(ilk, "pip", address(pipETH)); // Set pip
        spotter.file(ilk, "mat", 1500000000000000000000000000);


        //cat.rely(msg.sender);
        //cat.file(ilk, "chop", 1130000000000000000000000000);

        // set VAT cfg
        vat.init(ilk);
        //vat.fold(ilk, address(0), 1020041883692153436559184034);

        pipETH.poke(bytes32(uint(300 * 10 ** 18))); // Price 300 DAI = 1 ETH (precision 18)
        spotter.poke(ilk);

        assert(vat.live() == 1);


        vat.frob(ilk,address(this),address(this),address(this),1e18 * 1e6,100e6 * 1e18);

        //assert(vat.dai(address(this)) == 100e6 * 1e45);

        daiJoin.exit(address(this), 100e6 * 1e18);

        //assert(100e6 * 1e18 == dai.balanceOf(address(this)));
    }

    function getPool() external returns(Pool) {
        pool.setOwner(msg.sender);
        return pool;
    }

    function poke(BCdpManager man, address guy, int ink, int art, bytes32 ilk) public returns(uint cdpUnsafeNext, uint cdpCustom){
        pipETH.poke(bytes32(uint(300 * 10 ** 18))); // Price 300 DAI = 1 ETH (precision 18)
        spotter.poke(ilk);
        osm.setPrice(uint(300 * 10 ** 18));
        // send ton of gem to holder
        vat.slip(ilk, msg.sender, 1e18 * 1e6);
        vat.slip(ilk, address(this), 1e18 * 1e20);

        // get tons of dai
        dai.transfer(guy, 100e3 * 1e18);

        cdpUnsafeNext = man.open(ilk, address(this));
        vat.flux(ilk, address(this), man.urns(cdpUnsafeNext), 1e7 * 1 ether);
        man.frob(cdpUnsafeNext, 1 ether, 100 ether);

        cdpCustom = man.open(ilk, address(this));
        vat.flux(ilk, address(this), man.urns(cdpCustom), 1e7 * 1 ether);
        man.frob(cdpCustom, ink, art);

        pipETH.poke(bytes32(uint(151 ether)));
        spotter.poke(ilk);
        osm.setPrice(uint(146 ether));
        pipETH.poke(bytes32(uint(146 ether)));
    }

    function updatePrice(bytes32 ilk) public {
        spotter.poke(ilk);
    }
}

contract BDeployer {
    BCdpManager public man;
    Pool public pool;
    FakeMember public member;
    BCdpScore public score;
    FakeDaiToUsdPriceFeed public dai2usdPriceFeed;
    LiquidatorInfo public info;
    BudConnector public budConnector;

    uint public cdpUnsafeNext;
    uint public cdpCustom;

    FakeDssDeployer public deployer;

    constructor(FakeDssDeployer d) public {
        deployer = d;
        dai2usdPriceFeed = d.dai2usdPriceFeed(); //new FakeDaiToUsdPriceFeed();
        pool = d.getPool();//new Pool(address(d.vat()), address(0x12345678), address(d.spotter()), address(new FakeJug()), address(dai2usdPriceFeed));
        score = BCdpScore(address(new FakeScore())); //new BCdpScore();
        man = new BCdpManager(address(d.vat()), address(d.end()), address(pool), address(d.pipETH()), address(score));
        //score.setManager(address(man));
        pool.setCdpManager(man);
        budConnector = new BudConnector(OSMLike(address(d.osm())));
        //budConnector.setPip(address(d.pipETH()), ilk);

        PriceFeed p = d.pipETH();

        budConnector.setPip(address(p), "ETH-A");
        budConnector.setPip(address(p), "ETH-B");
        budConnector.setPip(address(p), "ETH-C");
        budConnector.setPip(address(p), "WBTC-A");        

        budConnector.authorize(address(pool));
        address[] memory members = new address[](3);
        member = new FakeMember();
        members[0] = address(member);
        members[1] = 0xe6bD52f813D76ff4192058C307FeAffe52aA49FC;
        members[2] = 0x534447900af78B74bB693470cfE7c7dFd54A974c;
        pool.setMembers(members);
        pool.setProfitParams(94, 100);
        //pool.setOwner(msg.sender);

        info = new LiquidatorInfo(LiquidationMachine(man), address(new FakeChainLink(p)), address(new FakeChainLink(p)));
    }

    function setIlk(bytes32 ilk, uint decimals) public {
        deployer.setIlk(ilk, decimals);
        pool.setOsm(ilk, address(budConnector));
        pool.setIlk(ilk, true);        
    }

    function poke(int ink, int art, bytes32 ilk) public {
        (cdpUnsafeNext, cdpCustom) = deployer.poke(man, msg.sender, ink, art, ilk);
    }

    function updatePrice(bytes32 ilk) public {
        deployer.updatePrice(ilk);
    }
}


contract DeploymentTest is BCdpManagerTestBase {
    uint currTime;
    FakeMember member;
    FakeMember[] members;
    FakeMember nonMember;
    FakeDssDeployer dssDeployer;
    BDeployer bDeployer;

    address constant JAR = address(0x1234567890);

    //VatDeployer deployer;

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

        member = members[0];

        dssDeployer = new FakeDssDeployer();
        bDeployer = new BDeployer(dssDeployer);        
    }

    function testGas() public {
        FakeDssDeployer x = new FakeDssDeployer();
        BDeployer b = new BDeployer(x);
        b.setIlk("ETH-C", 18);
    }

    function testAllIlks() public {
        testDeployerIlk("ETH-A", 18);
        testDeployerIlk("ETH-B", 18);
        testDeployerIlk("ETH-C", 18);
        testDeployerIlk("WBTC-A", 8);                        
    }

    function testDeployerEthA() public {
        testDeployerIlk("ETH-A", 18);
    }

    function testDeployerEthB() public {
        testDeployerIlk("ETH-B", 18);
    }

    function testDeployerEthC() public {
        testDeployerIlk("ETH-C", 18);
    }

    function testDeployerWBTCA() public {
        testDeployerIlk("WBTC-A", 8);
    }    

    function testDeployerIlk(bytes32 ilk, uint decimals) internal {
        FakeDssDeployer ds = dssDeployer; //new FakeDssDeployer();
        BDeployer b = bDeployer; //new BDeployer(ds);
        b.setIlk(ilk, decimals);
        b.poke(1 ether, 20 ether, ilk);
        b.poke(2 ether, 30 ether, ilk);
        assertTrue(ds.dai().balanceOf(address(this)) > 1e5 * 1e18);

        assertEq(ds.vat().live(), 1);

        uint cdp2 = b.cdpUnsafeNext();
        uint cdp3 = b.cdpCustom();

        address urn = b.man().urns(cdp3);
        {
            (uint ink, uint art) = ds.vat().urns(ilk, urn);
            assertEq(ink, 2 ether);
            assertEq(art, 30 ether);
            uint dartX;
            (dartX,,) = b.pool().topAmount(cdp2);
            assertTrue(dartX > 0);
        }

        Pool p = b.pool();
        Vat v = ds.vat();
        FakeMember m = b.member();
        ds.dai().transfer(address(m), 1e22);

        m.doAllowance(ds.dai(), address(ds.daiJoin()), uint(-1));
        m.doJoin(ds.daiJoin(), 1e22);
        assertEq(v.dai(address(m)), 1e22 * 1e27);
        m.doHope(v, address(p));
        {
            uint prevRadBalance = p.rad(address(m));
            m.doDeposit(p, 1e22 * 1e27);
            assertEq(p.rad(address(m)), 1e22 * 1e27 + prevRadBalance);
        }

        forwardTime(1);
        p.topupInfo(cdp2); // just make sure it does not crash

        m.doTopup(p, cdp2);
        ds.updatePrice(ilk);
        m.doBite(p, cdp2, 100 ether, 0);
        assertEq(v.gem(ilk, address(m)), 727534246575342465);

        uint factor = 10 ** (18 - decimals);
        
        assertEq(ds.weth(ilk).balanceOf(address(m)), 0);
        m.doExit(ds.ethJoin(ilk), 727534246575342465 / factor);
        assertEq(ds.weth(ilk).balanceOf(address(m)), 727534246575342465 / factor);
    }

    function testDeployerMultiplePokes() public {
        FakeDssDeployer ds = new FakeDssDeployer();
        BDeployer b = new BDeployer(ds);
        b.setIlk("ETH-B", 18);

        uint cdp1; uint cdp2; uint cdp3; uint cdp4;

        b.poke(1 ether, 99 ether, "ETH-B");
        cdp1 = b.cdpUnsafeNext();
        cdp2 = b.cdpCustom();

        b.poke(1 ether, 98 ether, "ETH-B");
        cdp3 = b.cdpUnsafeNext();
        cdp4 = b.cdpCustom();

        uint dart;
        (dart,,) = b.pool().topAmount(cdp1);
        assertTrue(dart > 0);
        (dart,,) = b.pool().topAmount(cdp2);
        assertTrue(dart > 0);
        (dart,,) = b.pool().topAmount(cdp3);
        assertTrue(dart > 0);
        (dart,,) = b.pool().topAmount(cdp4);
        assertTrue(dart > 0);
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
}


contract GemJoin5 {
    // --- Auth ---
    mapping (address => uint256) public wards;
    function rely(address usr) external auth { wards[usr] = 1; }
    function deny(address usr) external auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    VatLike public vat;
    bytes32 public ilk;
    GemLike public gem;
    uint256 public dec;
    uint256 public live;  // Access Flag

    constructor(address vat_, bytes32 ilk_, address gem_) public {
        gem = GemLike(gem_);
        dec = gem.decimals();
        require(dec <= 18, "GemJoin5/decimals-18-or-higher");
        wards[msg.sender] = 1;
        live = 1;
        vat = VatLike(vat_);
        ilk = ilk_;
    }

    function cage() external auth {
        live = 0;
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "GemJoin5/overflow");
    }

    function join(address urn, uint256 amt) public {
        require(live == 1, "GemJoin5/not-live");
        uint256 wad = mul(amt, 10 ** (18 - dec));
        require(int256(wad) >= 0, "GemJoin5/overflow");
        vat.slip(ilk, urn, int256(wad));
        require(gem.transferFrom(msg.sender, address(this), amt), "GemJoin5/failed-transfer");
    }

    function exit(address guy, uint256 amt) public {
        uint256 wad = mul(amt, 10 ** (18 - dec));
        require(int256(wad) >= 0, "GemJoin5/overflow");
        vat.slip(ilk, msg.sender, -int256(wad));
        require(gem.transfer(guy, amt), "GemJoin5/failed-transfer");
    }
}

contract GemLike {
    function decimals() external view returns (uint8);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

contract VatLike {
    function slip(bytes32, address, int256) external;
}
