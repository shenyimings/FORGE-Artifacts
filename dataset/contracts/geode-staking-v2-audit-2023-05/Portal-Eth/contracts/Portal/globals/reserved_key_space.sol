// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

/**
 * @notice Reserved Key Space for DataStoreModule
 * * helps preventing potential dev mistakes.
 * * helps keeping track of them.
 * * limits keys to bytes32.
 *
 * @dev utilize a key with rks.key
 * @dev keep this list in alphabetical order, per module.
 * @dev NEVER name your variables something else other than *its string value*.
 * @dev ! array keys with readUint returns the lenght of the array !
 */
library RESERVED_KEY_SPACE {
  /**
   * @dev reserved on GeodeModuleLib
   */

  /**
   * @custom:type address
   * @custom:definition representing body of an id
   */
  bytes32 internal constant CONTROLLER = "CONTROLLER";

  /**
   * @custom:type bytes
   * @custom:definition base of an id
   */
  bytes32 internal constant NAME = "NAME";

  /**
   * @custom:type uint
   * @custom:definition identifier for an id, based on ID_TYPEs
   */
  bytes32 internal constant TYPE = "TYPE";

  /**
   * @dev reserved on StakeModuleLib
   */

  /**
   * @custom:type uint, relational, pool[operator]
   * @custom:definition number of active validators run by an operator for a pool
   */
  bytes32 internal constant activeValidators = "activeValidators";

  /**
   * @custom:type uint, relational, pool[operator]
   * @custom:definition max amount of validators for an operator to run, for a specific pool.
   */
  bytes32 internal constant allowance = "allowance";

  /**
   * @custom:type uint
   * @custom:definition special operator that has max allowance, if threshold is hit for the pool
   */
  bytes32 internal constant fallbackOperator = "fallbackOperator";

  /**
   * @custom:type uint
   * @custom:definition fee of the pool or operator, will be shadowed by priorFee if switching
   */
  bytes32 internal constant fee = "fee";

  /**
   * @custom:type uint
   * @custom:definition effective timestamp pointing to the latest delayed fee change
   */
  bytes32 internal constant feeSwitch = "feeSwitch";

  /**
   * @custom:type uint
   * @custom:definition the timestamp of an "user" TYPE id
   */
  bytes32 internal constant initiated = "initiated";

  /**
   * @custom:type address
   * @custom:definition bound liquidity pool of a pool
   */
  bytes32 internal constant liquidityPool = "liquidityPool";

  /**
   * @custom:type address
   * @custom:definition hot wallet for pool and operators, automatooor
   */
  bytes32 internal constant maintainer = "maintainer";

  /**
   * @custom:type address array, direct call returns length
   * @custom:definition contracts with more than one versions, ex: gETHMiddlewares of a pool
   */
  bytes32 internal constant middlewares = "middlewares";

  /**
   * @custom:type uint
   * @custom:definition effective timestamp pointing to the latest delayed validator period change
   */
  bytes32 internal constant periodSwitch = "periodSwitch";

  /**
   * @custom:type uint
   * @custom:definition fee that will be effective if fee is currently switching
   */
  bytes32 internal constant priorFee = "priorFee";

  /**
   * @custom:type address
   * @custom:definition fee that will be effective if validatorPeriod is currently switching
   */
  bytes32 internal constant priorPeriod = "priorPeriod";

  /**
   * @custom:type uint, bool
   * @custom:definition 1(true) if id is a private pool
   */
  bytes32 internal constant privatePool = "privatePool";

  /**
   * @custom:type uint, relational, pool[operator]
   * @custom:definition proposed validator count for
   */
  bytes32 internal constant proposedValidators = "proposedValidators";

  /**
   * @custom:type uint
   * @custom:definition timestamp of the date of the latest imprisonment for an operator
   */
  bytes32 internal constant release = "release";

  /**
   * @custom:type uint
   * @custom:definition 32 eth is secured, per proposed-but-not-yet-activated validator
   */
  bytes32 internal constant secured = "secured";

  /**
   * @custom:type uint
   * @custom:definition collateral waiting to be staked, in wei
   */
  bytes32 internal constant surplus = "surplus";

  /**
   * @custom:type uint
   * @custom:definition sum of all allowances for a pool
   */

  bytes32 internal constant totalAllowance = "totalAllowance";

  /**
   * @custom:type uint
   * @custom:definition seconds, time that passes before the expected exit is reached for a validator
   */
  bytes32 internal constant validatorPeriod = "validatorPeriod";

  /**
   * @custom:type bytes array, direct call returns length
   * @custom:definition lists all (any state) validators' pubkeys for a pool, or an operator
   */
  bytes32 internal constant validators = "validators";

  /**
   * @custom:type address
   * @custom:definition custodian of validator funds for a pool
   */
  bytes32 internal constant withdrawalContract = "withdrawalContract";

  /**
   * @custom:type bytes
   * @custom:definition derived from withdrawalContract
   */
  bytes32 internal constant withdrawalCredential = "withdrawalCredential";

  /**
   * @custom:type uint
   * @custom:definition size of the internal wallet, which accrues fees etc. in wei
   */
  bytes32 internal constant wallet = "wallet";

  /**
   * @custom:type address
   * @custom:definition whitelist contract for the pool
   */
  bytes32 internal constant whitelist = "whitelist";

  /**
   * @dev reserved on OracleExtensionLib
   */

  /**
   * @custom:type uint, relational, pool[operator]
   * @custom:definition number of alienated validators run by an operator for a pool
   */
  bytes32 internal constant alienValidators = "alienValidators";
}
