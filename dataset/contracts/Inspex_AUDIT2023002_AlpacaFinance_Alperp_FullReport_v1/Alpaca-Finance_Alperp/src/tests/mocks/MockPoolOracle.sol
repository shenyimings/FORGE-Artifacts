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

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MockPoolOracle is Ownable {
  mapping(address => uint256) public maxPrices;
  mapping(address => uint256) public minPrices;
  uint80 public roundDepth;

  function feedMinPrice(address token, uint256 price) external {
    minPrices[token] = price;
  }

  function feedMaxPrice(address token, uint256 price) external {
    maxPrices[token] = price;
  }

  function getMaxPrice(address token) external view returns (uint256) {
    return maxPrices[token];
  }

  function getMinPrice(address token) external view returns (uint256) {
    return minPrices[token];
  }

  function getPrice(address token, bool isUseMaxPrice)
    external
    view
    returns (uint256)
  {
    if (isUseMaxPrice) {
      return maxPrices[token];
    } else {
      return minPrices[token];
    }
  }
}
