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
import "../../interfaces/IStablecoin.sol";
import "../../interfaces/IBookKeeper.sol";
import "../../interfaces/IToken.sol";
import "../../interfaces/IStablecoinAdapter.sol";
import "../../interfaces/ICagable.sol";

// FIXME: This contract was altered compared to the production version.
// It doesn't use LibNote anymore.
// New deployments of this contract will need to include custom events (TO DO).

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

contract StablecoinAdapter is PausableUpgradeable, ReentrancyGuardUpgradeable, IStablecoinAdapter, ICagable {
  IBookKeeper public override bookKeeper; // CDP Engine
  IStablecoin public override stablecoin; // Stablecoin Token
  uint256 public live; // Active Flag

  function initialize(address _bookKeeper, address _stablecoin) external initializer {
    PausableUpgradeable.__Pausable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    live = 1;
    bookKeeper = IBookKeeper(_bookKeeper);
    stablecoin = IStablecoin(_stablecoin);
  }

  function cage() external override {
    IAccessControlConfig _accessControlConfig = IAccessControlConfig(bookKeeper.accessControlConfig());
    require(
      _accessControlConfig.hasRole(_accessControlConfig.OWNER_ROLE(), msg.sender) ||
        _accessControlConfig.hasRole(keccak256("SHOW_STOPPER_ROLE"), msg.sender),
      "!(ownerRole or showStopperRole)"
    );
    require(live == 1, "StablecoinAdapter/not-live");
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
    require(live == 0, "StablecoinAdapter/not-caged");
    live = 1;
    emit LogUncage();
  }

  uint256 constant ONE = 10**27;

  function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require(y == 0 || (z = x * y) / y == x);
  }

  /// @dev Deposit stablecoin into the system from the caller to be used for debt repayment or liquidation
  /// @param usr The source address which is holding the stablecoin
  /// @param wad The amount of stablecoin to be deposited [wad]
  function deposit(
    address usr,
    uint256 wad,
    bytes calldata /* data */
  ) external payable override nonReentrant whenNotPaused {
    bookKeeper.moveStablecoin(address(this), usr, mul(ONE, wad));
    stablecoin.burn(msg.sender, wad);
  }

  /// @dev Withdraw stablecoin from the system to the caller
  /// @param usr The destination address to receive stablecoin
  /// @param wad The amount of stablecoin to be withdrawn [wad]
  function withdraw(
    address usr,
    uint256 wad,
    bytes calldata /* data */
  ) external override nonReentrant whenNotPaused {
    require(live == 1, "StablecoinAdapter/not-live");
    bookKeeper.moveStablecoin(msg.sender, address(this), mul(ONE, wad));
    stablecoin.mint(usr, wad);
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
