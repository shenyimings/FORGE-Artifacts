pragma solidity ^0.5.12;

import { DssCdpManager } from "./DssCdpManager.sol";
import { BCdpScoreConnector } from "./BCdpScoreConnector.sol";
import { Math } from "./Math.sol";

contract VatLike {
    function urns(bytes32 ilk, address u) public view returns (uint ink, uint art);
    function ilks(bytes32 ilk) public view returns(uint Art, uint rate, uint spot, uint line, uint dust);
    function frob(bytes32 i, address u, address v, address w, int dink, int dart) external;
    function move(address src, address dst, uint256 rad) external;
}

contract CatLike {
    function ilks(bytes32) public returns(address flip, uint256 chop, uint256 lump);
}

contract EndLike {
    function cat() public view returns(CatLike);
}

contract PriceFeedLike {
    function read(bytes32 ilk) external view returns(bytes32);
}

contract LiquidationMachine is DssCdpManager, BCdpScoreConnector, Math {
    VatLike                   public vat;
    EndLike                   public end;
    address                   public pool;
    PriceFeedLike             public real;

    mapping(uint => uint)     public tic;  // time of bite
    mapping(uint => uint)     public cushion; // how much was topped in art units

    uint constant             public GRACE = 1 hours;
    uint constant             public WAD = 1e18;

    mapping (uint => bool)    public out;

    modifier onlyPool {
        require(msg.sender == pool, "not-pool");
        _;
    }

    constructor(VatLike vat_, EndLike end_, address pool_, PriceFeedLike real_) public {
        vat = vat_;
        end = end_;
        pool = pool_;
        real = real_;
    }

    function setPool(address newPool) internal {
        pool = newPool;
    }

    function quitBLiquidation(uint cdp) internal {
        untop(cdp);
        out[cdp] = true;
    }

    function topup(uint cdp, uint dtopup) external onlyPool {
        if(out[cdp]) return;

        address urn = urns[cdp];
        bytes32 ilk = ilks[cdp];

        (, uint rate,,,) = vat.ilks(ilk);
        uint dtab = mul(rate, dtopup);

        vat.move(pool, address(this), dtab);
        vat.frob(ilk, urn, urn, address(this), 0, -toInt(dtopup));

        cushion[cdp] = add(cushion[cdp], dtopup);
    }

    function bitten(uint cdp) public view returns(bool) {
        return tic[cdp] + GRACE > now;
    }

    function untop(uint cdp) internal {
        require(! bitten(cdp), "untop: cdp was already bitten");

        uint top = cushion[cdp];
        if(top == 0) return; // nothing to do

        bytes32 ilk = ilks[cdp];
        address urn = urns[cdp];

        (, uint rate,,,) = vat.ilks(ilk);
        uint dtab = mul(rate, top);

        cushion[cdp] = 0;

        // move topping to pool
        vat.frob(ilk, urn, urn, urn, 0, toInt(top));
        vat.move(urn, pool, dtab);
    }

    function untopByPool(uint cdp) external onlyPool {
        untop(cdp);
    }

    function doBite(uint dart, bytes32 ilk, address urn, uint dink) internal {
        (, uint rate,,,) = vat.ilks(ilk);
        uint dtab = mul(rate, dart);

        vat.move(pool, address(this), dtab);

        vat.frob(ilk, urn, urn, address(this), 0, -toInt(dart));
        vat.frob(ilk, urn, msg.sender, urn, -toInt(dink), 0);
    }

    function calcDink(uint dart, uint rate, bytes32 ilk) internal returns(uint dink) {
        (, uint chop,) = end.cat().ilks(ilk);
        uint tab = mul(mul(dart, rate), chop) / WAD;
        bytes32 realtimePrice = real.read(ilk);

        dink = rmul(tab, WAD) / uint(realtimePrice);
    }

    function bite(uint cdp, uint dart) external onlyPool returns(uint dink){
        address urn = urns[cdp];
        bytes32 ilk = ilks[cdp];

        (uint ink, uint art) = vat.urns(ilk, urn);
        art = add(art, cushion[cdp]);
        (, uint rate, uint spotValue,,) = vat.ilks(ilk);

        require(dart <= art, "debt is too low");

        // verify cdp is unsafe now
        if(! bitten(cdp)) {
            require(mul(art, rate) > mul(ink, spotValue), "bite: cdp is safe");
            require(cushion[cdp] > 0, "bite: not-topped");
            tic[cdp] = now;
        }

        dink = calcDink(dart, rate, ilk);
        updateScore(cdp, ilk, -toInt(dink), -toInt(dart), now);

        uint usedCushion = mul(cushion[cdp], dart) / art;
        cushion[cdp] = sub(cushion[cdp], usedCushion);
        uint bart = sub(dart, usedCushion);

        doBite(bart, ilk, urn, dink);
    }
}
