// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import { IYieldSource } from "@pooltogether/yield-source-interface/contracts/IYieldSource.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./ISushiBar.sol";
import "./ISushi.sol";

/// @title An pooltogether yield source for sushi token
/// @author Steffel Fenix
contract SushiYieldSource is IYieldSource {
    using SafeMath for uint256;
    address public sushiBar;
    address public sushiAddr;
    mapping(address => uint256) public balances;

    constructor(address _sushiBar, address _sushiAddr) public {
        sushiBar = _sushiBar;
        sushiAddr = _sushiAddr;
    }

    /// @notice Returns the ERC20 asset token used for deposits.
    /// @return The ERC20 asset token
    function depositToken() public view override returns (address) {
        return (sushiAddr);
    }

    /// @notice Returns the total balance (in asset tokens).  This includes the deposits and interest.
    /// @return The underlying balance of asset tokens
    function balanceOfToken(address addr) public override returns (uint256) {
        if (balances[addr] == 0) return 0;
        ISushiBar bar = ISushiBar(sushiBar);

        uint256 shares = bar.balanceOf(address(this));
        uint256 totalShares = bar.totalSupply();

        uint256 sushiBalance =
            shares.mul(ISushi(sushiAddr).balanceOf(address(sushiBar))).div(
                totalShares
            );
        uint256 sourceShares = bar.balanceOf(address(this));

        return (balances[addr].mul(sushiBalance).div(sourceShares));
    }

    /// @notice Allows assets to be supplied on other user's behalf using the `to` param.
    /// @param amount The amount of `token()` to be supplied
    /// @param to The user whose balance will receive the tokens
    function supplyTokenTo(uint256 amount, address to) public override {
        ISushi(sushiAddr).transferFrom(msg.sender, address(this), amount);
        ISushi(sushiAddr).approve(sushiBar, amount);

        ISushiBar bar = ISushiBar(sushiBar);
        uint256 beforeBalance = bar.balanceOf(address(this));
        bar.enter(amount);
        uint256 afterBalance = bar.balanceOf(address(this));
        uint256 balanceDiff = afterBalance.sub(beforeBalance);
        balances[to] = balances[to].add(balanceDiff);
    }

    /// @notice Redeems tokens from the yield source from the msg.sender, it burn yield bearing tokens and return token to the sender.
    /// @param amount The amount of `token()` to withdraw.  Denominated in `token()` as above.
    /// @return The actual amount of tokens that were redeemed.
    function redeemToken(uint256 amount) public override returns (uint256) {
        ISushiBar bar = ISushiBar(sushiBar);
        ISushi sushi = ISushi(sushiAddr);

        uint256 totalShares = bar.totalSupply();
        uint256 barSushiBalance = sushi.balanceOf(address(bar));
        uint256 requiredShares = amount.mul(totalShares).div(barSushiBalance);

        uint256 barBeforeBalance = bar.balanceOf(address(this));
        uint256 sushiBeforeBalance = sushi.balanceOf(address(this));

        bar.leave(requiredShares);

        uint256 barAfterBalance = bar.balanceOf(address(this));
        uint256 sushiAfterBalance = sushi.balanceOf(address(this));

        uint256 barBalanceDiff = barBeforeBalance.sub(barAfterBalance);
        uint256 sushiBalanceDiff = sushiAfterBalance.sub(sushiBeforeBalance);

        balances[msg.sender] = balances[msg.sender].sub(barBalanceDiff);
        sushi.transfer(msg.sender, sushiBalanceDiff);
        return (sushiBalanceDiff);
    }
}
