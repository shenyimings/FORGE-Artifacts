// SPDX-License-Identifier: GPL-3.0
// solhint-disable not-rely-on-time
// solhint-disable reason-string
pragma solidity ^0.8.20;

import {APower} from "./APower.sol";
import {XPower} from "./XPower.sol";
import {XPowerPpt} from "./XPowerPpt.sol";

import {Array} from "./libs/Array.sol";
import {Constants} from "./libs/Constants.sol";
import {Integrator} from "./libs/Integrator.sol";
import {Polynomial, Polynomials} from "./libs/Polynomials.sol";
import {Power} from "./libs/Power.sol";
import {Rpp} from "./libs/Rpp.sol";
import {MoeTreasurySupervised} from "./base/Supervised.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * Treasury to mint (SoV) tokens for staked XPowerNft(s).
 */
contract MoeTreasury is MoeTreasurySupervised {
    using Integrator for Integrator.Item[];
    using Polynomials for Polynomial;

    /** (burnable) proof-of-work tokens */
    XPower private _moe;
    /** (burnable) *aged* XPower tokens */
    APower private _sov;
    /** staked proof-of-work NFTs */
    XPowerPpt private _ppt;

    /** map of rewards claimed: account => nft-id => amount */
    mapping(address => mapping(uint256 => uint256)) private _claimed;
    /** map of rewards minted: account => nft-id => amount */
    mapping(address => mapping(uint256 => uint256)) private _minted;

    /** @param moeLink address of contract for XPower tokens */
    /** @param sovLink address of contract for APower tokens */
    /** @param pptLink address of contract for staked NFTs */
    constructor(address moeLink, address sovLink, address pptLink) {
        _moe = XPower(moeLink);
        _sov = APower(sovLink);
        _ppt = XPowerPpt(pptLink);
    }

    /** @return minted amount */
    function minted(
        address account,
        uint256 nftId
    ) public view returns (uint256) {
        return _minted[account][nftId];
    }

    /** @return minted amounts */
    function mintedBatch(
        address account,
        uint256[] memory nftIds
    ) public view returns (uint256[] memory) {
        uint256[] memory mintedRewards = new uint256[](nftIds.length);
        for (uint256 i = 0; i < nftIds.length; i++) {
            mintedRewards[i] = minted(account, nftIds[i]);
        }
        return mintedRewards;
    }

    /** @return mintable amount */
    function mintable(
        address account,
        uint256 nftId
    ) public view returns (uint256) {
        return _sov.mintable(claimable(account, nftId));
    }

    /** @return mintable amounts */
    function mintableBatch(
        address account,
        uint256[] memory nftIds
    ) public view returns (uint256[] memory) {
        return _sov.mintableBatch(claimableBatch(account, nftIds));
    }

    /** emitted on claiming NFT reward */
    event Claim(address account, uint256 nftId, uint256 amount);

    /** claim APower tokens */
    function claim(address account, uint256 nftId) external {
        uint256 amount = claimable(account, nftId);
        require(amount > 0, "nothing claimable");
        _claimed[account][nftId] += amount;
        _minted[account][nftId] += _sov.mintable(amount);
        _moe.increaseAllowance(address(_sov), _sov.wrappable(amount));
        _sov.mint(account, amount);
        emit Claim(account, nftId, amount);
    }

    /** emitted on claiming NFT rewards */
    event ClaimBatch(address account, uint256[] nftIds, uint256[] amounts);

    /** claim APower tokens */
    function claimBatch(address account, uint256[] memory nftIds) external {
        require(Array.unique(nftIds), "unsorted or duplicate ids");
        uint256[] memory amounts = claimableBatch(account, nftIds);
        for (uint256 i = 0; i < nftIds.length; i++) {
            require(amounts[i] > 0, "nothing claimable");
            _claimed[account][nftIds[i]] += amounts[i];
            _minted[account][nftIds[i]] += _sov.mintable(amounts[i]);
            _moe.increaseAllowance(address(_sov), _sov.wrappable(amounts[i]));
            _sov.mint(account, amounts[i]);
        }
        emit ClaimBatch(account, nftIds, amounts);
    }

    /** @return claimed amount */
    function claimed(
        address account,
        uint256 nftId
    ) public view returns (uint256) {
        return _claimed[account][nftId];
    }

    /** @return claimed amounts */
    function claimedBatch(
        address account,
        uint256[] memory nftIds
    ) public view returns (uint256[] memory) {
        uint256[] memory claimedRewards = new uint256[](nftIds.length);
        for (uint256 i = 0; i < nftIds.length; i++) {
            claimedRewards[i] = claimed(account, nftIds[i]);
        }
        return claimedRewards;
    }

    /** @return claimable amount */
    function claimable(
        address account,
        uint256 nftId
    ) public view returns (uint256) {
        uint256 claimedReward = claimed(account, nftId);
        uint256 generalReward = rewardOf(account, nftId);
        if (generalReward > claimedReward) {
            return generalReward - claimedReward;
        }
        return 0;
    }

    /** @return claimable amounts */
    function claimableBatch(
        address account,
        uint256[] memory nftIds
    ) public view returns (uint256[] memory) {
        uint256[] memory claimedRewards = claimedBatch(account, nftIds);
        uint256[] memory generalRewards = rewardOfBatch(account, nftIds);
        uint256[] memory pendingRewards = new uint256[](nftIds.length);
        for (uint256 i = 0; i < nftIds.length; i++) {
            if (generalRewards[i] > claimedRewards[i]) {
                pendingRewards[i] = generalRewards[i] - claimedRewards[i];
            }
        }
        return pendingRewards;
    }

    /** @return reward amount */
    function rewardOf(
        address account,
        uint256 nftId
    ) public view returns (uint256) {
        uint256 age = _ppt.ageOf(account, nftId);
        uint256 rate = aprOf(nftId) + apbOf(nftId);
        uint256 denomination = _ppt.denominationOf(_ppt.levelOf(nftId));
        return Math.mulDiv(
            rate * age * 10 ** _moe.decimals(),
            denomination, 1e6 * Constants.CENTURY
        );
    }

    /** @return reward amounts */
    function rewardOfBatch(
        address account,
        uint256[] memory nftIds
    ) public view returns (uint256[] memory) {
        uint256[] memory rewards = new uint256[](nftIds.length);
        for (uint256 i = 0; i < nftIds.length; i++) {
            rewards[i] = rewardOf(account, nftIds[i]);
        }
        return rewards;
    }

    /** integrator for APRs: nft-id => [(stamp, value)] */
    mapping(uint256 => Integrator.Item[]) public aprs;
    /** parametrization of APR: nft-id => coefficients */
    mapping(uint256 => uint256[]) private _apr;

    /** @return length of APRs */
    function aprsLength(uint256 nftId) external view returns (uint256) {
        uint256 id = _aprId(nftId);
        return aprs[id].length;
    }

    /** @return duration weighted mean of APRs */
    function aprOf(uint256 nftId) public view returns (uint256) {
        uint256 rate = aprTargetOf(nftId);
        uint256 id = _aprId(nftId);
        if (aprs[id].length > 0) {
            return aprs[id].meanOf(block.timestamp, rate);
        }
        return rate;
    }

    /** @return target for annualized percentage rate */
    function aprTargetOf(uint256 nftId) public view returns (uint256) {
        return aprTargetOf(nftId, getAPR(nftId));
    }

    /** @return target for annualized percentage rate */
    function aprTargetOf(
        uint256 nftId,
        uint256[] memory array
    ) private view returns (uint256) {
        uint256 rate = Polynomial(array).eval3(_ppt.levelOf(nftId));
        uint256 base = Power.raise(1e6, array[array.length - 1]);
        return Math.mulDiv(rate, 1e6, base);
    }

    /** annual percentage rate: 3.375000[%] (per nft.level) */
    uint256 public constant APR_MUL = 3_375_000;
    uint256 private constant APR_DIV = 3;
    uint256 private constant APR_EXP = 256;

    /** @return APR parameters */
    function getAPR(uint256 nftId) public view returns (uint256[] memory) {
        uint256 id = _aprId(nftId);
        if (_apr[id].length > 0) {
            return _apr[id];
        }
        uint256[] memory array = new uint256[](4);
        array[1] = APR_DIV;
        array[2] = APR_MUL;
        array[3] = APR_EXP;
        return array;
    }

    /** set APR parameters */
    function setAPR(
        uint256 nftId,
        uint256[] memory array
    ) public onlyRole(APR_ROLE) {
        Rpp.checkArray(array);
        // fixed nft-id as anchor
        uint256 id = _aprId(nftId);
        // check APR reparametrization of value (rate)
        uint256 nextRate = aprTargetOf(id, array);
        uint256 currRate = aprTargetOf(id);
        Rpp.checkValue(nextRate, currRate, 1e6);
        // check APR reparametrization of value (mean)
        uint256 nextMean = _aprMeanOf(array);
        uint256 currMean = _aprMeanOf(_apr[id]);
        Rpp.checkValue(nextMean, currMean, APR_MUL);
        // check APR reparametrization of stamp
        Integrator.Item memory last = aprs[id].lastOf("S");
        Rpp.checkStamp(block.timestamp, last.stamp);
        // append (stamp, apr-of[nft-id]) to integrator
        aprs[id].append(block.timestamp, currRate, "S");
        // all requirements satisfied: use array
        _apr[id] = array;
    }

    /** @return mean of annualized percentage rate */
    function _aprMeanOf(uint256[] memory array) private pure returns (uint256) {
        return array.length > 2 ? array[2] : APR_MUL;
    }

    /** batch-set APR parameters */
    function setAPRBatch(
        uint256[] memory nftIds,
        uint256[] memory array
    ) external onlyRole(APR_ROLE) {
        for (uint256 i = 0; i < nftIds.length; i++) {
            setAPR(nftIds[i], array);
        }
    }

    /** emitted on refreshing APR parameters */
    event RefreshRates(bool allLevels);

    /** refresh APR parameters */
    function refreshRates(bool allLevels) external {
        int256[34] memory shares = _ppt.shares();
        (uint256 bins, uint256 sum, uint256 max) = _moments(shares);
        uint256 maxLength = allLevels ? shares.length : max;
        for (uint256 i = 0; i < maxLength; i++) {
            uint256 id = _ppt.idBy(2021, 3 * i);
            Integrator.Item memory item = aprs[id].lastOf();
            uint256 target = aprTargetOf(id);
            if (item.stamp == 0) {
                aprs[id].append(block.timestamp - Constants.MONTH, target);
                aprs[id].append(block.timestamp, target); // laggy init
            } else if (item.value != target) {
                aprs[id].append(block.timestamp, target);
            }
            if (shares[i] > 0) {
                if (_apr[id].length == 0) {
                    _apr[id] = new uint256[](4); // [add, div, mul, exp]
                    _apr[id][0] = _scalar(APR_MUL, sum, bins, shares[i]);
                    _apr[id][1] = type(uint256).max; // div-by-infinity
                    _apr[id][2] = APR_MUL;
                    _apr[id][3] = APR_EXP;
                } else {
                    _apr[id][0] = _scalar(_apr[id][2], sum, bins, shares[i]);
                    _apr[id][1] = type(uint256).max; // div-by-infinity
                }
            } else if (_apr[id].length > 0) {
                _apr[id][0] = 0; // clear
                _apr[id][1] = APR_DIV;
            }
        }
        emit RefreshRates(allLevels);
    }

    /** @return refreshable flag */
    function refreshable() external view returns (bool) {
        int256[34] memory shares = _ppt.shares();
        (uint256 bins, uint256 sum, ) = _moments(shares);
        for (uint256 i = 0; i < shares.length; i++) {
            uint256 id = _ppt.idBy(2021, 3 * i);
            Integrator.Item memory item = aprs[id].lastOf();
            if (item.stamp == 0) {
                return true;
            }
            if (shares[i] > 0) {
                if (_apr[id].length == 0) {
                    return true;
                }
                if (_apr[id][0] != _scalar(_apr[id][2], sum, bins, shares[i])) {
                    return true;
                }
                if (_apr[id][1] != type(uint256).max) {
                    return true;
                }
            } else if (_apr[id].length > 0) {
                if (_apr[id][0] != 0) {
                    return true;
                }
                if (_apr[id][1] != APR_DIV) {
                    return true;
                }
            }
        }
        return false;
    }

    /** @return moments of (bins, sum, max) */
    function _moments(
        int256[34] memory shares
    ) private pure returns (uint256, uint256, uint256) {
        (uint256 bins, uint256 sum, uint256 max) = (0, 0, 0);
        for (uint256 i = 0; i < shares.length; i++) {
            if (shares[i] > 0) {
                sum += uint256(shares[i]);
                max = i + 1;
                bins++;
            }
        }
        return (bins, sum, max);
    }

    /** @return additive scalar */
    function _scalar(
        uint256 mul,
        uint256 sum,
        uint256 bins,
        int256 share
    ) private pure returns (uint256) {
        assert(bins > 0 && share > 0); // no div-by-zero
        return Math.mulDiv(mul, sum, bins * uint256(share));
    }

    /** @return apr-id */
    function _aprId(uint256 nftId) private view returns (uint256) {
        return _ppt.idBy(2021, _ppt.levelOf(nftId));
    }

    /** integrator for APBs: nft-id => [(stamp, value)] */
    mapping(uint256 => Integrator.Item[]) public apbs;
    /** parametrization of APB: nft-id => coefficients */
    mapping(uint256 => uint256[]) private _apb;

    /** @return length fo APBs (for nft-id) */
    function apbsLength(uint256 nftId) external view returns (uint256) {
        uint256 id = _apbId(nftId);
        return apbs[id].length;
    }

    /** @return duration weighted mean of APBs (per nft.level) */
    function apbOf(uint256 nftId) public view returns (uint256) {
        uint256 rate = apbTargetOf(nftId);
        uint256 id = _apbId(nftId);
        if (apbs[id].length > 0) {
            return apbs[id].meanOf(block.timestamp, rate);
        }
        return rate;
    }

    /** @return target for annualized percentage rate bonus */
    function apbTargetOf(uint256 nftId) public view returns (uint256) {
        return apbTargetOf(nftId, getAPB(nftId));
    }

    /** @return target for annualized percentage rate bonus */
    function apbTargetOf(
        uint256 nftId,
        uint256[] memory array
    ) private view returns (uint256) {
        uint256 nowYear = _ppt.year();
        uint256 nftYear = _ppt.yearOf(nftId);
        if (nowYear > nftYear || nowYear == nftYear) {
            uint256 rate = Polynomial(array).eval3(nowYear - nftYear);
            uint256 base = Power.raise(1e6, array[array.length - 1]);
            return Math.mulDiv(rate, 1e6, base);
        }
        return 0;
    }

    /** annual percentage bonus: 1.0000[â€±] (per nft.year) */
    uint256 private constant APB_MUL = 10_000;
    uint256 private constant APB_DIV = 1;
    uint256 private constant APB_EXP = 256;

    /** @return APB parameters */
    function getAPB(uint256 nftId) public view returns (uint256[] memory) {
        uint256 id = _apbId(nftId);
        if (_apb[id].length > 0) {
            return _apb[id];
        }
        uint256[] memory array = new uint256[](4);
        array[1] = APB_DIV;
        array[2] = APB_MUL;
        array[3] = APB_EXP;
        return array;
    }

    /** set APB parameters */
    function setAPB(
        uint256 nftId,
        uint256[] memory array
    ) public onlyRole(APB_ROLE) {
        Rpp.checkArray(array);
        // fixed nft-id as anchor
        uint256 id = _apbId(nftId);
        // check APB reparametrization of value
        uint256 nextRate = apbTargetOf(id, array);
        uint256 currRate = apbTargetOf(id);
        Rpp.checkValue(nextRate, currRate, 1e6);
        // check APB reparametrization of stamp
        Integrator.Item memory last = apbs[id].lastOf();
        Rpp.checkStamp(block.timestamp, last.stamp);
        // append (stamp, apb-of[nft-id]) to integrator
        apbs[id].append(block.timestamp, currRate);
        // all requirements satisfied: use array
        _apb[id] = array;
    }

    /** batch-set APB parameters */
    function setAPBBatch(
        uint256[] memory nftIds,
        uint256[] memory array
    ) external onlyRole(APB_ROLE) {
        for (uint256 i = 0; i < nftIds.length; i++) {
            setAPB(nftIds[i], array);
        }
    }

    /** @return apb-id */
    function _apbId(uint256) private view returns (uint256) {
        return _ppt.idBy(2021, 3);
    }
}
