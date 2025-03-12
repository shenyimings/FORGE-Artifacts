// SPDX-License-Identifier: GPL-3.0
// solhint-disable no-empty-blocks
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {XPower} from "./XPower.sol";
import {SovMigratable} from "./base/Migratable.sol";

/**
 * Class for the APOW tokens, where only the owner of the contract i.e. the
 * MoeTreasury is entitled to mint them -- with a supply rate of on average
 * one token per minute.
 */
contract APower is ERC20, ERC20Burnable, SovMigratable, Ownable {
    /** timestamp of contract deployment (absolute) */
    uint256 private _timestamp = block.timestamp;
    /** timestamp of last mean (relative) */
    uint256 private _time;
    /** last mean of claims */
    uint256 private _mean;
    /** (burnable) XPower */
    XPower private _moe;

    /** @param moeLink address of XPower tokens */
    /** @param sovBase address of old contract */
    /** @param deadlineIn seconds to end-of-migration */
    constructor(
        address moeLink,
        address[] memory sovBase,
        uint256 deadlineIn
    )
        // ERC20 constructor: name, symbol
        ERC20("APower", "APOW")
        // Migratable: XPower, old APower & rel. deadline [seconds]
        SovMigratable(moeLink, sovBase, deadlineIn)
    {
        _moe = XPower(moeLink);
    }

    /** @return number of decimals of representation */
    function decimals() public view virtual override returns (uint8) {
        return _moe.decimals();
    }

    /** mint on average one APower/min (after wrapping XPower) */
    function mint(address to, uint256 claim) external onlyOwner {
        assert(_moe.transferFrom(owner(), address(this), wrappable(claim)));
        (uint256 a, uint256 m, uint256 t) = _mintable(claim, _mean, _time);
        (_mean, _time) = (m, t);
        _mint(to, a);
    }

    /** @return wrappable XPower targeting a ratio of 1:1 (at most) */
    function wrappable(uint256 claim) public view returns (uint256) {
        uint256 treasury = _moe.balanceOf(owner());
        return Math.min(claim, treasury);
    }

    /** @return mintable APower w.r.t. long-term mean of claims */
    function mintable(uint256 claim) external view returns (uint256) {
        (uint256 a, , ) = _mintable(claim, _mean, _time);
        return a;
    }

    /** @return mintable APower w.r.t. long-term mean of claims */
    function mintableBatch(
        uint256[] memory claims
    ) external view returns (uint256[] memory) {
        (uint256 mean, uint256 time) = (_mean, _time);
        uint256[] memory mintables = new uint256[](claims.length);
        for (uint256 i = 0; i < claims.length; i++) {
            (uint256 a, uint256 m, uint256 t) = _mintable(
                claims[i],
                mean,
                time
            );
            (mean, time) = (m, t);
            mintables[i] = a;
        }
        return mintables;
    }

    function _mintable(
        uint256 claim,
        uint256 mean,
        uint256 time
    ) private view returns (uint256, uint256, uint256) {
        if (claim > 0) {
            uint256 t = block.timestamp - _timestamp;
            uint256 m = Math.mulDiv(mean, time, t) + claim / t;
            uint256 a = Math.mulDiv(claim, 10 ** decimals() / 60, m);
            return (a, m, t);
        }
        return (0, mean, time);
    }

    /** burn amount of tokens from caller (and then unwrap XPower) */
    function burn(uint256 amount) public override {
        super.burn(amount);
        _moe.transfer(msg.sender, unwrappable(amount));
    }

    /**
     * burn amount of tokens from account, deducting from the caller's
     * allowance (and then unwrap XPower)
     */
    function burnFrom(address account, uint256 amount) public override {
        super.burnFrom(account, amount);
        _moe.transfer(account, unwrappable(amount));
    }

    /** @return unwrappable XPower proportional to burned APower amount */
    function unwrappable(uint256 amount) public view returns (uint256) {
        uint256 balance = _moe.balanceOf(address(this));
        uint256 supply = amount + totalSupply();
        if (supply > 0) {
            return Math.mulDiv(balance, amount, supply);
        }
        return 0;
    }

    /** @return APOW to XPOW conversion: 1e18 ~ 100% */
    function metric() external view returns (uint256) {
        uint256 balance = _moe.balanceOf(address(this));
        uint256 supply = totalSupply();
        if (supply > 0) {
            return Math.mulDiv(10 ** decimals(), balance, supply);
        }
        return 0;
    }
}
