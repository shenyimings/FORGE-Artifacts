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

import "../interfaces/IPriceFeed.sol";
import "../interfaces/IAccessControlConfig.sol";

// SimplePriceFeed is intended to be used for unit test only
contract SimplePriceFeed is PausableUpgradeable, AccessControlUpgradeable, IPriceFeed {
  IAccessControlConfig public accessControlConfig;

  uint256 public price;
  uint256 public lastUpdate;

  uint256 public priceLife;

  // --- Init ---
  function initialize(address _accessControlConfig) external initializer {
    PausableUpgradeable.__Pausable_init();
    AccessControlUpgradeable.__AccessControl_init();

    priceLife = 1 days; // [seconds] how old the price is considered stale, default 1 day

    accessControlConfig = IAccessControlConfig(_accessControlConfig);
  }

  modifier onlyOwner() {
    require(accessControlConfig.hasRole(accessControlConfig.OWNER_ROLE(), msg.sender), "!ownerRole");
    _;
  }

  event LogSetPrice(address indexed _caller, uint256 _price, uint256 indexed _lastUpdate);
  event LogSetPriceLife(address indexed _caller, uint256 _second);

  function setPrice(uint256 _price) external onlyOwner {
    price = _price;
    lastUpdate = now;
    emit LogSetPrice(msg.sender, price, lastUpdate);
  }

  function setPriceLife(uint256 _second) external onlyOwner {
    priceLife = _second;
    emit LogSetPriceLife(msg.sender, _second);
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  function readPrice() external view override returns (bytes32) {
    return bytes32(price);
  }

  function peekPrice() external view override returns (bytes32, bool) {
    return (bytes32(price), _isPriceOk());
  }

  function _isPriceFresh() internal view returns (bool) {
    // solhint-disable not-rely-on-time
    return lastUpdate >= now - priceLife;
  }

  function _isPriceOk() internal view returns (bool) {
    return _isPriceFresh() && !paused();
  }
}
