// SPDX-License-Identifier: AGPL-3.0-or-later
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

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "@alpaca-finance/alpaca-contract/contracts/6/protocol/apis/pancakeV2/PancakeLibraryV2.sol";
import "../interfaces/IAlpacaOracle.sol";

contract DexPriceOracle is PausableUpgradeable, IAlpacaOracle {
  using SafeMathUpgradeable for uint256;
  address public dexFactory;

  struct PriceData {
    uint192 price;
    uint64 lastUpdate;
  }

  function initialize(address _dexFactory) external initializer {
    dexFactory = _dexFactory;
  }

  /// @dev Return the wad price of token0/token1, multiplied by 1e18
  /// NOTE: (if you have 1 token0 how much you can sell it for token1)
  function getPrice(address token0, address token1) external view override returns (uint256, uint256) {
    if (token0 == token1) return (1e18, uint64(now));

    (uint256 r0, uint256 r1) = PancakeLibraryV2.getReserves(dexFactory, token0, token1);
    uint256 price = r0.mul(1e18).div(r1);
    return (price, uint64(now));
  }
}
