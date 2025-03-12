// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// globals
import {PERCENTAGE_DENOMINATOR} from "../../../globals/macros.sol";
import {ID_TYPE} from "../../../globals/id_type.sol";
import {VALIDATOR_STATE} from "../../../globals/validator_state.sol";
import {RESERVED_KEY_SPACE as rks} from "../../../globals/reserved_key_space.sol";
// libraries
import {DataStoreModuleLib as DSML} from "../../DataStoreModule/libs/DataStoreModuleLib.sol";
import {DepositContractLib as DCL} from "./DepositContractLib.sol";
// interfaces
import {IgETH} from "../../../interfaces/IgETH.sol";
import {IgETHMiddleware} from "../../../interfaces/middlewares/IgETHMiddleware.sol";
import {IGeodePackage} from "../../../interfaces/packages/IGeodePackage.sol";
import {ILiquidityPool} from "../../../interfaces/packages/ILiquidityPool.sol";
import {IWhitelist} from "../../../interfaces/helpers/IWhitelist.sol";
// external
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title SML: The Staking Library
 *
 * @notice Creating a global standard for Staking, allowing anyone to OWN a trustless staking pool,
 * improving the user experience for stakers and removing the "need" for centralized or decentralized intermediaries.
 * * Exclusively contains functions related to:
 * * 1. Initiators and Configurable Staking Pools.
 * * 2. Pool and Operator management.
 * * 3. Validator Delegation.
 * * 4. Depositing.
 * * 5. Staking Operations.
 *
 * @dev review: DataStoreModule for the IsolatedStorage logic.
 * @dev review: OracleExtensionLib for oracle logic.
 *
 * @dev Every pool is isolated and every validator is unique. Segregate all the risk.
 *
 * @dev CONTROLLER and Maintainer:
 * CONTROLLER is the owner of an ID, it manages the pool/operator. Its security is exteremely important.
 * maintainer is the worker, can be used to automate some daily tasks:
 * * distributing validators for Staking Pools or creating validators for Operators.
 * * not so crucial in terms of security.
 *
 * @dev Users:
 * Type 4 : Permissioned Operators
 * * Needs to be onboarded by the Dual Governance (Senate + Governance).
 * * Maintains Beacon Chain Validators on behalf of the Staking Pools.
 * * Can participate in the Operator Marketplace after initiation.
 * * Can utilize maintainers for staking operations.
 *
 * Type 5 : Permissionless Configurable Staking Pools
 * * Permissionless to create.
 * * Can utilize powers of packages and middlewares such as Bound Liquidity Pools, gETHMiddlewares etc.
 * * Can be public or private, can use a whitelist if private.
 * * Can utilize maintainers for validator distribution on Operator Marketplace.
 * * Uses a Withdrawal Contract to be given as withdrawalCredential on validator creation,
 * * accruing rewards and keeping Staked Ether safe and isolated.
 *
 * @dev Packages:
 * An ID can only point to 1(one) Package version at a time.
 * Built by utilizing the Modules!
 * Can be upgraded by a dual governance, via pullUpgrade.
 * * A Package's dual governance consists of Portal(governance) and the pool owner(senate).
 *
 * Type 10011 : Withdrawal Contract
 * * Mandatory.
 * * CONTROLLER is the implementation contract position (always)
 * * Version Release Requires the approval of Senate
 * * Upgrading to a new version is optional for pool owners.
 * * * Staking Pools are in "Isolation Mode" until their Withdrawal Contract is upgraded.
 * * * Meaning, no more Depositing or Validator Proposal can happen.
 * * Custodian of the validator funds after creation, including any type of rewards and fees.
 *
 * Type 10021 : Liquidity Pool implementation
 * * Optional.
 * * CONTROLLER is the implementation contract position (always)
 * * Version Release Requires the approval of Senate
 * * Upgrading to a new version is optional for pool owners.
 * * * Liquidity Pools are in "Isolation Mode" until upgraded.
 *
 * @dev Middlewares:
 * Can support many different versions that can be utilized by the Pool Owners.
 * No particular way to build one.
 * Can not be upgraded.
 * Currently only gETHMiddlewares.
 *
 * Type 20011 : gETHMiddleware
 * * Optional.
 * * CONTROLLER is the implementation contract position (always)
 * * Requires the approval of Senate
 * * Currently should be utilized on initiation.
 *
 * @dev Contracts relying on this library must initialize StakeUtils.PooledStaking
 *
 * @dev Functions are protected with authentication function
 *
 * @author Ice Bear & Crash Bandicoot
 */

library StakeModuleLib {
  using DSML for DSML.IsolatedStorage;

  /**
   * @custom:section                           ** STRUCTS **
   */

  /**
   * @notice Helper Struct to pack constant data that does not change per validator on batch proposals
   * * needed for that famous Solidity feature.
   */
  struct ConstantValidatorData {
    uint64 index;
    uint64 period;
    uint256 poolFee;
    uint256 operatorFee;
    uint256 governanceFee;
    bytes withdrawalCredential;
  }

  /**
   * @param state state of the validator, refer to globals.sol
   * @param index representing this validator's placement on the chronological order of the validators proposals
   * @param createdAt the timestamp pointing the proposal to create a validator with given pubkey.
   * @param period the latest point in time the operator is allowed to maintain this validator (createdAt + validatorPeriod).
   * @param poolId needed for withdrawal_credential
   * @param operatorId needed for staking after allowance
   * @param poolFee percentage of the rewards that will go to pool's maintainer, locked when the validator is proposed
   * @param operatorFee percentage of the rewards that will go to operator's maintainer, locked when the validator is proposed
   * @param governanceFee although governance fee is zero right now, all fees are crucial for the price calculation by the oracle.
   * @param signature31 BLS12-381 signature for the validator, used when the remaining 31 ETH is sent on validator activation.
   **/
  struct Validator {
    uint64 state;
    uint64 index;
    uint64 createdAt;
    uint64 period;
    uint256 poolId;
    uint256 operatorId;
    uint256 poolFee;
    uint256 operatorFee;
    uint256 governanceFee;
    bytes signature31;
  }

  /**
   * @param gETH constant, ERC1155, all Geode Staking Derivatives.
   * @param ORACLE_POSITION constant, address of the Oracle https://github.com/Geodefi/Telescope-Eth
   * @param VALIDATORS_INDEX total number of validators that are proposed at any given point.
   * * Includes all validators: proposed, active, alienated, exited.
   * @param VERIFICATION_INDEX the highest index of the validators that are verified (as not alien) by the Holy Oracle.
   * @param MONOPOLY_THRESHOLD max number of validators 1 operator is allowed to operate, updated by the Holy Oracle.
   * @param ORACLE_UPDATE_TIMESTAMP timestamp of the latest oracle update
   * @param DAILY_PRICE_DECREASE_LIMIT limiting the price decreases for one oracle period, 24h. Effective for any time interval, per second.
   * @param DAILY_PRICE_INCREASE_LIMIT limiting the price increases for one oracle period, 24h. Effective for any time interval, per second.
   * @param PRICE_MERKLE_ROOT merkle root of the prices of every pool, updated by the Holy Oracle.
   * @param GOVERNANCE_FEE **reserved** Although it is 0 right now, It can be updated in the future.
   * @param BALANCE_MERKLE_ROOT merkle root of the balances and other validator related data, useful on withdrawals, updated by the Holy Oracle.
   * @param validators pubkey => Validator, contains all the data about proposed, alienated, active, exit-called and fully exited validators.
   * @param packages TYPE => version id, pointing to the latest versions of the given package.
   * * Like default Withdrawal Contract version.
   * @param middlewares TYPE => version id => isAllowed, useful to check if given version of the middleware can be used.
   * * Like all the whitelisted gETHMiddlewares.
   * @param __gap keep the struct size at 16
   **/
  struct PooledStaking {
    IgETH gETH;
    address ORACLE_POSITION;
    uint256 VALIDATORS_INDEX;
    uint256 VERIFICATION_INDEX;
    uint256 MONOPOLY_THRESHOLD;
    uint256 ORACLE_UPDATE_TIMESTAMP;
    uint256 DAILY_PRICE_INCREASE_LIMIT;
    uint256 DAILY_PRICE_DECREASE_LIMIT;
    uint256 GOVERNANCE_FEE;
    bytes32 PRICE_MERKLE_ROOT;
    bytes32 BALANCE_MERKLE_ROOT;
    mapping(bytes => Validator) validators;
    mapping(uint256 => uint256) packages;
    mapping(uint256 => mapping(uint256 => bool)) middlewares;
    uint256[2] __gap;
  }

  /**
   * @custom:section                           ** CONSTANTS **
   */

  /// @notice limiting the GOVERNANCE_FEE to 5%
  uint256 public constant MAX_GOVERNANCE_FEE = (PERCENTAGE_DENOMINATOR * 5) / 100;

  /// @notice limiting the pool and operator maintenance fee, 10%
  uint256 public constant MAX_MAINTENANCE_FEE = (PERCENTAGE_DENOMINATOR * 10) / 100;

  /// @notice effective on allowance per operator, prevents overflow. Exclusive, save gas with +1.
  uint256 public constant MAX_ALLOWANCE = 10 ** 6 + 1;

  /// @notice if a pool has 80% of its allowances filled, fallback operator is active.
  uint256 public constant FALLBACK_THRESHOLD = (PERCENTAGE_DENOMINATOR * 80) / 100;

  /// @notice price of gETH is only valid for 24H, minting is not allowed afterwards.
  uint256 public constant PRICE_EXPIRY = 24 hours;

  /// @notice ignoring any buybacks if the Liquidity Pool has a low debt
  uint256 public constant IGNORABLE_DEBT = 1 ether;

  /// @notice limiting the operator.validatorPeriod, between 3 months to 2 years
  uint256 public constant MIN_VALIDATOR_PERIOD = 3 * 30 days;
  uint256 public constant MAX_VALIDATOR_PERIOD = 2 * 365 days;

  /// @notice some parameter changes are effective after a delay
  uint256 public constant SWITCH_LATENCY = 3 days;

  /// @notice limiting the access for Operators in case of bad/malicious/faulty behaviour
  uint256 public constant PRISON_SENTENCE = 14 days;

  /**
   * @custom:section                           ** EVENTS **
   */
  event IdInitiated(uint256 id, uint256 indexed TYPE);
  event VisibilitySet(uint256 id, bool isPrivate);
  event MaintainerChanged(uint256 indexed id, address newMaintainer);
  event FeeSwitched(uint256 indexed id, uint256 fee, uint256 effectiveAfter);
  event ValidatorPeriodSwitched(uint256 indexed operatorId, uint256 period, uint256 effectiveAfter);
  event Delegation(uint256 poolId, uint256 indexed operatorId, uint256 allowance);
  event FallbackOperator(uint256 poolId, uint256 indexed operatorId);
  event Prisoned(uint256 indexed operatorId, bytes proof, uint256 releaseTimestamp);
  event Deposit(uint256 indexed poolId, uint256 boughtgETH, uint256 mintedgETH);
  event StakeProposal(uint256 poolId, uint256 operatorId, bytes[] pubkeys);
  event Stake(bytes[] pubkeys);

  /**
   * @custom:section                           ** AUTHENTICATION **
   *
   * @custom:visibility -> view-internal
   */

  /**
   * @notice restricts the access to given function based on TYPE and msg.sender
   * @param _expectCONTROLLER restricts the access to only CONTROLLER.
   * @param _expectMaintainer restricts the access to only maintainer.
   * @param _restrictionMap Restricts which TYPEs can pass the authentication.
   * * [0: Operator = TYPE(4), 1: Pool = TYPE(5)]
   * @dev can only be used after an ID is initiated
   * @dev CONTROLLERS and maintainers of the Prisoned Operators can not access.
   */
  function _authenticate(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 _id,
    bool _expectCONTROLLER,
    bool _expectMaintainer,
    bool[2] memory _restrictionMap
  ) internal view {
    require(DATASTORE.readUint(_id, rks.initiated) != 0, "SML:not initiated");

    uint256 typeOfId = DATASTORE.readUint(_id, rks.TYPE);

    if (typeOfId == ID_TYPE.OPERATOR) {
      require(_restrictionMap[0], "SML:TYPE NOT allowed");
      if (_expectCONTROLLER || _expectMaintainer) {
        require(!isPrisoned(DATASTORE, _id), "SML:prisoned, get in touch with governance");
      }
    } else if (typeOfId == ID_TYPE.POOL) {
      require(_restrictionMap[1], "SML:TYPE NOT allowed");
    } else revert("SML:invalid TYPE");

    if (_expectMaintainer) {
      require(
        msg.sender == DATASTORE.readAddress(_id, rks.maintainer),
        "SML:sender NOT maintainer"
      );
      return;
    }

    if (_expectCONTROLLER) {
      require(
        msg.sender == DATASTORE.readAddress(_id, rks.CONTROLLER),
        "SML:sender NOT CONTROLLER"
      );
      return;
    }
  }

  /**
   * @custom:section                           ** OPERATOR INITIATOR **
   *
   * @custom:visibility -> external
   */

  /**
   * @notice initiates ID as a Permissionned Node Operator
   * @notice requires ID to be approved as a node operator with a specific CONTROLLER
   * @param fee as a percentage limited by MAX_MAINTENANCE_FEE, PERCENTAGE_DENOMINATOR represents 100%
   * @param validatorPeriod the expected maximum staking interval. This value should between
   * * MIN_VALIDATOR_PERIOD and MAX_VALIDATOR_PERIOD values defined as constants above.
   * Operator can unstake at any given point before this period ends.
   * If operator disobeys this rule, it can be prisoned with blameOperator()
   * @param maintainer an address that automates daily operations, a script, a contract...
   * @dev operators can fund their internal wallet on initiation by simply sending some ether.
   */
  function initiateOperator(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 id,
    uint256 fee,
    uint256 validatorPeriod,
    address maintainer
  ) external {
    require(DATASTORE.readUint(id, rks.initiated) == 0, "SML:already initiated");
    require(DATASTORE.readUint(id, rks.TYPE) == ID_TYPE.OPERATOR, "SML:TYPE NOT allowed");
    require(msg.sender == DATASTORE.readAddress(id, rks.CONTROLLER), "SML:sender NOT CONTROLLER");

    DATASTORE.writeUint(id, rks.initiated, block.timestamp);

    _setMaintenanceFee(DATASTORE, id, fee);
    _setValidatorPeriod(DATASTORE, id, validatorPeriod);
    _setMaintainer(DATASTORE, id, maintainer);
    _increaseWalletBalance(DATASTORE, id, msg.value);

    emit IdInitiated(id, ID_TYPE.OPERATOR);
  }

  /**
   * @custom:section                           ** STAKING POOL INITIATOR **
   *
   * @dev this section also contains the helper functions for packages and middlewares.
   */

  /**
   * @notice Creates a Configurable Trustless Staking Pool!
   * @param fee as a percentage limited by MAX_MAINTENANCE_FEE, PERCENTAGE_DENOMINATOR is 100%
   * @param middlewareVersion Pool creators can choose any allowed version as their gETHMiddleware
   * @param maintainer an address that automates daily operations, a script, a contract... not so critical.
   * @param name is utilized while generating an ID for the Pool, similar to any other ID generation.
   * @param middleware_data middlewares might require additional data on initialization; like name, symbol, etc.
   * @param config array(3)= [private(true) or public(false), deploy a middleware(if true), deploy liquidity pool(if true)]
   * @dev checking only initiated is enough to validate that ID is not used. no need to check TYPE, CONTROLLER etc.
   * @dev requires exactly 1 validator worth of funds to be deposited on initiation, prevent sybil attacks.
   */
  function initiatePool(
    PooledStaking storage self,
    DSML.IsolatedStorage storage DATASTORE,
    uint256 fee,
    uint256 middlewareVersion,
    address maintainer,
    bytes calldata name,
    bytes calldata middleware_data,
    bool[3] calldata config
  ) external returns (uint256 poolId) {
    require(msg.value == DCL.DEPOSIT_AMOUNT, "SML:need 1 validator worth of funds");

    poolId = DSML.generateId(name, ID_TYPE.POOL);
    require(DATASTORE.readUint(poolId, rks.initiated) == 0, "SML:already initiated");
    require(poolId > 10 ** 9, "SML:Wow! Low pool id");

    DATASTORE.writeUint(poolId, rks.initiated, block.timestamp);

    DATASTORE.writeUint(poolId, rks.TYPE, ID_TYPE.POOL);
    DATASTORE.writeAddress(poolId, rks.CONTROLLER, msg.sender);
    DATASTORE.writeBytes(poolId, rks.NAME, name);
    DATASTORE.allIdsByType[ID_TYPE.POOL].push(poolId);

    _setMaintainer(DATASTORE, poolId, maintainer);
    _setMaintenanceFee(DATASTORE, poolId, fee);

    // deploy a withdrawal Contract - mandatory
    _deployWithdrawalContract(self, DATASTORE, poolId);

    if (config[0]) {
      // set pool to private
      setPoolVisibility(DATASTORE, poolId, true);
    }
    if (config[1]) {
      // deploy a gETH middleware(erc20 etc.) - optional
      _deploygETHMiddleware(self, DATASTORE, poolId, middlewareVersion, middleware_data);
    }
    if (config[2]) {
      // deploy a bound liquidity pool - optional
      deployLiquidityPool(self, DATASTORE, poolId);
    }

    // initially 1 ETHER = 1 ETHER
    self.gETH.setPricePerShare(1 ether, poolId);

    // mint gETH and send back to the caller
    uint256 mintedgETH = _mintgETH(self, DATASTORE, poolId, msg.value);
    self.gETH.safeTransferFrom(address(this), msg.sender, poolId, mintedgETH, "");

    emit IdInitiated(poolId, ID_TYPE.POOL);
  }

  /**
   * @custom:subsection                           ** POOL INITIATOR HELPERS **
   *
   * @custom:visibility -> internal
   */

  /**
   * @notice internal function to set a gETHMiddleware
   * @param _middleware address of the new gETHMiddleware for given ID
   * @dev every middleware has a unique index within the middlewares dynamic array.
   * @dev if ever unset, SHOULD replace the implementation with address(0) for obvious security reasons.
   */
  function _setgETHMiddleware(
    PooledStaking storage self,
    DSML.IsolatedStorage storage DATASTORE,
    uint256 id,
    address _middleware
  ) internal {
    require(!self.gETH.isMiddleware(_middleware, id), "SML:already middleware");

    DATASTORE.appendAddressArray(id, rks.middlewares, _middleware);

    self.gETH.setMiddleware(_middleware, id, true);
  }

  /**
   * @notice deploys a new gETHMiddleware by cloning (no upgradability)
   * @param _id gETH id, also required for IgETHMiddleware.initialize
   * @param _versionId provided version id, can use any as a middleware if allowed for TYPE = MIDDLEWARE_GETH
   * @param _middleware_data middlewares might require additional data on initialization; like name, symbol, etc.
   * @dev currrently, can NOT deploy a middleware after initiation, thus only used by the initiator.
   * @dev currrently, can NOT unset a middleware.
   */
  function _deploygETHMiddleware(
    PooledStaking storage self,
    DSML.IsolatedStorage storage DATASTORE,
    uint256 _id,
    uint256 _versionId,
    bytes memory _middleware_data
  ) internal {
    require(_versionId > 0);
    require(self.middlewares[ID_TYPE.MIDDLEWARE_GETH][_versionId], "SML:not a middleware");

    address newgETHMiddleware = Clones.clone(DATASTORE.readAddress(_versionId, rks.CONTROLLER));

    IgETHMiddleware(newgETHMiddleware).initialize(_id, address(self.gETH), _middleware_data);

    _setgETHMiddleware(self, DATASTORE, _id, newgETHMiddleware);

    // isolate the contract from middleware risk for ID
    self.gETH.avoidMiddlewares(_id, true);
  }

  /**
   * @notice deploys a new package for given id with given type from packages mapping.
   * @param _type given package type
   * @param _poolId pool id, required for IGeodePackage.initialize
   * @param _package_data packages might require additional data on initialization
   * @dev no cloning because GeodePackages has Limited Upgradability (based on UUPS)
   */
  function _deployGeodePackage(
    PooledStaking storage self,
    DSML.IsolatedStorage storage DATASTORE,
    uint256 _poolId,
    uint256 _type,
    bytes memory _package_data
  ) internal returns (address packageInstance) {
    uint256 versionId = self.packages[_type];
    require(versionId > 0);

    packageInstance = address(
      new ERC1967Proxy(DATASTORE.readAddress(versionId, rks.CONTROLLER), "")
    );
    // we don't call on deployment because initialize uses _getImplementation() which is not available
    IGeodePackage(packageInstance).initialize(
      _poolId,
      DATASTORE.readAddress(_poolId, rks.CONTROLLER),
      DATASTORE.readBytes(versionId, rks.NAME),
      _package_data
    );
  }

  /**
   * @notice Deploys a Withdrawal Contract that will be used as a withdrawal credential on validator creation
   * @dev every pool requires a Withdrawal Contract, thus this function is only used by the initiator
   */
  function _deployWithdrawalContract(
    PooledStaking storage self,
    DSML.IsolatedStorage storage DATASTORE,
    uint256 _poolId
  ) internal {
    require(
      DATASTORE.readAddress(_poolId, rks.withdrawalContract) == address(0),
      "SML:already deployed"
    );

    address wp = _deployGeodePackage(
      self,
      DATASTORE,
      _poolId,
      ID_TYPE.PACKAGE_WITHDRAWAL_CONTRACT,
      bytes("")
    );

    DATASTORE.writeAddress(_poolId, rks.withdrawalContract, wp);
    DATASTORE.writeBytes(_poolId, rks.withdrawalCredential, DCL.addressToWC(wp));
  }

  /**
   * @custom:subsection                           ** BOUND LIQUIDITY POOL **
   *
   * @custom:visibility -> public
   */

  /**
   * @notice deploys a bound liquidity pool for a staking pool, if it does not have one.
   * @dev gives full allowance to the pool (should not be a problem as Portal only temporarily holds gETH)
   * @dev unlike withdrawal Contract, a controller can deploy a liquidity pool after initiation as well
   * @dev _package_data of a liquidity pool is only the staking pool's name.
   */
  function deployLiquidityPool(
    PooledStaking storage self,
    DSML.IsolatedStorage storage DATASTORE,
    uint256 poolId
  ) public {
    _authenticate(DATASTORE, poolId, true, false, [false, true]);
    require(DATASTORE.readAddress(poolId, rks.liquidityPool) == address(0), "SML:already deployed");

    address lp = _deployGeodePackage(
      self,
      DATASTORE,
      poolId,
      ID_TYPE.PACKAGE_LIQUIDITY_POOL,
      DATASTORE.readBytes(poolId, rks.NAME)
    );

    DATASTORE.writeAddress(poolId, rks.liquidityPool, lp);
    // approve gETH so we can use it in buybacks
    self.gETH.setApprovalForAll(lp, true);
  }

  /**
   * @custom:subsection                           ** BOUND LIQUIDITY POOL **
   */

  /**
   * @custom:visibility -> external
   */

  /**
   * @notice changes the visibility of the pool
   * @param makePrivate true if pool should be private, false for public pools
   * @dev whitelist is cleared when pool is set to public, to prevent legacy bugs if ever made private again.
   * Note private pools can whitelist addresses with the help of a third party contract.
   */
  function setPoolVisibility(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 poolId,
    bool makePrivate
  ) public {
    _authenticate(DATASTORE, poolId, true, false, [false, true]);
    require(makePrivate != isPrivatePool(DATASTORE, poolId), "SML:already set");

    DATASTORE.writeUint(poolId, rks.privatePool, makePrivate ? 1 : 0);

    if (!makePrivate) {
      DATASTORE.writeAddress(poolId, rks.whitelist, address(0));
    }

    emit VisibilitySet(poolId, makePrivate);
  }

  /**
   * @notice private pools can whitelist addresses with the help of a third party contract.
   * @dev Whitelisting contracts should implement IWhitelist interface.
   */
  function setWhitelist(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 poolId,
    address whitelist
  ) external {
    _authenticate(DATASTORE, poolId, true, false, [false, true]);
    require(isPrivatePool(DATASTORE, poolId), "SML:must be private pool");

    DATASTORE.writeAddress(poolId, rks.whitelist, whitelist);
  }

  /**
   * @custom:visibility -> view-public
   */

  /**
   * @notice returns true if the pool is private
   */
  function isPrivatePool(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 poolId
  ) public view returns (bool) {
    return (DATASTORE.readUint(poolId, rks.privatePool) == 1);
  }

  /**
   * @notice checks if the Whitelist allows staker to use given private pool
   * @dev Owner of the pool doesn't need whitelisting
   * @dev Otherwise requires a whitelisting address to be set
   */
  function isWhitelisted(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 poolId,
    address staker
  ) public view returns (bool) {
    if (DATASTORE.readAddress(poolId, rks.CONTROLLER) == staker) {
      return true;
    }

    address whitelist = DATASTORE.readAddress(poolId, rks.whitelist);
    require(whitelist != address(0), "SML:no whitelist");

    return IWhitelist(whitelist).isAllowed(staker);
  }

  /**
   * @custom:section                           ** ID MANAGEMENT **
   *
   */

  /**
   * @custom:subsection                           ** MAINTAINER **
   */

  /**
   * @custom:visibility -> internal
   */

  /**
   * @notice Set the maintainer address on initiation or later
   * @param _newMaintainer address of the new maintainer
   */
  function _setMaintainer(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 _id,
    address _newMaintainer
  ) internal {
    require(_newMaintainer != address(0), "SML:maintainer can NOT be zero");

    DATASTORE.writeAddress(_id, rks.maintainer, _newMaintainer);
    emit MaintainerChanged(_id, _newMaintainer);
  }

  /**
   * @custom:visibility -> external
   */

  /**
   * @notice CONTROLLER of the ID can change the maintainer to any address other than ZERO_ADDRESS
   * @dev there can only be 1 maintainer per ID.
   * @dev it is wise to change the maintainer before the CONTROLLER, in case of any migration
   * @dev we don't use _authenticate here because malicious maintainers can imprison operators
   * * and prevent them entering here, smh.
   */
  function changeMaintainer(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 id,
    address newMaintainer
  ) external {
    require(DATASTORE.readUint(id, rks.initiated) != 0, "SML:ID is not initiated");
    require(msg.sender == DATASTORE.readAddress(id, rks.CONTROLLER), "SML:sender NOT CONTROLLER");
    uint256 typeOfId = DATASTORE.readUint(id, rks.TYPE);
    require(typeOfId == ID_TYPE.OPERATOR || typeOfId == ID_TYPE.POOL, "SML:invalid TYPE");

    _setMaintainer(DATASTORE, id, newMaintainer);
  }

  /**
   * @custom:subsection                           ** FEE **
   */

  /**
   * @custom:visibility -> view-public
   */

  /**
   * @notice Gets fee as a percentage, PERCENTAGE_DENOMINATOR = 100%
   *
   * @dev respecs to the switching delay.
   *
   * @return fee = percentage * PERCENTAGE_DENOMINATOR / 100
   */
  function getMaintenanceFee(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 id
  ) public view returns (uint256 fee) {
    if (DATASTORE.readUint(id, rks.feeSwitch) > block.timestamp) {
      return DATASTORE.readUint(id, rks.priorFee);
    }
    return DATASTORE.readUint(id, rks.fee);
  }

  /**
   * @custom:visibility -> internal
   */

  /**
   * @notice internal function to set fee with NO DELAY
   */
  function _setMaintenanceFee(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 _id,
    uint256 _newFee
  ) internal {
    require(_newFee <= MAX_MAINTENANCE_FEE, "SML:> MAX_MAINTENANCE_FEE ");
    DATASTORE.writeUint(_id, rks.fee, _newFee);
  }

  /**
   * @custom:visibility -> external
   */

  /**
   * @notice Changes the fee that is applied to the newly created validators, with A DELAY OF SWITCH_LATENCY.
   * @dev Can NOT be called again while its currently switching.
   * @dev advise that 100% == PERCENTAGE_DENOMINATOR
   */
  function switchMaintenanceFee(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 id,
    uint256 newFee
  ) external {
    _authenticate(DATASTORE, id, true, false, [true, true]);

    require(block.timestamp > DATASTORE.readUint(id, rks.feeSwitch), "SML:currently switching");

    DATASTORE.writeUint(id, rks.priorFee, DATASTORE.readUint(id, rks.fee));
    DATASTORE.writeUint(id, rks.feeSwitch, block.timestamp + SWITCH_LATENCY);

    _setMaintenanceFee(DATASTORE, id, newFee);

    emit FeeSwitched(id, newFee, block.timestamp + SWITCH_LATENCY);
  }

  /**
   * @custom:subsection                           ** INTERNAL WALLET **
   *
   * @dev Internal wallet of an ID accrues fees over time.
   * It is also used by Node Operators to fund 1 ETH per validator proposal, which is reimbursed if/when activated.
   */

  /**
   * @custom:visibility -> internal
   */

  /**
   * @notice Simply increases the balance of an IDs Maintainer wallet
   * @param _value Ether (in Wei) amount to increase the wallet balance.
   */
  function _increaseWalletBalance(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 _id,
    uint256 _value
  ) internal {
    DATASTORE.addUint(_id, rks.wallet, _value);
  }

  /**
   * @notice To decrease the balance of an Operator's wallet internally
   * @param _value Ether (in Wei) amount to decrease the wallet balance and send back to Maintainer.
   */
  function _decreaseWalletBalance(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 _id,
    uint256 _value
  ) internal {
    require(DATASTORE.readUint(_id, rks.wallet) >= _value, "SML:insufficient wallet balance");
    DATASTORE.subUint(_id, rks.wallet, _value);
  }

  /**
   * @custom:visibility -> external
   */

  /**
   * @notice external function to increase the internal wallet balance
   * @dev anyone can increase the balance directly, useful for withdrawalContracts and fees etc.
   */
  function increaseWalletBalance(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 id
  ) external returns (bool success) {
    _authenticate(DATASTORE, id, false, false, [true, true]);
    _increaseWalletBalance(DATASTORE, id, msg.value);
    success = true;
  }

  /**
   * @notice external function to decrease the internal wallet balance
   * @dev only CONTROLLER can decrease the balance externally,
   * @return success if the amount was sent and deducted
   */
  function decreaseWalletBalance(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 id,
    uint256 value
  ) external returns (bool success) {
    _authenticate(DATASTORE, id, true, false, [true, true]);

    require(address(this).balance >= value, "SML:insufficient contract balance");

    _decreaseWalletBalance(DATASTORE, id, value);
    address controller = DATASTORE.readAddress(id, rks.CONTROLLER);

    (success, ) = payable(controller).call{value: value}("");
    require(success, "SML:Failed to send ETH");
  }

  /**
   * @custom:subsection                           ** OPERATORS PERIOD **
   */

  /**
   * @custom:visibility -> view-public
   */

  function getValidatorPeriod(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 id
  ) public view returns (uint256 period) {
    if (DATASTORE.readUint(id, rks.periodSwitch) > block.timestamp) {
      return DATASTORE.readUint(id, rks.priorPeriod);
    }
    return DATASTORE.readUint(id, rks.validatorPeriod);
  }

  /**
   * @custom:visibility -> internal
   */

  /**
   * @notice internal function to set validator period with NO DELAY
   */
  function _setValidatorPeriod(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 _operatorId,
    uint256 _newPeriod
  ) internal {
    require(_newPeriod >= MIN_VALIDATOR_PERIOD, "SML:< MIN_VALIDATOR_PERIOD");
    require(_newPeriod <= MAX_VALIDATOR_PERIOD, "SML:> MAX_VALIDATOR_PERIOD");

    DATASTORE.writeUint(_operatorId, rks.validatorPeriod, _newPeriod);
  }

  /**
   * @custom:visibility -> external
   */

  /**
   * @notice updates validatorPeriod for given operator, with A DELAY OF SWITCH_LATENCY.
   * @dev limited by MIN_VALIDATOR_PERIOD and MAX_VALIDATOR_PERIOD
   */
  function switchValidatorPeriod(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 operatorId,
    uint256 newPeriod
  ) external {
    _authenticate(DATASTORE, operatorId, true, false, [true, false]);

    require(
      block.timestamp > DATASTORE.readUint(operatorId, rks.periodSwitch),
      "SML:currently switching"
    );

    DATASTORE.writeUint(
      operatorId,
      rks.priorPeriod,
      DATASTORE.readUint(operatorId, rks.validatorPeriod)
    );
    DATASTORE.writeUint(operatorId, rks.periodSwitch, block.timestamp + SWITCH_LATENCY);

    _setValidatorPeriod(DATASTORE, operatorId, newPeriod);

    emit ValidatorPeriodSwitched(operatorId, newPeriod, block.timestamp + SWITCH_LATENCY);
  }

  /**
   * @custom:section                           ** PRISON **
   *
   * When node operators act in a malicious way, which can also be interpereted as
   * an honest mistake like using a faulty signature, Oracle imprisons the operator.
   * These conditions are:
   * * 1. Created a malicious validator(alien): faulty withdrawal credential, faulty signatures etc.
   * * 2. Have not respect the validatorPeriod (or blamed for some other valid case)
   * * 3. Stole block fees or MEV boost rewards from the pool
   */

  /**
   * @custom:visibility -> view-public
   */

  /**
   * @notice Checks if the given operator is Prisoned
   * @dev rks.release key refers to the end of the last imprisonment, when the limitations of operator is lifted
   */
  function isPrisoned(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 operatorId
  ) public view returns (bool) {
    return (block.timestamp < DATASTORE.readUint(operatorId, rks.release));
  }

  /**
   * @custom:visibility -> internal
   */

  /**
   * @notice Put an operator in prison
   * @dev rks.release key refers to the end of the last imprisonment, when the limitations of operator is lifted
   */
  function _imprison(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 _operatorId,
    bytes calldata _proof
  ) internal {
    _authenticate(DATASTORE, _operatorId, false, false, [true, false]);

    DATASTORE.writeUint(_operatorId, rks.release, block.timestamp + PRISON_SENTENCE);

    emit Prisoned(_operatorId, _proof, block.timestamp + PRISON_SENTENCE);
  }

  /**
   * @custom:visibility -> external
   */

  /**
   * @notice allows imprisoning an Operator if the validator have not been exited until expected exit
   * @dev anyone can call this function while the state is ACTIVE
   * @dev if operator has given enough allowance, they SHOULD rotate the validators to avoid being prisoned
   *
   * @dev this function lacks 2 other punishable acts:
   * 1. while state is PROPOSED: validator proposed, it is passed, but haven't been created even tho it has been a MAX_BEACON_DELAY
   * 2. while state is EXIT_REQUESTED:  validator requested exit, but it haven't been executed even tho it has been MAX_BEACON_DELAY
   */
  function blameOperator(
    PooledStaking storage self,
    DSML.IsolatedStorage storage DATASTORE,
    bytes calldata pk
  ) external {
    require(
      self.validators[pk].state == VALIDATOR_STATE.ACTIVE,
      "SML:validator is never activated"
    );
    require(
      block.timestamp > self.validators[pk].createdAt + self.validators[pk].period,
      "SML:validator is active"
    );

    _imprison(DATASTORE, self.validators[pk].operatorId, pk);
  }

  /**
   * @custom:section                           ** VALIDATOR DELEGATION **
   */

  /**
   * @custom:visibility -> view-public
   */

  /**
   * @notice maximum number of remaining operator allowance that the given Operator is allowed to create for given Pool
   * @dev an operator can not create new validators if:
   * * 1. if operator is a monopoly
   * * 2. allowance is filled
   * * * But if operator is set as a fallback, it can if FALLBACK_THRESHOLD (80%) is reached on all allowances.
   * @dev If operator withdraws a validator, then able to create a new one.
   * @dev prestake checks the approved validator count to make sure the number of validators are not bigger than allowance
   * @dev allowance doesn't change when new validators created or old ones are unstaked.
   */
  function operatorAllowance(
    PooledStaking storage self,
    DSML.IsolatedStorage storage DATASTORE,
    uint256 poolId,
    uint256 operatorId
  ) public view returns (uint256 remValidators) {
    // monopoly check
    {
      // readUint for an array gives us length
      uint256 numOperatorValidators = DATASTORE.readUint(operatorId, rks.validators);
      uint256 monopoly_threshold = self.MONOPOLY_THRESHOLD;
      if (numOperatorValidators >= monopoly_threshold) {
        return 0;
      } else {
        remValidators = monopoly_threshold - numOperatorValidators;
      }
    }

    // fallback check
    {
      if (operatorId == DATASTORE.readUint(poolId, rks.fallbackOperator)) {
        // readUint for an array gives us length
        uint256 numPoolValidators = DATASTORE.readUint(poolId, rks.validators);
        uint256 totalAllowance = DATASTORE.readUint(poolId, rks.totalAllowance);
        if (
          totalAllowance == 0 ||
          (((numPoolValidators * PERCENTAGE_DENOMINATOR) / totalAllowance) >= FALLBACK_THRESHOLD)
        ) {
          return remValidators;
        }
      }
    }

    // approval check
    {
      uint256 allowance = DATASTORE.readUint(poolId, DSML.getKey(operatorId, rks.allowance));
      uint256 pooledValidators = DATASTORE.readUint(
        poolId,
        DSML.getKey(operatorId, rks.proposedValidators)
      ) + DATASTORE.readUint(poolId, DSML.getKey(operatorId, rks.activeValidators));
      if (pooledValidators >= allowance) {
        return 0;
      } else {
        uint256 remAllowance = allowance - pooledValidators;
        if (remValidators > remAllowance) {
          remValidators = remAllowance;
        }
      }
    }
  }

  /**
   * @custom:visibility -> internal
   */

  function _setFallbackOperator(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 poolId,
    uint256 operatorId
  ) internal {
    DATASTORE.writeUint(poolId, rks.fallbackOperator, operatorId);
    emit FallbackOperator(poolId, operatorId);
  }

  function _approveOperator(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 poolId,
    uint256 operatorId,
    uint256 allowance
  ) internal returns (uint256 oldAllowance) {
    bytes32 allowanceKey = DSML.getKey(operatorId, rks.allowance);

    oldAllowance = DATASTORE.readUint(poolId, allowanceKey);
    DATASTORE.writeUint(poolId, allowanceKey, allowance);

    emit Delegation(poolId, operatorId, allowance);
  }

  /**
   * @custom:visibility -> external
   */

  /**
   * @notice To allow a Node Operator run validators for your Pool with a given number of validators.
   * * This number can be set again at any given point in the future.
   * @param poolId the gETH id of the Pool
   * @param operatorIds array of Operator IDs to allow them create validators
   * @param allowances the MAX number of validators that can be created by the Operator, for given Pool
   * @dev When decreased the approved validator count below current active+proposed validators,
   * operator can NOT create new validators.
   */
  function delegate(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 poolId,
    uint256[] calldata operatorIds,
    uint256[] calldata allowances,
    uint256 fallbackOperator
  ) external {
    _authenticate(DATASTORE, poolId, false, true, [false, true]);
    require(operatorIds.length == allowances.length, "SML:allowances should match");
    for (uint256 i = 0; i < operatorIds.length; ) {
      require(
        DATASTORE.readUint(operatorIds[i], rks.TYPE) == ID_TYPE.OPERATOR,
        "SML:id not operator"
      );
      require(allowances[i] < MAX_ALLOWANCE, "SML:> MAX_ALLOWANCE, set fallback");
      unchecked {
        i += 1;
      }
    }

    if (fallbackOperator != 0) {
      require(
        DATASTORE.readUint(fallbackOperator, rks.TYPE) == ID_TYPE.OPERATOR,
        "SML:fallback not operator"
      );
    }

    uint256 newCumulativeSubset;
    uint256 oldCumulativeSubset;
    for (uint256 i = 0; i < operatorIds.length; ) {
      newCumulativeSubset += allowances[i];
      oldCumulativeSubset += _approveOperator(DATASTORE, poolId, operatorIds[i], allowances[i]);
      unchecked {
        i += 1;
      }
    }

    if (newCumulativeSubset > oldCumulativeSubset) {
      DATASTORE.addUint(poolId, rks.totalAllowance, newCumulativeSubset - oldCumulativeSubset);
    } else if (newCumulativeSubset < oldCumulativeSubset) {
      DATASTORE.subUint(poolId, rks.totalAllowance, oldCumulativeSubset - newCumulativeSubset);
    }

    _setFallbackOperator(DATASTORE, poolId, fallbackOperator);
  }

  /**
   * @custom:section                           ** POOLING  **
   */

  /**
   * @custom:subsection                           ** DEPOSIT HELPERS **
   */

  /**
   * @custom:visibility -> view-internal
   */

  function _isGeodePackageIsolated(address _packageAddress) internal view returns (bool) {
    return IGeodePackage(_packageAddress).isolationMode();
  }

  /**
   * @notice returns wrapped bound liquidity pool. If deployed, if not in isolationMode.
   * @dev returns address(0) if no pool or it is under isolation
   */
  function _getLiquidityPool(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 _poolId
  ) internal view returns (ILiquidityPool) {
    address liqPool = DATASTORE.readAddress(_poolId, rks.liquidityPool);
    if (liqPool == address(0)) {
      return ILiquidityPool(address(0));
    } else if (_isGeodePackageIsolated(liqPool)) {
      return ILiquidityPool(address(0));
    } else {
      return ILiquidityPool(liqPool);
    }
  }

  /**
   * @custom:visibility -> view-public
   */

  /**
   * @notice returns true if the price is valid:
   * - last price syncinc happened less than 24h
   * - there has been no oracle reports since the last update
   *
   * @dev known bug / feature: if there have been no oracle updates,
   * * this function will return true.
   *
   * lastupdate + PRICE_EXPIRY >= block.timestamp ? true
   *    : lastupdate >= self.ORACLE_UPDATE_TIMESTAMP ? true
   *    : false
   */
  function isPriceValid(
    PooledStaking storage self,
    uint256 poolId
  ) public view returns (bool isValid) {
    uint256 lastupdate = self.gETH.priceUpdateTimestamp(poolId);
    unchecked {
      isValid =
        lastupdate + PRICE_EXPIRY >= block.timestamp &&
        lastupdate >= self.ORACLE_UPDATE_TIMESTAMP;
    }
  }

  /**
   * @notice checks if staking is allowed in given staking pool
   * @notice staking is not allowed if:
   * 1. Price is not valid
   * 2. WithdrawalContract is in Isolation Mode, can have many reasons
   */
  function isMintingAllowed(
    PooledStaking storage self,
    DSML.IsolatedStorage storage DATASTORE,
    uint256 poolId
  ) public view returns (bool) {
    return
      (isPriceValid(self, poolId)) &&
      !(_isGeodePackageIsolated(DATASTORE.readAddress(poolId, rks.withdrawalContract)));
  }

  /**
   * @custom:subsection                           ** DEPOSIT **
   */

  /**
   * @custom:visibility -> internal
   */

  /**
   * @notice mints gETH for a given ETH amount, keeps the tokens in Portal.
   * @dev fails if minting is not allowed: invalid price, or isolationMode.
   */
  function _mintgETH(
    PooledStaking storage self,
    DSML.IsolatedStorage storage DATASTORE,
    uint256 _poolId,
    uint256 _ethAmount
  ) internal returns (uint256 mintedgETH) {
    require(isMintingAllowed(self, DATASTORE, _poolId), "SML:minting is not allowed");

    uint256 price = self.gETH.pricePerShare(_poolId);
    require(price > 0, "SML:price is zero?");

    mintedgETH = (((_ethAmount * self.gETH.denominator()) / price));
    self.gETH.mint(address(this), _poolId, mintedgETH, "");
    DATASTORE.addUint(_poolId, rks.surplus, _ethAmount);
  }

  /**
   * @notice conducts a buyback using the given liquidity pool
   * @param _poolId id of the gETH that will be bought
   * @param _maxEthToSell max ETH amount to sell in the liq pool
   * @param _deadline TX is expected to revert by Swap.sol if not meet
   * @dev this function assumes that pool is deployed by deployLiquidityPool
   * as index 0 is ETH and index 1 is gETH!
   */
  function _buyback(
    DSML.IsolatedStorage storage DATASTORE,
    uint256 _poolId,
    uint256 _maxEthToSell,
    uint256 _deadline
  ) internal returns (uint256 remETH, uint256 boughtgETH) {
    ILiquidityPool LP = _getLiquidityPool(DATASTORE, _poolId);
    // skip if no liquidity pool is found
    if (address(LP) != address(0)) {
      uint256 debt = LP.getDebt();
      // skip if debt is too low
      if (debt > IGNORABLE_DEBT) {
        if (_maxEthToSell > debt) {
          // if debt is lower, then only sell debt
          remETH = _maxEthToSell - debt;
        } else {
          // if eth is lower, then sell all eth, remETH already 0
          debt = _maxEthToSell;
        }
        // SWAP in LP
        boughtgETH = LP.swap{value: debt}(0, 1, debt, 0, _deadline);
      } else {
        remETH = _maxEthToSell;
      }
    } else {
      remETH = _maxEthToSell;
    }
  }

  /**
   * @custom:visibility -> external
   */

  /**
   * @notice Allowing users to deposit into a staking pool.
   * @notice If a pool is not public only the maintainer can deposit.
   * @param poolId id of the staking pool, liquidity pool and gETH to be used.
   * @param mingETH liquidity pool parameter
   * @param deadline liquidity pool parameter
   * @dev an example for minting + buybacks
   * Buys from DWP if price is low -debt-, mints new tokens if surplus is sent -more than debt-
   * * debt  msgValue
   * * 100   10  => buyback
   * * 100   100 => buyback
   * * 10    100 => buyback + mint
   * * 1     x   => mint
   * * 0.5   x   => mint
   * * 0     x   => mint
   */
  function deposit(
    PooledStaking storage self,
    DSML.IsolatedStorage storage DATASTORE,
    uint256 poolId,
    uint256 mingETH,
    uint256 deadline,
    address receiver
  ) external returns (uint256 boughtgETH, uint256 mintedgETH) {
    _authenticate(DATASTORE, poolId, false, false, [false, true]);
    require(deadline > block.timestamp, "SML:deadline not met");
    require(receiver != address(0), "SML:receiver is zero address");

    if (isPrivatePool(DATASTORE, poolId)) {
      require(isWhitelisted(DATASTORE, poolId, msg.sender), "SML:sender NOT whitelisted");
    }

    uint256 remEth = msg.value;
    (remEth, boughtgETH) = _buyback(DATASTORE, poolId, remEth, deadline);

    if (remEth > 0) {
      mintedgETH = _mintgETH(self, DATASTORE, poolId, remEth);
    }

    require(boughtgETH + mintedgETH >= mingETH, "SML:less than minimum");

    // send back to user
    self.gETH.safeTransferFrom(address(this), receiver, poolId, boughtgETH + mintedgETH, "");

    emit Deposit(poolId, boughtgETH, mintedgETH);
  }

  /**
   * @custom:section                           ** VALIDATOR CREATION **
   *
   * @dev Creation of a Validator takes 2 steps: propose and beacon stake.
   * Before entering stake() function, _canStake verifies the eligibility of
   * given pubKey that is proposed by an operator with proposeStake function.
   * Eligibility is defined by an optimistic alienation, check OracleUtils._alienateValidator() for info.
   */

  /**
   * @custom:visibility -> view
   */

  /**
   * @notice internal function to check if a validator can use the pool funds
   *
   *  @param _pubkey BLS12-381 public key of the validator
   *  @return true if:
   *   - pubkey should be proposed
   *   - pubkey should not be alienated (https://bit.ly/3Tkc6UC)
   *   - validator's index should be covered by VERIFICATION_INDEX. Updated by Telescope.
   * Note: while distributing the rewards, if a validator has 1 Eth, it is safe to assume that the balance belongs to Operator
   */
  function _canStake(
    PooledStaking storage self,
    bytes calldata _pubkey,
    uint256 _verificationIndex
  ) internal view returns (bool) {
    return
      (self.validators[_pubkey].state == VALIDATOR_STATE.PROPOSED) &&
      (self.validators[_pubkey].index <= _verificationIndex);
  }

  /**
   * @notice external function to check if a validator can use the pool funds
   */
  function canStake(
    PooledStaking storage self,
    bytes calldata pubkey
  ) external view returns (bool) {
    return _canStake(self, pubkey, self.VERIFICATION_INDEX);
  }

  /**
   * @dev -> external
   */

  /**
   * @notice Validator Credentials Proposal function, first step of crating validators.
   * * Once a pubKey is proposed and not alienated after verificationIndex updated,
   * * it is optimistically allowed to take funds from staking pools.
   *
   * @param poolId the id of the staking pool
   * @param operatorId the id of the Operator whose maintainer calling this function
   * @param pubkeys  Array of BLS12-381 public keys of the validators that will be proposed
   * @param signatures1 Array of BLS12-381 signatures that will be used to send 1 ETH from the Operator's
   * maintainer balance
   * @param signatures31 Array of BLS12-381 signatures that will be used to send 31 ETH from pool on stake() function call
   *
   * @dev DCL.DEPOSIT_AMOUNT_PRESTAKE = 1 ether, DCL.DEPOSIT_AMOUNT = 32 ether which is the minimum amount to create a validator.
   * 31 Ether will be staked after verification of oracles. 32 in total.
   * 1 ether will be sent back to Node Operator when the finalized deposit is successful.
   * @dev ProposeStake requires enough allowance from Staking Pools to Operators.
   * @dev ProposeStake requires enough funds within Wallet.
   * @dev Max number of validators to propose is per call is MAX_DEPOSITS_PER_CALL (currently 50)
   */
  function proposeStake(
    PooledStaking storage self,
    DSML.IsolatedStorage storage DATASTORE,
    uint256 poolId,
    uint256 operatorId,
    bytes[] calldata pubkeys,
    bytes[] calldata signatures1,
    bytes[] calldata signatures31
  ) external {
    // checks
    _authenticate(DATASTORE, operatorId, false, true, [true, false]);
    _authenticate(DATASTORE, poolId, false, false, [false, true]);
    require(
      !(_isGeodePackageIsolated(DATASTORE.readAddress(poolId, rks.withdrawalContract))),
      "SML:withdrawalContract is isolated"
    );

    uint256 pkLen = pubkeys.length;

    require((pkLen > 0) && (pkLen <= DCL.MAX_DEPOSITS_PER_CALL), "SML:1 - 50 validators");

    require(
      pkLen == signatures1.length && pkLen == signatures31.length,
      "SML:invalid input length"
    );

    require(
      operatorAllowance(self, DATASTORE, poolId, operatorId) >= pkLen,
      "SML:insufficient allowance"
    );

    require(
      DATASTORE.readUint(poolId, rks.surplus) >= DCL.DEPOSIT_AMOUNT * pkLen,
      "SML:NOT enough surplus"
    );

    for (uint256 i = 0; i < pkLen; ) {
      require(pubkeys[i].length == DCL.PUBKEY_LENGTH, "SML:PUBKEY_LENGTH ERROR");
      require(signatures1[i].length == DCL.SIGNATURE_LENGTH, "SML:SIGNATURE_LENGTH ERROR");
      require(signatures31[i].length == DCL.SIGNATURE_LENGTH, "SML:SIGNATURE_LENGTH ERROR");
      unchecked {
        i += 1;
      }
    }

    ConstantValidatorData memory valData = ConstantValidatorData({
      index: uint64(self.VALIDATORS_INDEX + 1),
      period: uint64(getValidatorPeriod(DATASTORE, operatorId)),
      poolFee: getMaintenanceFee(DATASTORE, poolId),
      operatorFee: getMaintenanceFee(DATASTORE, operatorId),
      governanceFee: self.GOVERNANCE_FEE,
      withdrawalCredential: DATASTORE.readBytes(poolId, rks.withdrawalCredential)
    });

    for (uint256 i = 0; i < pkLen; ) {
      require(
        self.validators[pubkeys[i]].state == VALIDATOR_STATE.NONE,
        "SML: used or alienated pk"
      );

      self.validators[pubkeys[i]] = Validator(
        VALIDATOR_STATE.PROPOSED,
        valData.index + uint64(i),
        uint64(block.timestamp),
        valData.period,
        poolId,
        operatorId,
        valData.poolFee,
        valData.operatorFee,
        valData.governanceFee,
        signatures31[i]
      );

      DCL.depositValidator(
        pubkeys[i],
        valData.withdrawalCredential,
        signatures1[i],
        DCL.DEPOSIT_AMOUNT_PRESTAKE
      );

      unchecked {
        i += 1;
      }
    }

    _decreaseWalletBalance(DATASTORE, operatorId, (pkLen * DCL.DEPOSIT_AMOUNT_PRESTAKE));

    DATASTORE.subUint(poolId, rks.surplus, (pkLen * DCL.DEPOSIT_AMOUNT));
    DATASTORE.addUint(poolId, rks.secured, (pkLen * DCL.DEPOSIT_AMOUNT));

    DATASTORE.addUint(poolId, DSML.getKey(operatorId, rks.proposedValidators), pkLen);
    DATASTORE.appendBytesArrayBatch(poolId, rks.validators, pubkeys);
    DATASTORE.appendBytesArrayBatch(operatorId, rks.validators, pubkeys);

    self.VALIDATORS_INDEX += pkLen;

    emit StakeProposal(poolId, operatorId, pubkeys);
  }

  /**
   *  @notice Sends 31 Eth from staking pool to validators that are previously created with ProposeStake.
   *  1 Eth per successful validator boostraping is returned back to Wallet.
   *
   *  @param operatorId the id of the Operator whose maintainer calling this function
   *  @param pubkeys  Array of BLS12-381 public keys of the validators that are already proposed with ProposeStake.
   *
   *  @dev To save gas cost, pubkeys should be arranged by poolIds.
   *  ex: [pk1, pk2, pk3, pk4, pk5, pk6, pk7]
   *  pk1, pk2, pk3 from pool1
   *  pk4, pk5 from pool2
   *  pk6 from pool3
   *  seperate them in similar groups as much as possible.
   *  @dev Max number of validators to boostrap is MAX_DEPOSITS_PER_CALL (currently 50)
   *  @dev A pubkey that is alienated will not get through. Do not frontrun during ProposeStake.
   */
  function stake(
    PooledStaking storage self,
    DSML.IsolatedStorage storage DATASTORE,
    uint256 operatorId,
    bytes[] calldata pubkeys
  ) external {
    _authenticate(DATASTORE, operatorId, false, true, [true, false]);

    require(
      (pubkeys.length > 0) && (pubkeys.length <= DCL.MAX_DEPOSITS_PER_CALL),
      "SML:1 - 50 validators"
    );

    {
      uint256 _verificationIndex = self.VERIFICATION_INDEX;
      for (uint256 j = 0; j < pubkeys.length; ) {
        require(
          _canStake(self, pubkeys[j], _verificationIndex),
          "SML:NOT all pubkeys are stakeable"
        );

        unchecked {
          j += 1;
        }
      }
    }

    {
      bytes32 activeValKey = DSML.getKey(operatorId, rks.activeValidators);
      bytes32 proposedValKey = DSML.getKey(operatorId, rks.proposedValidators);
      uint256 poolId = self.validators[pubkeys[0]].poolId;
      bytes memory withdrawalCredential = DATASTORE.readBytes(poolId, rks.withdrawalCredential);

      uint256 lastIdChange = 0;
      for (uint256 i = 0; i < pubkeys.length; ) {
        uint256 newPoolId = self.validators[pubkeys[i]].poolId;
        if (poolId != newPoolId) {
          uint256 sinceLastIdChange;

          unchecked {
            sinceLastIdChange = i - lastIdChange;
          }

          DATASTORE.subUint(poolId, rks.secured, (DCL.DEPOSIT_AMOUNT * (sinceLastIdChange)));
          DATASTORE.subUint(poolId, proposedValKey, (sinceLastIdChange));
          DATASTORE.addUint(poolId, activeValKey, (sinceLastIdChange));

          lastIdChange = i;
          poolId = newPoolId;
          withdrawalCredential = DATASTORE.readBytes(poolId, rks.withdrawalCredential);
        }

        DCL.depositValidator(
          pubkeys[i],
          withdrawalCredential,
          self.validators[pubkeys[i]].signature31,
          (DCL.DEPOSIT_AMOUNT - DCL.DEPOSIT_AMOUNT_PRESTAKE)
        );

        self.validators[pubkeys[i]].state = VALIDATOR_STATE.ACTIVE;

        unchecked {
          i += 1;
        }
      }
      {
        uint256 sinceLastIdChange;
        unchecked {
          sinceLastIdChange = pubkeys.length - lastIdChange;
        }
        if (sinceLastIdChange > 0) {
          DATASTORE.subUint(poolId, rks.secured, DCL.DEPOSIT_AMOUNT * (sinceLastIdChange));
          DATASTORE.subUint(poolId, proposedValKey, (sinceLastIdChange));
          DATASTORE.addUint(poolId, activeValKey, (sinceLastIdChange));
        }
      }

      _increaseWalletBalance(DATASTORE, operatorId, DCL.DEPOSIT_AMOUNT_PRESTAKE * pubkeys.length);

      emit Stake(pubkeys);
    }
  }
}
