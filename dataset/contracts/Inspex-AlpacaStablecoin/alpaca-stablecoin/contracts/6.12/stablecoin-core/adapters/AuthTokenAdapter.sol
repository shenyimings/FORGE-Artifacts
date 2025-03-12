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

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "../../interfaces/IBookKeeper.sol";
import "../../interfaces/IToken.sol";
import "../../interfaces/IAuthTokenAdapter.sol";
import "../../interfaces/ICagable.sol";

// Authed TokenAdapter for a token that has a lower precision than 18 and it has decimals (like USDC)

contract AuthTokenAdapter is
  PausableUpgradeable,
  AccessControlUpgradeable,
  ReentrancyGuardUpgradeable,
  IAuthTokenAdapter,
  ICagable
{
  bytes32 public constant WHITELISTED = keccak256("WHITELISTED");

  IBookKeeper public override bookKeeper; // cdp engine
  bytes32 public override collateralPoolId; // collateral pool id
  IToken public token; // collateral token
  uint256 public override decimals; // collateralToken decimals
  uint256 public live; // Access Flag

  // --- Events ---
  event LogDeposit(address indexed urn, uint256 wad, address indexed msgSender);
  event LogWithdraw(address indexed guy, uint256 wad);

  function initialize(
    address _bookKeeper,
    bytes32 _collateralPoolId,
    address _token
  ) external initializer {
    PausableUpgradeable.__Pausable_init();
    AccessControlUpgradeable.__AccessControl_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    token = IToken(_token);
    decimals = IToken(_token).decimals();
    live = 1;
    bookKeeper = IBookKeeper(_bookKeeper);
    collateralPoolId = _collateralPoolId;

    // Grant the contract deployer the owner role: it will be able
    // to grant and revoke any roles
    _setupRole(IAccessControlConfig(bookKeeper.accessControlConfig()).OWNER_ROLE(), msg.sender);
  }

  function cage() external override {
    IAccessControlConfig _accessControlConfig = IAccessControlConfig(bookKeeper.accessControlConfig());
    require(
      _accessControlConfig.hasRole(_accessControlConfig.OWNER_ROLE(), msg.sender) ||
        _accessControlConfig.hasRole(keccak256("SHOW_STOPPER_ROLE"), msg.sender),
      "!(ownerRole or showStopperRole)"
    );
    require(live == 1, "AuthTokenAdapter/not-live");
    live = 0;
    emit LogCage();
  }

  function uncage() external override {
    IAccessControlConfig _accessControlConfig = IAccessControlConfig(bookKeeper.accessControlConfig());
    require(
      _accessControlConfig.hasRole(_accessControlConfig.OWNER_ROLE(), msg.sender) ||
        _accessControlConfig.hasRole(keccak256("SHOW_STOPPER_ROLE"), msg.sender),
      "!(ownerRole or showStopperRole)"
    );
    require(live == 0, "AuthTokenAdapter/not-caged");
    live = 1;
    emit LogUncage();
  }

  function mul(uint256 _x, uint256 _y) internal pure returns (uint256 _z) {
    require(_y == 0 || (_z = _x * _y) / _y == _x, "AuthTokenAdapter/overflow");
  }

  /**
   * @dev Deposit token into the system from the msgSender to be used as collateral
   * @param _urn The destination address which is holding the collateral token
   * @param _wad The amount of collateral to be deposit [wad]
   * @param _msgSender The source address which transfer token
   */
  function deposit(
    address _urn,
    uint256 _wad,
    address _msgSender
  ) external override nonReentrant whenNotPaused {
    require(hasRole(WHITELISTED, msg.sender), "AuthTokenAdapter/not-whitelisted");
    require(live == 1, "AuthTokenAdapter/not-live");
    uint256 _wad18 = mul(_wad, 10**(18 - decimals));
    require(int256(_wad18) >= 0, "AuthTokenAdapter/overflow");
    bookKeeper.addCollateral(collateralPoolId, _urn, int256(_wad18));
    require(token.transferFrom(_msgSender, address(this), _wad), "AuthTokenAdapter/failed-transfer");
    emit LogDeposit(_urn, _wad, _msgSender);
  }

  /**
   * @dev Withdraw token from the system to guy
   * @param _guy The destination address to receive collateral token
   * @param _wad The amount of collateral to be withdraw [wad]
   */
  function withdraw(address _guy, uint256 _wad) external override nonReentrant whenNotPaused {
    uint256 _wad18 = mul(_wad, 10**(18 - decimals));
    require(int256(_wad18) >= 0, "AuthTokenAdapter/overflow");
    bookKeeper.addCollateral(collateralPoolId, msg.sender, -int256(_wad18));
    require(token.transfer(_guy, _wad), "AuthTokenAdapter/failed-transfer");
    emit LogWithdraw(_guy, _wad);
  }

  // --- pause ---
  function pause() external {
    IAccessControlConfig _accessControlConfig = IAccessControlConfig(bookKeeper.accessControlConfig());
    require(
      _accessControlConfig.hasRole(_accessControlConfig.OWNER_ROLE(), msg.sender) ||
        _accessControlConfig.hasRole(_accessControlConfig.GOV_ROLE(), msg.sender),
      "!(ownerRole or govRole)"
    );
    _pause();
  }

  function unpause() external {
    IAccessControlConfig _accessControlConfig = IAccessControlConfig(bookKeeper.accessControlConfig());
    require(
      _accessControlConfig.hasRole(_accessControlConfig.OWNER_ROLE(), msg.sender) ||
        _accessControlConfig.hasRole(_accessControlConfig.GOV_ROLE(), msg.sender),
      "!(ownerRole or govRole)"
    );
    _unpause();
  }
}
