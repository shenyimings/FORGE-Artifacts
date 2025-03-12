// SPDX-License-Identifier: MIT
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/

pragma solidity 0.8.17;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockDonateVault - For testing purpuse only. DO NOT USE IN PROD.
contract MockDonateVault is ERC20("Some Lending Token", "SLT") {
  address public underlying;

  constructor(address underlying_) {
    underlying = underlying_;
  }

  function deposit(uint256 amount) external {
    ERC20(underlying).transferFrom(msg.sender, address(this), amount);
    uint256 shares = totalSupply() == 0
      ? amount
      : (amount * totalSupply()) / ERC20(underlying).balanceOf(address(this));
    _mint(msg.sender, shares);
  }

  function withdraw(uint256 shares) external {
    uint256 amount = (shares * ERC20(underlying).balanceOf(address(this))) /
      totalSupply();
    _burn(msg.sender, shares);
    ERC20(underlying).transfer(msg.sender, amount);
  }

  function shareToValue(uint256 shares) external view returns (uint256) {
    uint256 _totalSupply = totalSupply();
    return
      _totalSupply == 0
        ? shares
        : (shares * ERC20(underlying).balanceOf(address(this))) / _totalSupply;
  }

  function valueToShare(uint256 value) external view returns (uint256) {
    uint256 underlyingBalance = ERC20(underlying).balanceOf(address(this));
    return
      underlyingBalance == 0
        ? value
        : (value * totalSupply()) / underlyingBalance;
  }

  function totalToken() public view virtual returns (uint256) {
    return ERC20(underlying).balanceOf(address(this));
  }
}
