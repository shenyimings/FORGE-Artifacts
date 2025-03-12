// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// globals
import {PERCENTAGE_DENOMINATOR} from "../../globals/macros.sol";
// interfaces
import {IgETH} from "../../interfaces/IgETH.sol";
import {IStakeModule} from "../../interfaces/modules/IStakeModule.sol";
// libraries
import {StakeModuleLib as SML} from "./libs/StakeModuleLib.sol";
import {OracleExtensionLib as OEL} from "./libs/OracleExtensionLib.sol";
// contracts
import {DataStoreModule} from "../DataStoreModule/DataStoreModule.sol";
// external
import {ERC1155HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/**
 * @title SM: Stake Module
 *
 * @notice Liquid staking for everyone.
 * * pooling and staking for staking derivatives
 * * validator delegation and operator onboarding
 * * oracle operations such as pricing
 *
 * @dev review: this module delegates its functionality to SML (StakeModuleLib).
 * * SML has authenticate function for access control.
 * @dev review: OEL (OracleExtensionLib) is an extension for oracle operations.
 * @dev review: DCL (DepositContractLib) is an helper for validator creation.
 *
 * @dev There are 1 additional functionality implemented seperately from the library:
 * * check price validity and accept proofs for updating the price (refer to deposit function).
 * * However, this module inherits and implements nonReentrant & whenNotPaused modifiers.
 * * SM has pausability and expects inheriting contract to provide the access control mechanism.
 *
 * @dev 2 functions need to be overriden when inherited: pause, unpause.
 *
 * @dev __StakeModule_init (or _unchained) call is NECESSARY when inherited.
 *
 * @dev This module inherits DataStoreModule.
 *
 * @author Ice Bear & Crash Bandicoot
 */
abstract contract StakeModule is
  IStakeModule,
  DataStoreModule,
  ERC1155HolderUpgradeable,
  PausableUpgradeable,
  ReentrancyGuardUpgradeable
{
  using SML for SML.PooledStaking;
  using OEL for SML.PooledStaking;

  /**
   * @custom:section                           ** VARIABLES **
   *
   * @dev Do not add any other variables here. Modules do NOT have a gap.
   * Library's main struct has a gap, providing up to 16 storage slots for this module.
   */
  SML.PooledStaking internal STAKE;

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

  event Alienated(bytes pubkey);
  event VerificationIndexUpdated(uint256 validatorVerificationIndex);
  event FeeTheft(uint256 indexed id, bytes proofs);
  event OracleReported(
    bytes32 priceMerkleRoot,
    bytes32 balanceMerkleRoot,
    uint256 monopolyThreshold
  );

  /**
   * @custom:section                           ** ABSTRACT FUNCTIONS **
   */
  function pause() external virtual override;

  function unpause() external virtual override;

  /**
   * @custom:section                           ** INITIALIZING **
   */
  function __StakeModule_init(address _gETH, address _oracle_position) internal onlyInitializing {
    __ReentrancyGuard_init();
    __Pausable_init();
    __ERC1155Holder_init();
    __DataStoreModule_init();
    __StakeModule_init_unchained(_gETH, _oracle_position);
  }

  function __StakeModule_init_unchained(
    address _gETH,
    address _oracle_position
  ) internal onlyInitializing {
    require(_gETH != address(0));
    require(_oracle_position != address(0));
    STAKE.gETH = IgETH(_gETH);
    STAKE.ORACLE_POSITION = _oracle_position;
    STAKE.DAILY_PRICE_INCREASE_LIMIT = (7 * PERCENTAGE_DENOMINATOR) / 100;
    STAKE.DAILY_PRICE_DECREASE_LIMIT = (7 * PERCENTAGE_DENOMINATOR) / 100;
  }

  /**
   * @custom:section                           ** GETTER FUNCTIONS **
   *
   * @custom:visibility -> view-external
   */

  function StakeParams()
    external
    view
    virtual
    override
    returns (
      address gETH,
      address oraclePosition,
      uint256 validatorsIndex,
      uint256 verificationIndex,
      uint256 monopolyThreshold,
      uint256 oracleUpdateTimestamp,
      uint256 dailyPriceIncreaseLimit,
      uint256 dailyPriceDecreaseLimit,
      uint256 governanceFee,
      bytes32 priceMerkleRoot,
      bytes32 balanceMerkleRoot
    )
  {
    gETH = address(STAKE.gETH);
    oraclePosition = STAKE.ORACLE_POSITION;
    validatorsIndex = STAKE.VALIDATORS_INDEX;
    verificationIndex = STAKE.VERIFICATION_INDEX;
    monopolyThreshold = STAKE.MONOPOLY_THRESHOLD;
    oracleUpdateTimestamp = STAKE.ORACLE_UPDATE_TIMESTAMP;
    dailyPriceIncreaseLimit = STAKE.DAILY_PRICE_INCREASE_LIMIT;
    dailyPriceDecreaseLimit = STAKE.DAILY_PRICE_DECREASE_LIMIT;
    governanceFee = STAKE.GOVERNANCE_FEE;
    priceMerkleRoot = STAKE.PRICE_MERKLE_ROOT;
    balanceMerkleRoot = STAKE.BALANCE_MERKLE_ROOT;
  }

  function getValidator(
    bytes calldata pubkey
  ) external view virtual override returns (SML.Validator memory) {
    return STAKE.validators[pubkey];
  }

  function getPackageVersion(uint256 _type) external view virtual override returns (uint256) {
    return STAKE.packages[_type];
  }

  function isMiddleware(
    uint256 _type,
    uint256 _version
  ) external view virtual override returns (bool) {
    return STAKE.middlewares[_type][_version];
  }

  /**
   * @custom:section                           ** OPERATOR INITIATORS **
   *
   * @custom:visibility -> external
   */
  function initiateOperator(
    uint256 id,
    uint256 fee,
    uint256 validatorPeriod,
    address maintainer
  ) external payable virtual override whenNotPaused nonReentrant {
    SML.initiateOperator(DATASTORE, id, fee, validatorPeriod, maintainer);
  }

  /**
   * @custom:section                           ** STAKING POOL INITIATOR **
   *
   * @custom:visibility -> external
   */

  function initiatePool(
    uint256 fee,
    uint256 middlewareVersion,
    address maintainer,
    bytes calldata NAME,
    bytes calldata middleware_data,
    bool[3] calldata config
  ) external payable virtual override whenNotPaused returns (uint256 poolId) {
    poolId = STAKE.initiatePool(
      DATASTORE,
      fee,
      middlewareVersion,
      maintainer,
      NAME,
      middleware_data,
      config
    );
  }

  /**
   * @custom:subsection                           ** POOL VISIBILITY **
   */

  function setPoolVisibility(uint256 poolId, bool makePrivate) external virtual override {
    SML.setPoolVisibility(DATASTORE, poolId, makePrivate);
  }

  function setWhitelist(uint256 poolId, address whitelist) external virtual override {
    SML.setWhitelist(DATASTORE, poolId, whitelist);
  }

  /**
   * @custom:visibility -> view
   */
  function isPrivatePool(uint256 poolId) external view virtual override returns (bool) {
    return SML.isPrivatePool(DATASTORE, poolId);
  }

  function isWhitelisted(
    uint256 poolId,
    address staker
  ) external view virtual override returns (bool) {
    return SML.isWhitelisted(DATASTORE, poolId, staker);
  }

  /**
   * @custom:subsection                           ** BOUND LIQUIDITY POOL **
   */

  function deployLiquidityPool(uint256 poolId) external virtual override whenNotPaused {
    STAKE.deployLiquidityPool(DATASTORE, poolId);
  }

  /**
   * @custom:section                           ** ID MANAGEMENT **
   *
   * @custom:visibility -> external
   */

  /**
   * @custom:subsection                           ** MAINTAINER **
   */

  function changeMaintainer(
    uint256 poolId,
    address newMaintainer
  ) external virtual override whenNotPaused {
    SML.changeMaintainer(DATASTORE, poolId, newMaintainer);
  }

  /**
   * @custom:subsection                           ** FEE **
   */

  function switchMaintenanceFee(
    uint256 id,
    uint256 newFee
  ) external virtual override whenNotPaused {
    SML.switchMaintenanceFee(DATASTORE, id, newFee);
  }

  /**
   * @custom:visibility -> view
   */
  function getMaintenanceFee(uint256 id) external view virtual override returns (uint256) {
    return SML.getMaintenanceFee(DATASTORE, id);
  }

  /**
   * @custom:section                           ** INTERNAL WALLET **
   */

  function increaseWalletBalance(
    uint256 id
  ) external payable virtual override whenNotPaused nonReentrant returns (bool) {
    return SML.increaseWalletBalance(DATASTORE, id);
  }

  function decreaseWalletBalance(
    uint256 id,
    uint256 value
  ) external virtual override nonReentrant returns (bool) {
    return SML.decreaseWalletBalance(DATASTORE, id, value);
  }

  /**
   * @custom:section                           ** OPERATORS PERIOD **
   *
   * @custom:visibility -> external
   */

  function switchValidatorPeriod(
    uint256 operatorId,
    uint256 newPeriod
  ) external virtual override whenNotPaused {
    SML.switchValidatorPeriod(DATASTORE, operatorId, newPeriod);
  }

  /**
   * @custom:visibility -> view
   */
  function getValidatorPeriod(uint256 id) external view virtual override returns (uint256) {
    return SML.getValidatorPeriod(DATASTORE, id);
  }

  /**
   * @custom:section                           ** PRISON **
   *
   * @custom:visibility -> external
   */
  function blameOperator(bytes calldata pk) external virtual override whenNotPaused {
    STAKE.blameOperator(DATASTORE, pk);
  }

  /**
   * @custom:visibility -> view
   */
  function isPrisoned(uint256 operatorId) external view virtual override returns (bool) {
    return SML.isPrisoned(DATASTORE, operatorId);
  }

  /**
   * @custom:section                           ** DELEGATION **
   *
   * @custom:visibility -> external
   */

  function delegate(
    uint256 poolId,
    uint256[] calldata operatorIds,
    uint256[] calldata allowances,
    uint256 fallbackOperator
  ) external virtual override whenNotPaused {
    SML.delegate(DATASTORE, poolId, operatorIds, allowances, fallbackOperator);
  }

  /**
   * @custom:visibility -> view
   */
  function operatorAllowance(
    uint256 poolId,
    uint256 operatorId
  ) external view virtual override returns (uint256) {
    return STAKE.operatorAllowance(DATASTORE, poolId, operatorId);
  }

  /**
   * @custom:section                           ** DEPOSIT GETTERS **
   *
   * @custom:visibility -> view-external
   */

  function isPriceValid(uint256 poolId) external view virtual override returns (bool) {
    return STAKE.isPriceValid(poolId);
  }

  function isMintingAllowed(uint256 poolId) external view virtual override returns (bool) {
    return STAKE.isMintingAllowed(DATASTORE, poolId);
  }

  /**
   * @custom:section                           ** POOLING OPERATIONS **
   *
   * @custom:visibility -> external
   */
  function deposit(
    uint256 poolId,
    uint256 price,
    bytes32[] calldata priceProof,
    uint256 mingETH,
    uint256 deadline,
    address receiver
  )
    external
    payable
    virtual
    override
    whenNotPaused
    nonReentrant
    returns (uint256 boughtgETH, uint256 mintedgETH)
  {
    if (!STAKE.isPriceValid(poolId)) {
      STAKE.priceSync(DATASTORE, poolId, price, priceProof);
    }

    (boughtgETH, mintedgETH) = STAKE.deposit(DATASTORE, poolId, mingETH, deadline, receiver);
  }

  /**
   * @custom:section                           ** VALIDATOR CREATION **
   *
   * @custom:visibility -> external
   */
  function proposeStake(
    uint256 poolId,
    uint256 operatorId,
    bytes[] calldata pubkeys,
    bytes[] calldata signatures1,
    bytes[] calldata signatures31
  ) external virtual override whenNotPaused {
    STAKE.proposeStake(DATASTORE, poolId, operatorId, pubkeys, signatures1, signatures31);
  }

  function stake(
    uint256 operatorId,
    bytes[] calldata pubkeys
  ) external virtual override whenNotPaused {
    STAKE.stake(DATASTORE, operatorId, pubkeys);
  }

  /**
   * @custom:visibility -> view
   */
  function canStake(bytes calldata pubkey) external view virtual override returns (bool) {
    return STAKE.canStake(pubkey);
  }

  /**
   * @custom:section                           ** ORACLE OPERATIONS **
   *
   * @custom:visibility -> external
   */

  function updateVerificationIndex(
    uint256 validatorVerificationIndex,
    bytes[] calldata alienatedPubkeys
  ) external virtual override whenNotPaused {
    STAKE.updateVerificationIndex(DATASTORE, validatorVerificationIndex, alienatedPubkeys);
  }

  function regulateOperators(
    uint256[] calldata feeThefts,
    bytes[] calldata proofs
  ) external virtual override whenNotPaused {
    STAKE.regulateOperators(DATASTORE, feeThefts, proofs);
  }

  function reportBeacon(
    bytes32 priceMerkleRoot,
    bytes32 balanceMerkleRoot,
    uint256 allValidatorsCount
  ) external virtual override whenNotPaused {
    STAKE.reportBeacon(priceMerkleRoot, balanceMerkleRoot, allValidatorsCount);
  }

  function priceSync(
    uint256 poolId,
    uint256 price,
    bytes32[] calldata priceProof
  ) external virtual override whenNotPaused {
    STAKE.priceSync(DATASTORE, poolId, price, priceProof);
  }

  function priceSyncBatch(
    uint256[] calldata poolIds,
    uint256[] calldata prices,
    bytes32[][] calldata priceProofs
  ) external virtual override whenNotPaused {
    STAKE.priceSyncBatch(DATASTORE, poolIds, prices, priceProofs);
  }
}
