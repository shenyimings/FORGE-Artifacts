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
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract ALP is ERC20Upgradeable, OwnableUpgradeable {
  mapping(address => bool) public whitelist;
  mapping(address => uint256) public cooldown;
  mapping(address => bool) public isMinter;
  uint256 public MAX_COOLDOWN_DURATION;
  uint256 public liquidityCooldown;

  event ALP_SetWhitelist(address whitelisted, bool isActive);
  event ALP_SetMinter(address minter, bool prevAllow, bool newAllow);
  event ALP_SetLiquidityCooldown(uint256 oldCooldown, uint256 newCooldown);

  error ALP_BadLiquidityCooldown(uint256 cooldown);
  error ALP_Cooldown(uint256 cooldownExpireAt);
  error ALP_NotMinter();

  modifier onlyMinter() {
    if (!isMinter[msg.sender]) revert ALP_NotMinter();
    _;
  }

  function initialize(uint256 liquidityCooldown_) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ERC20Upgradeable.__ERC20_init("Alperp Liquidity Provider", "ALP");

    MAX_COOLDOWN_DURATION = 48 hours;
    liquidityCooldown = liquidityCooldown_;
  }

  function setLiquidityCooldown(uint256 newLiquidityCooldown)
    external
    onlyOwner
  {
    if (newLiquidityCooldown > MAX_COOLDOWN_DURATION)
      revert ALP_BadLiquidityCooldown(newLiquidityCooldown);
    uint256 oldCooldown = liquidityCooldown;
    liquidityCooldown = newLiquidityCooldown;
    emit ALP_SetLiquidityCooldown(oldCooldown, newLiquidityCooldown);
  }

  function setWhitelist(address whitelisted, bool isActive) external onlyOwner {
    whitelist[whitelisted] = isActive;

    emit ALP_SetWhitelist(whitelisted, isActive);
  }

  function setMinter(address minter, bool allow) external onlyOwner {
    isMinter[minter] = allow;
    emit ALP_SetMinter(minter, isMinter[minter], allow);
  }

  function mint(address to, uint256 amount) public onlyMinter {
    cooldown[to] = block.timestamp + liquidityCooldown;
    _mint(to, amount);
  }

  function burn(address from, uint256 amount) public onlyMinter {
    _burn(from, amount);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal view override {
    if (whitelist[from] || whitelist[to]) return;

    uint256 cooldownExpireAt = cooldown[from];
    if (amount > 0 && block.timestamp < cooldownExpireAt)
      revert ALP_Cooldown(cooldownExpireAt);
  }
}
