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

import "../../interfaces/IBookKeeper.sol";
import "../../interfaces/IToken.sol";
import "../../interfaces/IGenericTokenAdapter.sol";
import "../../interfaces/ICagable.sol";
import "../../utils/SafeToken.sol";

/*
    Here we provide *adapters* to connect the BookKeeper to arbitrary external
    token implementations, creating a bounded context for the BookKeeper. The
    adapters here are provided as working examples:

      - `TokenAdapter`: For well behaved ERC20 tokens, with simple transfer
                   semantics.

      - `StablecoinAdapter`: For connecting internal Alpaca Stablecoin balances to an external
                   `AlpacaStablecoin` implementation.

    In practice, adapter implementations will be varied and specific to
    individual collateral types, accounting for different transfer
    semantics and token standards.

    Adapters need to implement two basic methods:

      - `deposit`: enter token into the system
      - `withdraw`: remove token from the system

*/

contract TokenAdapter is PausableUpgradeable, ReentrancyGuardUpgradeable, IGenericTokenAdapter, ICagable {
  using SafeToken for address;

  modifier onlyOwner() {
    IAccessControlConfig _accessControlConfig = IAccessControlConfig(bookKeeper.accessControlConfig());
    require(_accessControlConfig.hasRole(_accessControlConfig.OWNER_ROLE(), msg.sender), "!ownerRole");
    _;
  }

  IBookKeeper public bookKeeper; // CDP Engine
  bytes32 public override collateralPoolId; // Collateral Type
  address public override collateralToken;
  uint256 public override decimals;
  uint256 public live; // Active Flag

  function initialize(
    address _bookKeeper,
    bytes32 collateralPoolId_,
    address collateralToken_
  ) external initializer {
    PausableUpgradeable.__Pausable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    live = 1;
    bookKeeper = IBookKeeper(_bookKeeper);
    collateralPoolId = collateralPoolId_;
    collateralToken = collateralToken_;
    decimals = IToken(collateralToken).decimals();
  }

  function cage() external override {
    IAccessControlConfig _accessControlConfig = IAccessControlConfig(bookKeeper.accessControlConfig());
    require(
      _accessControlConfig.hasRole(_accessControlConfig.OWNER_ROLE(), msg.sender) ||
        _accessControlConfig.hasRole(keccak256("SHOW_STOPPER_ROLE"), msg.sender),
      "!(ownerRole or showStopperRole)"
    );
    require(live == 1, "TokenAdapter/not-live");
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
    require(live == 0, "TokenAdapter/not-caged");
    live = 1;
    emit LogUncage();
  }

  /// @dev Deposit token into the system from the caller to be used as collateral
  /// @param usr The source address which is holding the collateral token
  /// @param wad The amount of collateral to be deposited [wad]
  function deposit(
    address usr,
    uint256 wad,
    bytes calldata /* data */
  ) external payable override nonReentrant whenNotPaused {
    require(live == 1, "TokenAdapter/not-live");
    require(int256(wad) >= 0, "TokenAdapter/overflow");
    bookKeeper.addCollateral(collateralPoolId, usr, int256(wad));

    // Move the actual token
    address(collateralToken).safeTransferFrom(msg.sender, address(this), wad);
  }

  /// @dev Withdraw token from the system to the caller
  /// @param usr The destination address to receive collateral token
  /// @param wad The amount of collateral to be withdrawn [wad]
  function withdraw(
    address usr,
    uint256 wad,
    bytes calldata /* data */
  ) external override nonReentrant whenNotPaused {
    require(wad <= 2**255, "TokenAdapter/overflow");
    bookKeeper.addCollateral(collateralPoolId, msg.sender, -int256(wad));

    // Move the actual token
    address(collateralToken).safeTransfer(usr, wad);
  }

  function onAdjustPosition(
    address src,
    address dst,
    int256 collateralValue,
    int256 debtShare,
    bytes calldata data
  ) external override nonReentrant {}

  function onMoveCollateral(
    address src,
    address dst,
    uint256 wad,
    bytes calldata data
  ) external override nonReentrant {}

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
