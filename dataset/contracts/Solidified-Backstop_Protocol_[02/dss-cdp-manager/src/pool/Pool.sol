pragma solidity ^0.5.12;

import { LibNote } from "dss/lib.sol";
import { BCdpManager } from "./../BCdpManager.sol";
import { Math } from "./../Math.sol";
import { DSAuth } from "ds-auth/auth.sol";

contract VatLike {
    function urns(bytes32 ilk, address u) public view returns (uint ink, uint art);
    function ilks(bytes32 ilk) public view returns(uint Art, uint rate, uint spot, uint line, uint dust);
    function flux(bytes32 ilk, address src, address dst, uint256 wad) external;
    function move(address src, address dst, uint256 rad) external;
    function hope(address usr) external;
    function dai(address usr) external view returns(uint);
}

contract JugLike {
    function ilks(bytes32 ilk) public view returns(uint duty, uint rho);
    function base() public view returns(uint);
}

contract PriceFeedLike {
    function peek(bytes32 ilk) external view returns(bytes32, bool);
}

contract SpotLike {
    function par() external view returns (uint256);
    function ilks(bytes32 ilk) external view returns (address pip, uint mat);
}

contract OSMLike {
    function peep() external view returns(bytes32, bool);
    function hop()  external view returns(uint16);
    function zzz()  external view returns(uint64);
}

contract DaiToUsdPriceFeed {
    function getMarketPrice(uint marketId) public view returns (uint);
}

contract Pool is Math, DSAuth, LibNote {
    uint public constant DAI_MARKET_ID = 3;
    address[] public members;
    mapping(bytes32 => bool) public ilks;
    uint                     public minArt; // min debt to share among members
    uint                     public shrn;   // share profit % numerator
    uint                     public shrd;   // share profit % denumerator
    mapping(address => uint) public rad;    // mapping from member to its dai balance in rad

    VatLike                   public vat;
    BCdpManager               public man;
    SpotLike                  public spot;
    JugLike                   public jug;
    address                   public jar;
    DaiToUsdPriceFeed         public dai2usd;

    mapping(uint => CdpData)  internal cdpData;

    mapping(bytes32 => OSMLike) public osm; // mapping from ilk to osm

    struct CdpData {
        uint       art;        // topup in art units
        uint       cushion;    // cushion in rad units
        address[]  members;    // liquidators that are in
        uint[]     bite;       // how much was already bitten
    }

    modifier onlyMember {
        bool member = false;
        for(uint i = 0 ; i < members.length ; i++) {
            if(members[i] == msg.sender) {
                member = true;
                break;
            }
        }
        require(member, "not-member");
        _;
    }

    constructor(address vat_, address jar_, address spot_, address jug_, address dai2usd_) public {
        spot = SpotLike(spot_);
        jug = JugLike(jug_);
        vat = VatLike(vat_);
        jar = jar_;
        dai2usd = DaiToUsdPriceFeed(dai2usd_);
    }

    function getCdpData(uint cdp) external view returns(uint art, uint cushion, address[] memory members_, uint[] memory bite) {
        art = cdpData[cdp].art;
        cushion = cdpData[cdp].cushion;
        members_ = cdpData[cdp].members;
        bite = cdpData[cdp].bite;
    }

    function setCdpManager(BCdpManager man_) external auth note {
        man = man_;
        vat.hope(address(man));
    }

    function setOsm(bytes32 ilk_, address  osm_) external auth note {
        osm[ilk_] = OSMLike(osm_);
    }

    function setMembers(address[] calldata members_) external auth note {
        members = members_;
    }

    function setIlk(bytes32 ilk, bool set) external auth note {
        ilks[ilk] = set;
    }

    function setMinArt(uint minArt_) external auth note {
        minArt = minArt_;
    }

    function setDaiToUsdPriceFeed(address dai2usd_) external auth note {
        dai2usd = DaiToUsdPriceFeed(dai2usd_);
    }

    function setProfitParams(uint num, uint den) external auth note {
        require(num < den, "invalid-profit-params");
        shrn = num;
        shrd = den;
    }

    function emergencyExecute(address target, bytes calldata data) external auth note {
        (bool succ,) = target.call(data);
        require(succ, "emergencyExecute: failed");
    }

    function deposit(uint radVal) external onlyMember note {
        vat.move(msg.sender, address(this), radVal);
        rad[msg.sender] = add(rad[msg.sender], radVal);
    }

    function withdraw(uint radVal) external note {
        require(rad[msg.sender] >= radVal, "withdraw: insufficient-balance");
        rad[msg.sender] = sub(rad[msg.sender], radVal);
        vat.move(address(this), msg.sender, radVal);
    }

    function getIndex(address[] storage array, address elm) internal view returns(uint) {
        for(uint i = 0 ; i < array.length ; i++) {
            if(array[i] == elm) return i;
        }

        return uint(-1);
    }

    function removeElement(address[] memory array, uint index) internal pure returns(address[] memory newArray) {
        if(index >= array.length) {
            newArray = array;
        }
        else {
            newArray = new address[](array.length - 1);
            for(uint i = 0 ; i < array.length ; i++) {
                if(i == index) continue;
                if(i < index) newArray[i] = array[i];
                else newArray[i-1] = array[i];
            }
        }
    }

    function chooseMember(uint cdp, uint radVal, address[] memory candidates) public view returns(address[] memory winners) {
        if(candidates.length == 0) return candidates;
        // A bit of randomness to choose winners. We don't need pure randomness, its ok even if a
        // liquidator can predict his winning in the future.
        uint chosen = uint(keccak256(abi.encodePacked(cdp, now / 1 hours))) % candidates.length;
        address winner = candidates[chosen];

        if(rad[winner] < radVal) return chooseMember(cdp, radVal, removeElement(candidates, chosen));

        winners = new address[](1);
        winners[0] = candidates[chosen];
        return winners;
    }

    function chooseMembers(uint radVal, address[] memory candidates) public view returns(address[] memory winners) {
        if(candidates.length == 0) return candidates;

        uint need = add(1, radVal / candidates.length);
        for(uint i = 0 ; i < candidates.length ; i++) {
            if(rad[candidates[i]] < need) {
                return chooseMembers(radVal, removeElement(candidates, i));
            }
        }

        winners = candidates;
    }

    function calcCushion(bytes32 ilk, uint ink, uint art, uint nextSpot) public view returns(uint dart, uint dtab) {
        (, uint prev, uint currSpot,,) = vat.ilks(ilk);
        if(currSpot <= nextSpot) return (0, 0);

        uint hop = uint(osm[ilk].hop());
        uint next = add(uint(osm[ilk].zzz()), hop);
        (uint duty, uint rho) = jug.ilks(ilk);

        require(next >= rho, "calcCushion: next-in-the-past");

        // note that makerdao governance could change jug.base() before the actual
        // liquidation happens. but there is 48 hours time lock on makerdao votes
        // so liquidators should withdraw their funds if they think such event will
        // happen
        uint nextRate = rmul(rpow(add(jug.base(), duty), next - rho, RAY), prev);
        uint nextnextRate = rmul(rpow(add(jug.base(), duty), hop, RAY), nextRate);

        if(mul(nextRate, art) > mul(ink, currSpot)) return (0, 0); // prevent L attack
        if(mul(nextRate, art) <= mul(ink, nextSpot)) return (0, 0);

        uint maxArt = mul(ink, nextSpot) / nextnextRate;
        dart = sub(art, maxArt);
        dart = add(1 ether, dart); // compensate for rounding errors
        dtab = mul(dart, prev); // provide a cushion according to current rate
    }

    function hypoTopAmount(uint cdp) internal view returns(uint dart, uint dtab, uint art, bool should) {
        address urn = man.urns(cdp);
        bytes32 ilk = man.ilks(cdp);

        uint ink;
        (ink, art) = vat.urns(ilk, urn);

        if(! ilks[ilk]) return (0, 0, art, false);

        (bytes32 peep, bool valid) = osm[ilk].peep();

        // price feed invalid
        if(! valid) return (0, 0, art, false);

        // too early to topup
        should = (now >= add(uint(osm[ilk].zzz()), uint(osm[ilk].hop())/2));

        (, uint mat) = spot.ilks(ilk);
        uint par = spot.par();

        uint nextVatSpot = rdiv(rdiv(mul(uint(peep), uint(10 ** 9)), par), mat);

        (dart, dtab) = calcCushion(ilk, ink, art, nextVatSpot);
    }

    function topAmount(uint cdp) public view returns(uint dart, uint dtab, uint art) {
        bool should;
        (dart, dtab, art, should) = hypoTopAmount(cdp);
        if(! should) return (0, 0, art);
    }

    function resetCdp(uint cdp) internal {
        address[] memory winners = cdpData[cdp].members;

        if(winners.length == 0) return;

        uint art = cdpData[cdp].art;
        uint cushion = cdpData[cdp].cushion;

        uint perUserArt = cdpData[cdp].art / winners.length;
        for(uint i = 0 ; i < winners.length ; i++) {
            if(perUserArt <= cdpData[cdp].bite[i]) continue; // nothing to refund
            uint refundArt = sub(perUserArt, cdpData[cdp].bite[i]);
            rad[winners[i]] = add(rad[winners[i]], mul(refundArt, cushion)/art);
        }

        cdpData[cdp].art = 0;
        cdpData[cdp].cushion = 0;
        delete cdpData[cdp].members;
        delete cdpData[cdp].bite;
    }

    function setCdp(uint cdp, address[] memory winners, uint art, uint dradVal) internal {
        uint drad = add(1, dradVal / winners.length); // round up
        for(uint i = 0 ; i < winners.length ; i++) {
            rad[winners[i]] = sub(rad[winners[i]], drad);
        }

        cdpData[cdp].art = art;
        cdpData[cdp].cushion = dradVal;
        cdpData[cdp].members = winners;
        cdpData[cdp].bite = new uint[](winners.length);
    }

    function topupInfo(uint cdp) public view returns(uint dart, uint dtab, uint art, bool should, address[] memory winners) {
        (dart, dtab, art, should) = hypoTopAmount(cdp);
        if(art < minArt) {
            winners = chooseMember(cdp, uint(dtab), members);
        }
        else winners = chooseMembers(uint(dtab), members);
    }

    function topup(uint cdp) external onlyMember note {
        require(man.cushion(cdp) == 0, "topup: already-topped");
        require(! man.bitten(cdp), "topup: already-bitten");

        (uint dart, uint dtab, uint art, bool should, address[] memory winners) = topupInfo(cdp);

        require(should, "topup: no-need");
        require(dart > 0, "topup: 0-dart");

        resetCdp(cdp);

        require(winners.length > 0, "topup: members-are-broke");
        // for small amounts, only winner can topup
        if(art < minArt) require(winners[0] == msg.sender, "topup: only-winner-can-topup");

        setCdp(cdp, winners, uint(art), uint(dtab));

        man.topup(cdp, uint(dart));
    }

    function untop(uint cdp) external onlyMember note {
        require(man.cushion(cdp) == 0, "untop: should-be-untopped-by-user");

        resetCdp(cdp);
    }

    function bite(uint cdp, uint dart, uint minInk) external onlyMember note returns(uint dMemberInk){
        uint index = getIndex(cdpData[cdp].members, msg.sender);
        uint availBite = availBite(cdp, index);
        require(dart <= availBite, "bite: debt-too-small");

        cdpData[cdp].bite[index] = add(cdpData[cdp].bite[index], dart);

        uint dink = man.bite(cdp, dart);

        // update user rad
        bytes32 ilk = man.ilks(cdp);
        (,uint rate,,,) = vat.ilks(ilk);
        uint cushionPortion = mul(cdpData[cdp].cushion, dart) / cdpData[cdp].art;
        rad[msg.sender] = sub(rad[msg.sender], sub(mul(dart, rate), cushionPortion));

        // DAI to USD rate, scale 1e18
        uint d2uPrice = dai2usd.getMarketPrice(DAI_MARKET_ID);

        // dMemberInk = debt * 1.065 * d2uPrice
        // dMemberInk = dink * (shrn/shrd) * (d2uPrice/1e18)
        dMemberInk = mul(mul(dink, shrn), d2uPrice) / mul(shrd, uint(1 ether));

        // To protect edge case when 1 DAI > 1.13 USD
        if(dMemberInk > dink) dMemberInk = dink;

        // Remaining to Jar
        uint userInk = sub(dink, dMemberInk);

        require(dMemberInk >= minInk, "bite: low-dink");

        vat.flux(ilk, address(this), jar, userInk);
        vat.flux(ilk, address(this), msg.sender, dMemberInk);
    }

    function availBite(uint cdp, address member) public view returns (uint) {
        uint index = getIndex(cdpData[cdp].members, member);
        return availBite(cdp, index);
    }

    function availBite(uint cdp, uint index) internal view returns (uint) {
        if(index == uint(-1)) return 0;

        uint numMembers = cdpData[cdp].members.length;

        uint maxArt = cdpData[cdp].art / numMembers;
        // give dust to first member
        if(index == 0) {
            uint dust = cdpData[cdp].art % numMembers;
            maxArt = add(maxArt, dust);
        }
        uint availArt = sub(maxArt, cdpData[cdp].bite[index]);

        address urn = man.urns(cdp);
        bytes32 ilk = man.ilks(cdp);
        (,uint art) = vat.urns(ilk, urn);
        uint remainingArt = add(art, man.cushion(cdp));

        return availArt < remainingArt ? availArt : remainingArt;
    }
}
