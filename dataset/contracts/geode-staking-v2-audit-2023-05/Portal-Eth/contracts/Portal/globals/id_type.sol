// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

/**
 * @notice ID_TYPE is an internal library that acts like an ENUM.
 *
 * @dev Used within the limited upgradability pattern:
 *
 * NONE & GAP: should not be used.
 *
 * Dual Governance:
 * * SENATE: points to a proposal that will update the current SENATE address of a package(or Portal).
 * * CONTRACT_UPGRADE: proposal to change the given contract's implementation.
 *
 * Users:
 * * OPERATOR: permissionned Node Operators (hosted on Portal).
 * * POOL: permissionless staking pools (hosted on Portal).
 *
 * Packages: (hosted on StakeModuleLib)
 * * An ID can only point to 1(one) Package version' implementation address at a given point.
 * * Can be upgraded by a dual governance, via pullUpgrade.
 * * * Portal's dual governance consists of a Governance Token(governance) and a Senate(senate).
 * * * A Package's dual governance consists of Portal(governance) and the pool owner(senate).
 * * Built by utilizing the Modules.
 * * LiquidityPool and WithdrawalContract are some examples.
 *
 * Middlewares: (hosted on StakeModuleLib)
 * * An ID can point to multiple Middleware version' implementation address at the same time.
 * * Can not be upgraded.
 * * Do not have any guides to build really.
 * * Currently only gETHMiddlewares
 *
 *  Limits:
 *  * We simply set limits to separate a group of types from others. Like Packages and Middlewares.
 *
 * @dev all LIMIT parameters are exclusive, prevents double usage.
 */
library ID_TYPE {
  /// @notice TYPE 0: *invalid*
  uint256 internal constant NONE = 0;

  /// @notice TYPE 1: Senate
  uint256 internal constant SENATE = 1;

  /// @notice TYPE 2: Contract Upgrade
  uint256 internal constant CONTRACT_UPGRADE = 2;

  /// @notice TYPE 3: *gap*: formally represented the admin contract. reserved to be never used.
  uint256 internal constant __GAP__ = 3;

  /// --

  /// @notice TYPE 4: USER: Permissionned Node Operator
  uint256 internal constant OPERATOR = 4;

  /// @notice TYPE 5: USER: Staking Pool
  uint256 internal constant POOL = 5;

  /// --

  /// @notice TYPE 10000: Limit: exclusive, minimum TYPE that will be percieved as a package
  uint256 internal constant LIMIT_MIN_PACKAGE = 10000;

  /// @notice TYPE 10011: Package: Portal is also a package
  uint256 internal constant PACKAGE_PORTAL = 10001;

  /// @notice TYPE 10011: Package: The Withdrawal Credential Contract
  uint256 internal constant PACKAGE_WITHDRAWAL_CONTRACT = 10011;

  /// @notice TYPE 10021: Package: A Liquidity Pool
  uint256 internal constant PACKAGE_LIQUIDITY_POOL = 10021;

  /// @notice TYPE 19999: Limit: exclusive, maximum TYPE that will be percieved as a package
  uint256 internal constant LIMIT_MAX_PACKAGE = 19999;

  /// --

  /// @notice TYPE 20000: Limit: exclusive, minimum TYPE that will be percieved as a middleware
  uint256 internal constant LIMIT_MIN_MIDDLEWARE = 20000;

  /// @notice TYPE 20031: Middleware: A new gETH interface
  uint256 internal constant MIDDLEWARE_GETH = 20011;

  /// @notice TYPE 29999: Limit: exclusive, maximum TYPE that will be percieved as a middleware
  uint256 internal constant LIMIT_MAX_MIDDLEWARE = 29999;
}
