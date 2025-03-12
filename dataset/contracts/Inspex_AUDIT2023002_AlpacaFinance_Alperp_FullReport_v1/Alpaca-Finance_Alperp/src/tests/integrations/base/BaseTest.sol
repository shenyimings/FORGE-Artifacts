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

import { VM } from "../../utils/VM.sol";
import "../../base/DSTest.sol";

import "./Config.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

abstract contract BaseTest is DSTest, Config {
  /// @dev Accounts
  address public constant ALICE = address(111);
  address public constant BOB = address(112);
  address public constant CAT = address(113);
  address public constant EVE = address(114);
  uint256 public constant PRICE_PRECISION = 10**30;
  uint256 public constant BPS = 10000;

  VM internal constant vm = VM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

  function setUp() public virtual {}
}
