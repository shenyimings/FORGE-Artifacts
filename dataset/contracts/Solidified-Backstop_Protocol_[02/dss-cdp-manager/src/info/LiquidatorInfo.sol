pragma solidity ^0.5.12;
pragma experimental ABIEncoderV2;

import { LiquidationMachine } from "./../LiquidationMachine.sol";
import { Pool } from "./../pool/Pool.sol";
import { Math } from "./../Math.sol";

contract VatLike {
    function urns(bytes32 ilk, address u) public view returns (uint ink, uint art);
    function ilks(bytes32 ilk) public view returns(uint Art, uint rate, uint spot, uint line, uint dust);
}

contract SpotLike {
    function ilks(bytes32 ilk) external view returns (address pip, uint mat);
}

contract ChainlinkLike {
    function latestAnswer(bytes32 ilk) external view returns (int256);
}

contract LiquidatorInfo is Math {
    struct VaultInfo {
        bytes32 collateralType;
        uint collateralInWei;
        uint debtInDaiWei;
        uint liquidationPrice;
        uint expectedEthReturnWithCurrentPrice;
        bool expectedEthReturnBetterThanChainlinkPrice;
    }

    struct CushionInfo {
        uint cushionSizeInWei;
        uint numLiquidators;

        uint cushionSizeInWeiIfAllHaveBalance;
        uint numLiquidatorsIfAllHaveBalance;

        bool shouldProvideCushion;
        bool shouldProvideCushionIfAllHaveBalance;

        uint minimumTimeBeforeCallingTopup;
        bool canCallTopupNow;

        bool shouldCallUntop;
        bool isToppedUp;
    }

    struct BiteInfo {
        uint availableBiteInArt;
        uint availableBiteInDaiWei;
        uint minimumTimeBeforeCallingBite;
        bool canCallBiteNow;
    }

    struct CdpInfo {
        uint cdp;
        uint blockNumber;
        VaultInfo vault;
        CushionInfo cushion;
        BiteInfo bite;
    }

    // Struct to store local vars. This avoid stack too deep error
    struct CdpDataVars {
        uint cdpArt;
        uint cushion;
         address[] cdpWinners;
         uint[] bite;
    }

    LiquidationMachine public manager;
    VatLike public vat;
    Pool public pool;
    SpotLike public spot;
    ChainlinkLike public chainlink;
    ChainlinkLike public makerOracle;    

    constructor(LiquidationMachine manager_, address makerOracle_, address chainlink_) public {
        manager = manager_;
        vat = VatLike(address(manager.vat()));
        pool = Pool(manager.pool());
        spot = SpotLike(address(pool.spot()));
        chainlink = ChainlinkLike(chainlink_);
        makerOracle = ChainlinkLike(makerOracle_);
    }

    function getExpectedEthReturn(bytes32 collateralType, uint daiDebt, uint currentPriceFeedValue) public returns(uint) {
        // get chope value
        (,uint chop,) = manager.end().cat().ilks(collateralType);
        uint biteIlk = mul(chop, daiDebt) / currentPriceFeedValue;

        // DAI to USD rate, scale 1e18
        uint d2uPrice = pool.dai2usd().getMarketPrice(pool.DAI_MARKET_ID());
        uint shrn = pool.shrn();
        uint shrd = pool.shrd();

        return mul(mul(biteIlk, shrn), d2uPrice) / mul(shrd, uint(1 ether));
    }

    function getVaultInfo(uint cdp) public returns(VaultInfo memory info) {
        address urn = manager.urns(cdp);
        info.collateralType = manager.ilks(cdp);

        uint cushion = manager.cushion(cdp);

        uint art;
        (info.collateralInWei, art) = vat.urns(info.collateralType, urn);
        if(info.collateralInWei == 0) return info;
        (,uint rate,,,) = vat.ilks(info.collateralType);
        info.debtInDaiWei = mul(add(art, cushion), rate) / RAY;
        (, uint mat) = spot.ilks(info.collateralType);
        info.liquidationPrice = mul(info.debtInDaiWei, mat) / mul(info.collateralInWei, RAY / 1e18);

        uint currentPriceFeedValue = uint(makerOracle.latestAnswer(info.collateralType));

        if(currentPriceFeedValue > 0) {
            info.expectedEthReturnWithCurrentPrice = getExpectedEthReturn(info.collateralType, info.debtInDaiWei, currentPriceFeedValue);
        }

        int chainlinkPrice = chainlink.latestAnswer(info.collateralType);
        uint chainlinkEthReturn = 0;
        if(chainlinkPrice > 0) {
            chainlinkEthReturn = mul(info.debtInDaiWei, uint(chainlinkPrice)) / 1 ether;
        }

        info.expectedEthReturnBetterThanChainlinkPrice =
            info.expectedEthReturnWithCurrentPrice > chainlinkEthReturn;
    }

    function getCushionInfo(uint cdp, address me, uint numMembers) public view returns(CushionInfo memory info) {
        CdpDataVars memory c;
        (c.cdpArt, c.cushion, c.cdpWinners, c.bite) = pool.getCdpData(cdp);

        for(uint i = 0 ; i < c.cdpWinners.length ; i++) {
            if(me == c.cdpWinners[i]) {
                uint perUserArt = c.cdpArt / c.cdpWinners.length;
                info.shouldCallUntop = manager.cushion(cdp) == 0 && c.cushion > 0 && c.bite[i] < perUserArt;
                info.isToppedUp = c.bite[i] < perUserArt;
                break;
            }
        }

        (uint dart, uint dtab, uint art, bool should, address[] memory winners) = pool.topupInfo(cdp);

        info.numLiquidators = winners.length;
        info.cushionSizeInWei = dtab / RAY;

        if(dart == 0) {
            if(info.isToppedUp) {
                info.numLiquidatorsIfAllHaveBalance = winners.length;
                info.cushionSizeInWei = c.cushion / RAY;
            }

            return info;
        }

        if(art < pool.minArt()) {
            info.cushionSizeInWeiIfAllHaveBalance = info.cushionSizeInWei;
            info.numLiquidatorsIfAllHaveBalance = 1;
            info.shouldProvideCushion = false;
            for(uint i = 0 ; i < winners.length ; i++) {
                if(me == winners[i]) info.shouldProvideCushion = true;
            }

            uint chosen = uint(keccak256(abi.encodePacked(cdp, now / 1 hours))) % numMembers;
            info.shouldProvideCushionIfAllHaveBalance = (pool.members(chosen) == me);
        }
        else {
            info.cushionSizeInWeiIfAllHaveBalance = info.cushionSizeInWei / numMembers;
            info.numLiquidatorsIfAllHaveBalance = numMembers;
            info.shouldProvideCushion = true;
            info.shouldProvideCushionIfAllHaveBalance = true;
        }

        info.canCallTopupNow = !info.isToppedUp && should && info.shouldProvideCushion;

        bytes32 ilk = manager.ilks(cdp);
        uint topupTime = add(uint(pool.osm(ilk).zzz()), uint(pool.osm(ilk).hop())/2);
        info.minimumTimeBeforeCallingTopup = (now >= topupTime) ? 0 : sub(topupTime, now);

        (,uint rate,,,uint dust) = vat.ilks(ilk);
        if((dart > art) || (mul(rate, sub(art, dart)) < dust)) {
            info.shouldProvideCushion = false;
            info.shouldProvideCushionIfAllHaveBalance = false;
            info.canCallTopupNow = false;
        }
    }

    function getBiteInfo(uint cdp, address me) public view returns(BiteInfo memory info) {
        info.availableBiteInArt = pool.availBite(cdp, me);

        bytes32 ilk = manager.ilks(cdp);
        uint priceUpdateTime = add(uint(pool.osm(ilk).zzz()), uint(pool.osm(ilk).hop()));
        info.minimumTimeBeforeCallingBite = (now >= priceUpdateTime) ? 0 : sub(priceUpdateTime, now);

        if(info.availableBiteInArt == 0) return info;

        address u = manager.urns(cdp);
        (,uint rate, uint currSpot,,) = vat.ilks(ilk);

        info.availableBiteInDaiWei = mul(rate, info.availableBiteInArt) / RAY;

        (uint ink, uint art) = vat.urns(ilk, u);
        uint cushion = manager.cushion(cdp);
        info.canCallBiteNow = (mul(ink, currSpot) < mul(add(art, cushion), rate)) || manager.bitten(cdp);
    }

    function getNumMembers() public returns(uint) {
        for(uint i = 0 ; /* infinite loop */ ; i++) {
            (bool result,) = address(pool).call(abi.encodeWithSignature("members(uint256)", i));
            if(! result) return i;
        }
    }

    function getCdpData(uint startCdp, uint endCdp, address me) public returns(CdpInfo[] memory info) {
        uint numMembers = getNumMembers();
        info = new CdpInfo[](add(sub(endCdp, startCdp), uint(1)));
        for(uint cdp = startCdp ; cdp <= endCdp ; cdp++) {
            uint index = cdp - startCdp;
            info[index].cdp = cdp;
            info[index].blockNumber = block.number;
            info[index].vault = getVaultInfo(cdp);
            info[index].cushion = getCushionInfo(cdp, me, numMembers);
            info[index].bite = getBiteInfo(cdp, me);
        }
    }

    function getCdpData(uint startCdp, uint endCdp, address me, uint) external returns(CdpInfo[] memory info) {
        return getCdpData(startCdp, endCdp, me);
    }

    function getCdpData(uint[] memory cdps, address me) public returns(CdpInfo[] memory info) {
        uint numMembers = getNumMembers();
        info = new CdpInfo[](cdps.length);
        for(uint index = 0 ; index < cdps.length ; index++) {
            uint cdp = cdps[index];
            info[index].cdp = cdp;
            info[index].blockNumber = block.number;
            info[index].vault = getVaultInfo(cdp);
            info[index].cushion = getCushionInfo(cdp, me, numMembers);
            info[index].bite = getBiteInfo(cdp, me);
        }
    }

    function getCdpData(uint[] calldata cdps, address me, uint) external returns(CdpInfo[] memory info) {
        return getCdpData(cdps, me);
    }    
}

contract FlatLiquidatorInfo is LiquidatorInfo {
    constructor(LiquidationMachine manager_, address makerOracle_, address chainlink_) public LiquidatorInfo(manager_, makerOracle_, chainlink_) {}

    function getVaultInfoFlat(uint cdp) external
        returns(bytes32 collateralType, uint collateralInWei, uint debtInDaiWei, uint liquidationPrice,
                uint expectedEthReturnWithCurrentPrice, bool expectedEthReturnBetterThanChainlinkPrice) {
        VaultInfo memory info = getVaultInfo(cdp);
        collateralType = info.collateralType;
        collateralInWei = info.collateralInWei;
        debtInDaiWei = info.debtInDaiWei;
        liquidationPrice = info.liquidationPrice;
        expectedEthReturnWithCurrentPrice = info.expectedEthReturnWithCurrentPrice;
        expectedEthReturnBetterThanChainlinkPrice = info.expectedEthReturnBetterThanChainlinkPrice;
    }

    function getCushionInfoFlat(uint cdp, address me, uint numMembers) external view
        returns(uint cushionSizeInWei, uint numLiquidators, uint cushionSizeInWeiIfAllHaveBalance,
                uint numLiquidatorsIfAllHaveBalance, bool shouldProvideCushion, bool shouldProvideCushionIfAllHaveBalance,
                bool canCallTopupNow, bool shouldCallUntop, uint minimumTimeBeforeCallingTopup,
                bool isToppedUp) {

        CushionInfo memory info = getCushionInfo(cdp, me, numMembers);
        cushionSizeInWei = info.cushionSizeInWei;
        numLiquidators = info.numLiquidators;
        cushionSizeInWeiIfAllHaveBalance = info.cushionSizeInWeiIfAllHaveBalance;
        numLiquidatorsIfAllHaveBalance = info.numLiquidatorsIfAllHaveBalance;
        shouldProvideCushion = info.shouldProvideCushion;
        shouldProvideCushionIfAllHaveBalance = info.shouldProvideCushionIfAllHaveBalance;
        canCallTopupNow = info.canCallTopupNow;
        shouldCallUntop = info.shouldCallUntop;
        minimumTimeBeforeCallingTopup = info.minimumTimeBeforeCallingTopup;
        isToppedUp = info.isToppedUp;
    }

    function getBiteInfoFlat(uint cdp, address me) external view
        returns(uint availableBiteInArt, uint availableBiteInDaiWei, bool canCallBiteNow,uint minimumTimeBeforeCallingBite) {
        BiteInfo memory info = getBiteInfo(cdp, me);
        availableBiteInArt = info.availableBiteInArt;
        availableBiteInDaiWei = info.availableBiteInDaiWei;
        canCallBiteNow = info.canCallBiteNow;
        minimumTimeBeforeCallingBite = info.minimumTimeBeforeCallingBite;
    }
}

contract ERC20Like {
    function balanceOf(address guy) public view returns(uint);
}

contract VatBalanceLike {
    function gem(bytes32 ilk, address user) external view returns(uint);
    function dai(address user) external view returns(uint);
}

contract LiquidatorBalanceInfo is Math {
    struct BalanceInfo {
        uint blockNumber;
        uint ethBalance;
        uint wethBalance;
        uint wbtcBalance;
        uint daiBalance;
        uint vatDaiBalanceInWei;
        uint vatEthBalanceInWei;
        uint poolDaiBalanceInWei;
    }

    function cdpi(address pool) public view returns (uint cdpi) {
        cdpi = Pool(pool).man().cdpi();
    }

    function getTotalCushion(address me, address pool, uint startCdp, uint endCdp)
        public view returns(uint cushionInArt) {

        for(uint cdp = startCdp ; cdp <= endCdp ; cdp++) {
            (uint topupArt, uint cushion, address[] memory members, uint[] memory bite) = Pool(pool).getCdpData(cdp);
            for(uint m = 0 ; topupArt > 0 && m < members.length ; m++) {
                uint perUserArt = topupArt / members.length;
                if(perUserArt <= bite[m]) continue;
                if(members[m] == me) {
                    uint refundArt = sub(perUserArt, bite[m]);
                    cushionInArt = add(cushionInArt, mul(refundArt, cushion)/topupArt);
                    break;
                }
            }
        }

        cushionInArt = cushionInArt / RAY;
    }

    function getTotalCushion(address me, address pool)
        public view returns(uint cushionInArt) {

        uint startCdp = 1;
        uint endCdp = Pool(pool).man().cdpi();

        cushionInArt = getTotalCushion(me, pool, startCdp, endCdp);
    }

    function getBalanceInfo(address me, address pool, address vat, bytes32 ilk, address dai, address weth, address wbtc)
        public view returns(BalanceInfo memory info) {

        info.blockNumber = block.number;
        info.ethBalance = me.balance;
        info.wethBalance = ERC20Like(weth).balanceOf(me);
        info.wbtcBalance = ERC20Like(wbtc).balanceOf(me) * 10 ** 10;
        info.daiBalance = ERC20Like(dai).balanceOf(me);
        info.vatDaiBalanceInWei = VatBalanceLike(vat).dai(me) / RAY;
        info.vatEthBalanceInWei = VatBalanceLike(vat).gem(ilk, me);
        info.poolDaiBalanceInWei = Pool(pool).rad(me) / RAY;
    }

    function getBalanceInfoFlat(address me, address pool, address vat, bytes32 ilk, address dai, address weth, address wbtc)
        public view returns(uint blockNumber, uint[3] memory balances,/* ethBalance, uint wethBalance, uint wbtcBalance,*/ uint daiBalance, uint vatDaiBalanceInWei,
                            uint vatEthBalanceInWei, uint poolDaiBalanceInWei) {

        BalanceInfo memory info = getBalanceInfo(me, pool, vat, ilk, dai, weth, wbtc);
        blockNumber = info.blockNumber;
        balances[0] = info.ethBalance;
        balances[1] = info.wethBalance;
        balances[2] = info.wbtcBalance;
        daiBalance = info.daiBalance;
        vatDaiBalanceInWei = info.vatDaiBalanceInWei;
        vatEthBalanceInWei = info.vatEthBalanceInWei;
        poolDaiBalanceInWei = info.poolDaiBalanceInWei;
    }
}
