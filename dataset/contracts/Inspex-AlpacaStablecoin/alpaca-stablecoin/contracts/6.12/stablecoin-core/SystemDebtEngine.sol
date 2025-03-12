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
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "../interfaces/IBookKeeper.sol";
import "../interfaces/ISystemDebtEngine.sol";
import "../interfaces/IGenericTokenAdapter.sol";
import "../interfaces/ICagable.sol";

/// @title SystemDebtEngine
/// @author Alpaca Fin Corporation
/** @notice A contract which manages the bad debt and the surplus of the system.
    SystemDebtEngine will be the debitor or debtor when a position is liquidated. 
    The debt recorded in the name of SystemDebtEngine will be considered as system bad debt unless it is cleared by liquidation.
    The stability fee will be accrued and kept within SystemDebtEngine. As it is the debtor, therefore SystemDebtEngine should be the holder of the surplus and use it to settle the bad debt.
*/

contract SystemDebtEngine is PausableUpgradeable, ReentrancyGuardUpgradeable, ISystemDebtEngine, ICagable {
  // --- Data ---
  IBookKeeper public bookKeeper; // CDP Engine
  uint256 public override surplusBuffer; // Surplus buffer         [rad]
  uint256 public live; // Active Flag

  // --- Init ---
  function initialize(address _bookKeeper) external initializer {
    PausableUpgradeable.__Pausable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    bookKeeper = IBookKeeper(_bookKeeper);
    live = 1;
  }

  // --- Math ---
  function add(uint256 _x, uint256 _y) internal pure returns (uint256 _z) {
    require((_z = _x + _y) >= _x);
  }

  function sub(uint256 _x, uint256 _y) internal pure returns (uint256 _z) {
    require((_z = _x - _y) <= _x);
  }

  function min(uint256 _x, uint256 _y) internal pure returns (uint256 _z) {
    return _x <= _y ? _x : _y;
  }

  // --- withdraw surplus ---
  /// @param _amount The amount of collateral. [wad]
  function withdrawCollateralSurplus(
    bytes32 _collateralPoolId,
    IGenericTokenAdapter _adapter,
    address _to,
    uint256 _amount // [wad]
  ) external {
    IAccessControlConfig _accessControlConfig = IAccessControlConfig(bookKeeper.accessControlConfig());
    require(_accessControlConfig.hasRole(_accessControlConfig.OWNER_ROLE(), msg.sender), "!ownerRole");
    bookKeeper.moveCollateral(_collateralPoolId, address(this), _to, _amount);
    _adapter.onMoveCollateral(address(this), _to, _amount, abi.encode(_to));
  }

  /// @param _value The value of collateral. [rad]
  function withdrawStablecoinSurplus(address _to, uint256 _value) external {
    IAccessControlConfig _accessControlConfig = IAccessControlConfig(bookKeeper.accessControlConfig());
    require(_accessControlConfig.hasRole(_accessControlConfig.OWNER_ROLE(), msg.sender), "!ownerRole");
    require(bookKeeper.systemBadDebt(address(this)) == 0, "SystemDebtEngine/system-bad-debt-remaining");
    require(
      sub(bookKeeper.stablecoin(address(this)), _value) >= surplusBuffer,
      "SystemDebtEngine/insufficient-surplus"
    );
    bookKeeper.moveStablecoin(address(this), _to, _value);
  }

  // --- Administration ---
  event LogSetSurplusBuffer(address indexed _caller, uint256 _data);

  function setSurplusBuffer(uint256 _data) external whenNotPaused {
    IAccessControlConfig _accessControlConfig = IAccessControlConfig(bookKeeper.accessControlConfig());
    require(_accessControlConfig.hasRole(_accessControlConfig.OWNER_ROLE(), msg.sender), "!ownerRole");
    surplusBuffer = _data;
    emit LogSetSurplusBuffer(msg.sender, _data);
  }

  // Debt settlement
  /** @dev Settle system bad debt as SystemDebtEngine.
      This function could be called by anyone to settle the system bad debt when there is available surplus.
      The stablecoin held by SystemDebtEngine (which is the surplus) will be deducted to compensate the incurred bad debt.
  */
  /// @param _value The value of bad debt to be settled. [rad]
  function settleSystemBadDebt(uint256 _value) external override whenNotPaused nonReentrant {
    require(_value <= bookKeeper.stablecoin(address(this)), "SystemDebtEngine/insufficient-surplus");
    require(_value <= bookKeeper.systemBadDebt(address(this)), "SystemDebtEngine/insufficient-debt");
    bookKeeper.settleSystemBadDebt(_value);
  }

  function cage() external override {
    IAccessControlConfig _accessControlConfig = IAccessControlConfig(bookKeeper.accessControlConfig());
    require(
      _accessControlConfig.hasRole(_accessControlConfig.OWNER_ROLE(), msg.sender) ||
        _accessControlConfig.hasRole(_accessControlConfig.SHOW_STOPPER_ROLE(), msg.sender),
      "!(ownerRole or showStopperRole)"
    );
    require(live == 1, "SystemDebtEngine/not-live");
    live = 0;
    bookKeeper.settleSystemBadDebt(min(bookKeeper.stablecoin(address(this)), bookKeeper.systemBadDebt(address(this))));
    emit LogCage();
  }

  function uncage() external override {
    IAccessControlConfig _accessControlConfig = IAccessControlConfig(bookKeeper.accessControlConfig());
    require(
      _accessControlConfig.hasRole(_accessControlConfig.OWNER_ROLE(), msg.sender) ||
        _accessControlConfig.hasRole(_accessControlConfig.SHOW_STOPPER_ROLE(), msg.sender),
      "!(ownerRole or showStopperRole)"
    );
    require(live == 0, "SystemDebtEngine/not-caged");
    live = 1;
    emit LogUncage();
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
