pragma solidity ^0.5.12;
pragma experimental ABIEncoderV2;

import { BCdpManager } from "./../BCdpManager.sol";
import { BCdpScore } from "./../BCdpScore.sol";
import { LiquidationMachine } from "./../LiquidationMachine.sol";
import { DssCdpManager } from "./../DssCdpManager.sol";
import { GetCdps } from "./../GetCdps.sol";
import { Math } from "./../Math.sol";


contract VatLike {
    function urns(bytes32 ilk, address u) public view returns (uint ink, uint art);
    function ilks(bytes32 ilk) public view returns(uint Art, uint rate, uint spot, uint line, uint dust);
    function gem(bytes32 ilk, address user) external view returns(uint);
}

contract DSProxyLike {
    function owner() public view returns(address);
}

contract ProxyRegistryLike {
    function proxies(address u) public view returns(DSProxyLike);
}

contract SpotLike {
    function par() external view returns (uint256);
    function ilks(bytes32 ilk) external view returns (address pip, uint mat);
}

contract ERC20Like {
    function balanceOf(address guy) public view returns(uint);
    function allowance(address owner, address spender) public view returns (uint);
}

contract JarConnectorLike {
    function getUserScore(bytes32 user) external view returns (uint);
    function getGlobalScore() external view returns (uint);
}

contract JarLike {
    function connector() external view returns (address);
}

contract GemJoinLike {
    function dec() external view returns(uint);
    function gem() external view returns(address);
}

// this is just something to help avoiding solidity quirks
contract UserInfoStorage {
    struct ProxyInfo {
        bool hasProxy;
        DSProxyLike userProxy;
    }

    struct CdpInfo {
        bool hasCdp;
        bool bitten;
        uint cdp;
        uint ethDeposit;
        uint daiDebt; // in wad - not in rad
        uint maxDaiDebt;
        uint unlockedEth;
        bool expectedDebtMissmatch;
    }

    struct MiscInfo {
        uint spotPrice;
        uint dustInWei;
        uint blockNumber;
        uint gemDecimals;
    }

    struct UserWalletInfo {
        uint ethBalance;
        uint gemBalance;
        uint gemAllowance;
        uint daiBalance;
        uint daiAllowance;
    }

    struct UserState {
        ProxyInfo proxyInfo;
        CdpInfo bCdpInfo;
        CdpInfo makerdaoCdpInfo;
        MiscInfo miscInfo;
        UserWalletInfo userWalletInfo;
    }

    UserState userState;

    bool public hasProxy;
    address public userProxy;

    // CdpInfo of B
    bool public hasCdp;
    bool public bitten;
    uint public cdp;
    uint public ethDeposit;
    uint public daiDebt; // in wad - not in rad
    uint public maxDaiDebt;
    uint public unlockedEth;
    bool public expectedDebtMissmatch;

    // CdpInfo of Mkr
    bool public makerdaoHasCdp;
    uint public makerdaoCdp;
    uint public makerdaoEthDeposit;
    uint public makerdaoDaiDebt; // in wad - not in rad
    uint public makerdaoMaxDaiDebt;

    uint public spotPrice;
    uint public dustInWei;
    uint public blockNumber;
    uint public gemDecimals;

    uint public ethBalance;
    uint public gemBalance;
    uint public gemAllowance; 
    uint public daiBalance;
    uint public daiAllowance;

    function set(UserState memory state) public {
        hasProxy = state.proxyInfo.hasProxy;
        userProxy = address(state.proxyInfo.userProxy);

        hasCdp = state.bCdpInfo.hasCdp;
        bitten = state.bCdpInfo.bitten;
        cdp = state.bCdpInfo.cdp;
        ethDeposit = state.bCdpInfo.ethDeposit;
        daiDebt = state.bCdpInfo.daiDebt;
        maxDaiDebt = state.bCdpInfo.maxDaiDebt;
        unlockedEth = state.bCdpInfo.unlockedEth;
        expectedDebtMissmatch = state.bCdpInfo.expectedDebtMissmatch;

        makerdaoHasCdp = state.makerdaoCdpInfo.hasCdp;
        makerdaoCdp = state.makerdaoCdpInfo.cdp;
        makerdaoEthDeposit = state.makerdaoCdpInfo.ethDeposit;
        makerdaoDaiDebt = state.makerdaoCdpInfo.daiDebt;
        makerdaoMaxDaiDebt = state.makerdaoCdpInfo.maxDaiDebt;

        spotPrice = state.miscInfo.spotPrice;
        dustInWei = state.miscInfo.dustInWei;
        blockNumber = state.miscInfo.blockNumber;
        gemDecimals = state.miscInfo.gemDecimals;

        ethBalance = state.userWalletInfo.ethBalance;
        gemBalance = state.userWalletInfo.gemBalance;
        gemAllowance = state.userWalletInfo.gemAllowance;
        daiBalance = state.userWalletInfo.daiBalance;
        daiAllowance = state.userWalletInfo.daiAllowance;

        userState = state;
    }
}

contract UserInfo is Math, UserInfoStorage {


    uint constant ONE = 1e27;
    address public dai;
    address public weth;

    constructor(
        address dai_,
        address weth_
    ) public {
        dai = dai_;
        weth = weth_;
    }

    function getFirstCdp(GetCdps getCdp, address manager, address guy, bytes32 ilk) internal view returns(uint) {
        (uint[] memory ids,, bytes32[] memory ilks) = getCdp.getCdpsAsc(manager, guy);

        for(uint i = 0 ; i < ilks.length ; i++) {
            if(ilks[i] == ilk) return ids[i];
        }

        return 0;
    }

    function artToDaiDebt(VatLike vat, bytes32 ilk, uint art) internal view returns(uint) {
        (, uint rate,,,) = vat.ilks(ilk);
        return mul(rate, art) / ONE;
    }

    function calcMaxDebt(VatLike vat, bytes32 ilk, uint ink) internal view returns(uint) {
        (, uint rate, uint spot,,) = vat.ilks(ilk);
        // mul(art, rate) = mul(ink, spot)

        uint maxArt = mul(ink, spot)/rate;
        return artToDaiDebt(vat, ilk, maxArt);
    }

    function calcSpotPrice(VatLike vat, SpotLike spot, bytes32 ilk) internal view returns(uint) {
        (,, uint spotVal,,) = vat.ilks(ilk);
        (, uint mat) = spot.ilks(ilk);
        uint par = spot.par();

        // spotVal = rdiv(rdiv(mul(uint(peep), uint(10 ** 9)), par), mat);
        uint peep = rmul(rmul(spotVal, mat), par) / uint(1e9);

        return peep;
    }

    function getProxyInfo(ProxyRegistryLike registry, address user) public view returns(ProxyInfo memory info) {
        if(registry.proxies(user) == DSProxyLike(0x0) || registry.proxies(user).owner() != user) return info;

        info.hasProxy = true;
        info.userProxy = registry.proxies(user);
    }

    function getCdpInfo(
        address guy,
        address manager,
        bytes32 ilk,
        VatLike vat,
        GetCdps getCdp,
        bool b,
        address gemJoin
    ) public view returns(CdpInfo memory info) {
        uint factor = 10 ** (18 - GemJoinLike(gemJoin).dec()); 
        if(b) {
            // B.Protocol
            info.cdp = getFirstCdp(getCdp, manager, guy, ilk);
            info.hasCdp = info.cdp > 0;
            if(info.hasCdp) {
                (uint ink, uint art) = vat.urns(ilk, DssCdpManager(manager).urns(info.cdp));
                art = add(art, LiquidationMachine(manager).cushion(info.cdp));
                info.bitten = LiquidationMachine(manager).bitten(info.cdp);
                info.ethDeposit = ink / factor;
                info.daiDebt = artToDaiDebt(vat, ilk, art);
                info.maxDaiDebt = calcMaxDebt(vat, ilk, ink);

                info.unlockedEth = vat.gem(ilk, DssCdpManager(manager).urns(info.cdp));
                info.expectedDebtMissmatch = false;
            }
        } else {
            // MakerDAO
            info.cdp = findFirstNonZeroInkCdp(manager, guy, ilk, vat, getCdp);
            info.hasCdp = info.cdp > 0;
            if(info.hasCdp) {
                (uint ink, uint art) = vat.urns(ilk, DssCdpManager(manager).urns(info.cdp));
                info.ethDeposit = ink / factor;
                info.daiDebt = artToDaiDebt(vat, ilk, art);
                info.maxDaiDebt = calcMaxDebt(vat, ilk, ink);
            }
        }
    }

    function findFirstNonZeroInkCdp(
        address manager,
        address guy,
        bytes32 ilk,
        VatLike vat,
        GetCdps getCdp
    ) public view returns (uint) {
        (uint[] memory ids,, bytes32[] memory ilks) = getCdp.getCdpsAsc(manager, guy);
        for(uint i = 0 ; i < ilks.length ; i++) {
            if(ilks[i] == ilk) {
                (uint ink,) = vat.urns(ilk, DssCdpManager(manager).urns(ids[i]));
                if(ink > 0) return ids[i];
            }
        }
        return 0;
    }

    function setInfo(
        address user,
        bytes32 ilk,
        BCdpManager manager,
        DssCdpManager makerDAOManager,
        GetCdps getCdp,
        VatLike vat,
        SpotLike spot,
        ProxyRegistryLike registry,
        address jar,
        address gemJoin
    ) public {
        UserState memory state;

        // fill proxy info
        state.proxyInfo = getProxyInfo(registry, user);

        address guy = address(state.proxyInfo.userProxy);

        // fill bprotocol info
        state.bCdpInfo = getCdpInfo(guy, address(manager), ilk, vat, getCdp, true, gemJoin);

        // fill makerdao info
        state.makerdaoCdpInfo = getCdpInfo(guy, address(makerDAOManager), ilk, vat, getCdp, false, gemJoin);

        state.miscInfo.spotPrice = calcSpotPrice(vat, spot, ilk);
        (,,,, uint dust) = vat.ilks(ilk);
        state.miscInfo.dustInWei = dust / ONE;
        state.miscInfo.blockNumber = block.number;
        state.miscInfo.gemDecimals = GemJoinLike(gemJoin).dec();

        state.userWalletInfo.ethBalance = user.balance;
        state.userWalletInfo.gemBalance = ERC20Like(GemJoinLike(gemJoin).gem()).balanceOf(user);
        state.userWalletInfo.gemAllowance = ERC20Like(GemJoinLike(gemJoin).gem()).allowance(user, guy);        
        state.userWalletInfo.daiBalance = ERC20Like(dai).balanceOf(user);
        state.userWalletInfo.daiAllowance = ERC20Like(dai).allowance(user, guy);

        uint cdp = state.bCdpInfo.cdp;
        address urn = manager.urns(cdp);

        set(state);
    }

    function getInfo(
        address user,
        bytes32 ilk,
        BCdpManager manager,
        DssCdpManager makerDAOManager,
        GetCdps getCdp,
        VatLike vat,
        SpotLike spot,
        ProxyRegistryLike registry,
        address jar,
        address gemJoin
    ) public returns(UserState memory state) {
        setInfo(user, ilk, manager, makerDAOManager, getCdp, vat, spot, registry, jar, gemJoin);
        return userState;
    }
}
