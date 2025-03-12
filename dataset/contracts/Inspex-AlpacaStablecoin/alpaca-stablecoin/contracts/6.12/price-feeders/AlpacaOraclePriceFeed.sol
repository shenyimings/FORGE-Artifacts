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

import "../interfaces/IPriceFeed.sol";
import "../interfaces/IAlpacaOracle.sol";
import "../interfaces/IAccessControlConfig.sol";

contract AlpacaOraclePriceFeed is PausableUpgradeable, IPriceFeed {
  IAlpacaOracle public alpacaOracle;
  IAccessControlConfig public accessControlConfig;
  address public token0;
  address public token1;
  uint256 public priceLife; // [seconds] how old the price is considered stale, default 1 day

  // --- Init ---
  function initialize(
    address _alpacaOracle,
    address _token0,
    address _token1,
    address _accessControlConfig
  ) external initializer {
    PausableUpgradeable.__Pausable_init();

    accessControlConfig = IAccessControlConfig(_accessControlConfig);

    alpacaOracle = IAlpacaOracle(_alpacaOracle);
    token0 = _token0;
    token1 = _token1;
    priceLife = 1 days;
  }

  modifier onlyOwner() {
    require(accessControlConfig.hasRole(accessControlConfig.OWNER_ROLE(), msg.sender), "!ownerRole");
    _;
  }

  event LogSetPriceLife(address indexed _caller, uint256 _second);

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
    (uint256 _price, ) = alpacaOracle.getPrice(token0, token1);
    return bytes32(_price);
  }

  function peekPrice() external view override returns (bytes32, bool) {
    // [wad], [seconds]
    (uint256 _price, uint256 _lastUpdate) = alpacaOracle.getPrice(token0, token1);
    return (bytes32(_price), _isPriceOk(_lastUpdate));
  }

  function _isPriceFresh(uint256 _lastUpdate) internal view returns (bool) {
    // solhint-disable not-rely-on-time
    return _lastUpdate >= now - priceLife;
  }

  function _isPriceOk(uint256 _lastUpdate) internal view returns (bool) {
    return _isPriceFresh(_lastUpdate) && !paused();
  }
}
