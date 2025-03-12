// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// globals
import {PERCENTAGE_DENOMINATOR} from "../../../globals/macros.sol";
import {RESERVED_KEY_SPACE as rks} from "../../../globals/reserved_key_space.sol";
import {ID_TYPE} from "../../../globals/id_type.sol";
import {VALIDATOR_STATE} from "../../../globals/validator_state.sol";
// libraries
import {DataStoreModuleLib as DSML} from "../../DataStoreModule/libs/DataStoreModuleLib.sol";
import {StakeModuleLib as SML} from "./StakeModuleLib.sol";
import {DepositContractLib as DCL} from "./DepositContractLib.sol";
// external
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title OEL: Oracle Extension Library
 *
 * @notice An extension to SML
 * @notice Oracle, named Telescope, handles some operations for The Staking Library,
 * * using the logic explained below.
 *
 * @dev review: DataStoreModule for the IsolatedStorage logic.
 * @dev review: StakeModuleLib for base staking logic.
 *
 * @dev Telescope is currently responsible from 4 tasks:
 * * Updating the on-chain price of all pools with a MerkleRoot for minting operations
 * * Updating the on-chain balances info of all pools with a MerkleRoot for withdrawal operations
 * * Confirming validator proposals
 * * Regulating the Node Operators
 *
 * 1. updateVerificationIndex: Confirming validator proposals
 * * 2 step process is essential to prevent the frontrunning with a problematic withdrawalCredential: https://bit.ly/3Tkc6UC
 * * Simply, all proposed validator has an index bound to them,
 * * n representing the latest proposal: (0,n]
 * * Telescope verifies the validator data provided in proposeStake:
 * * especially sig1, sig31 and withdrawal credentials.
 * * Telescope confirms the latest index verified and states the faulty validator proposals (aliens)
 * * If a validator proposal is faulty then it's state is set to 69, refer to globals/validator_state.sol
 *
 * 2. regulateOperators: Regulating the Operators
 * * Operators can act faulty in many different ways. To prevent such actions,
 * * Telescope regulates them with well defined limitations.
 * * Currently only issue is the fee theft, meaning operator have not
 * * used the withdrawal contract for miner fees or MEV boost.
 * * There can be other restrictions in the future.
 *
 * 2. reportBeacon: Continous Data from Beacon chain: Price Merkle Root & Balances Merkle Root & # of active validators
 * * 1. Oracle Nodes calculate the price of its derivative, according to the validator data such as balance and fees.
 * * 2. If a pool doesn't have a validator, price kept same.
 * * 3. A merkle tree is constructed with the order of allIdsByType array.
 * * 4. A watcher collects all the signatures from Multiple Oracle Nodes, and submits the merkle root.
 * * 5. Anyone can update the price of the derivative  by calling priceSync() functions with correct merkle proofs
 * * 6. Minting is allowed within PRICE_EXPIRY (24H) after the last price update.
 * * 7. Updates the regulation around Monopolies and provides BALANCE_MERKLE_ROOT to be used within withdrawal process.
 *
 * @dev External functions have OracleOnly modifier, except priceSync and priceSyncBatch.
 *
 * @dev This is an external library, requires deployment.
 *
 * @author Ice Bear & Crash Bandicoot
 */

library OracleExtensionLib {
  using DSML for DSML.IsolatedStorage;
  using SML for SML.PooledStaking;

  /**
   * @custom:section                           ** CONSTANTS **
   */
  /// @notice effective on MONOPOLY_THRESHOLD, limiting the active validators: Set to 1%
  uint256 public constant MONOPOLY_RATIO = PERCENTAGE_DENOMINATOR / 100;

  /// @notice sensible value for the minimum beacon chain validators. No reasoning.
  uint256 public constant MIN_VALIDATOR_COUNT = 50000;

  /**
   * @custom:section                           ** EVENTS **
   */
  event Alienated(bytes pubkey);
  event VerificationIndexUpdated(uint256 validatorVerificationIndex);
  event FeeTheft(uint256 indexed id, bytes proofs);
  event OracleReported(
    bytes32 priceMerkleRoot,
    bytes32 balanceMerkleRoot,
    uint256 monopolyThreshold
  );

  /**
   * @custom:section                           ** MODIFIERS **
   */
  modifier onlyOracle(SML.PooledStaking storage STAKE) {
    require(msg.sender == STAKE.ORACLE_POSITION, "OEL:sender NOT ORACLE");
    _;
  }

  /**
   * @custom:section                                       ** VERIFICATION INDEX **
   */

  /**
   * @custom:visibility -> internal
   *
   * @notice "Alien" is a validator that is created with a faulty withdrawal
   * credential or signatures, this is a malicious act.
   * @notice Alienation results in imprisonment for the operator of the faulty validator proposal.
   * @dev While alienating a validator we should adjust the 'surplus' and 'secured'
   * balances of the pool accordingly
   * @dev We should adjust the 'proposedValidators' to fix allowances.
   */
  function _alienateValidator(
    SML.PooledStaking storage STAKE,
    DSML.IsolatedStorage storage DATASTORE,
    uint256 verificationIndex,
    bytes calldata _pk
  ) internal {
    require(STAKE.validators[_pk].index <= verificationIndex, "OEL:unexpected index");
    require(
      STAKE.validators[_pk].state == VALIDATOR_STATE.PROPOSED,
      "OEL:NOT all pubkeys are pending"
    );

    uint256 operatorId = STAKE.validators[_pk].operatorId;
    SML._imprison(DATASTORE, operatorId, _pk);

    uint256 poolId = STAKE.validators[_pk].poolId;
    DATASTORE.subUint(poolId, rks.secured, DCL.DEPOSIT_AMOUNT);
    DATASTORE.addUint(poolId, rks.surplus, DCL.DEPOSIT_AMOUNT);

    DATASTORE.subUint(poolId, DSML.getKey(operatorId, rks.proposedValidators), 1);
    DATASTORE.addUint(poolId, DSML.getKey(operatorId, rks.alienValidators), 1);

    STAKE.validators[_pk].state = VALIDATOR_STATE.ALIENATED;

    emit Alienated(_pk);
  }

  /**
   * @custom:visibility -> external
   *
   * @notice Updating VERIFICATION_INDEX, signaling that it is safe to activate
   * the validator proposals with lower index than new VERIFICATION_INDEX
   * @param validatorVerificationIndex (inclusive) index of the highest validator that is verified to be activated
   * @param alienatedPubkeys faulty proposals within the range of new and old verification indexes.
   */
  function updateVerificationIndex(
    SML.PooledStaking storage STAKE,
    DSML.IsolatedStorage storage DATASTORE,
    uint256 validatorVerificationIndex,
    bytes[] calldata alienatedPubkeys
  ) external onlyOracle(STAKE) {
    require(STAKE.VALIDATORS_INDEX >= validatorVerificationIndex, "OEL:high VERIFICATION_INDEX");
    require(validatorVerificationIndex > STAKE.VERIFICATION_INDEX, "OEL:low VERIFICATION_INDEX");

    for (uint256 i = 0; i < alienatedPubkeys.length; ++i) {
      _alienateValidator(STAKE, DATASTORE, validatorVerificationIndex, alienatedPubkeys[i]);
    }

    STAKE.VERIFICATION_INDEX = validatorVerificationIndex;
    emit VerificationIndexUpdated(validatorVerificationIndex);
  }

  /**
   * @dev                                       ** REGULATING OPERATORS **
   *
   * @custom:visibility -> external
   */

  /**
   * @notice regulating operators, currently only regulation is towards fee theft, can add more stuff in the future.
   * @param feeThefts Operator ids who have stolen MEV or block rewards detected
   * @param proofs  BlockNumber, tx or any other referance as a proof
   * @dev Stuff here result in imprisonment
   */
  function regulateOperators(
    SML.PooledStaking storage STAKE,
    DSML.IsolatedStorage storage DATASTORE,
    uint256[] calldata feeThefts,
    bytes[] calldata proofs
  ) external onlyOracle(STAKE) {
    require(feeThefts.length == proofs.length, "OEL:invalid proofs");

    for (uint256 i = 0; i < feeThefts.length; ++i) {
      SML._imprison(DATASTORE, feeThefts[i], proofs[i]);

      emit FeeTheft(feeThefts[i], proofs[i]);
    }
  }

  /**
   * @custom:section                           ** CONTINUOUS UPDATES **
   *
   * @custom:visibility -> external
   */

  /**
   * @notice Telescope reports all of the g-derivate prices with a new PRICE_MERKLE_ROOT.
   * Also reports all of the validator balances with a BALANCE_MERKLE_ROOT.
   * Then, updates the ORACLE_UPDATE_TIMESTAMP and MONOPOLY_THRESHOLD
   *
   * @param allValidatorsCount Number of all validators within BeaconChain, all of them.
   * Prevents monopolies.
   */
  function reportBeacon(
    SML.PooledStaking storage STAKE,
    bytes32 priceMerkleRoot,
    bytes32 balanceMerkleRoot,
    uint256 allValidatorsCount
  ) external onlyOracle(STAKE) {
    require(allValidatorsCount > MIN_VALIDATOR_COUNT, "OEL:low validator count");

    STAKE.PRICE_MERKLE_ROOT = priceMerkleRoot;
    STAKE.BALANCE_MERKLE_ROOT = balanceMerkleRoot;
    STAKE.ORACLE_UPDATE_TIMESTAMP = block.timestamp;

    uint256 newThreshold = (allValidatorsCount * MONOPOLY_RATIO) / PERCENTAGE_DENOMINATOR;
    STAKE.MONOPOLY_THRESHOLD = newThreshold;

    emit OracleReported(priceMerkleRoot, balanceMerkleRoot, newThreshold);
  }

  /**
   * @custom:section                           **  PRICE UPDATE **
   *
   * @dev Permissionless.
   */

  /**
   * @custom:visibility -> view-internal
   *
   * @dev in order to prevent faulty updates to the derivative prices there are boundaries to price updates.
   * 1. Price should not be increased more than DAILY_PRICE_INCREASE_LIMIT
   *  with the factor of how many days since priceUpdateTimestamp has past.
   * 2. Price should not be decreased more than DAILY_PRICE_DECREASE_LIMIT
   *  with the factor of how many days since priceUpdateTimestamp has past.
   *
   * @dev Worth noting, if price drops more than x%, UP TO (slashing percentage/x) days deposits/withdrawals are halted.
   * Example:
   * * A pool can have only one validator, it can get slashed.
   * * Lets say max decrease is 5%, and 50% is slashed.
   * * Then deposits/withdrawals are halted for 10 days.
   * This is not a bug, but a safe circuit-breaker.
   * This logic have effects the withdrawal contract logic.
   */
  function _sanityCheck(
    SML.PooledStaking storage STAKE,
    DSML.IsolatedStorage storage DATASTORE,
    uint256 _id,
    uint256 _newPrice
  ) internal view {
    require(DATASTORE.readUint(_id, rks.TYPE) == ID_TYPE.POOL, "OEL:not a pool?");

    uint256 lastUpdate = STAKE.gETH.priceUpdateTimestamp(_id);
    uint256 dayPercentSinceUpdate = ((block.timestamp - lastUpdate) * PERCENTAGE_DENOMINATOR) /
      1 days;

    uint256 curPrice = STAKE.gETH.pricePerShare(_id);

    uint256 maxPriceIncrease = ((curPrice *
      STAKE.DAILY_PRICE_INCREASE_LIMIT *
      dayPercentSinceUpdate) / PERCENTAGE_DENOMINATOR) / PERCENTAGE_DENOMINATOR;

    uint256 maxPriceDecrease = ((curPrice *
      STAKE.DAILY_PRICE_DECREASE_LIMIT *
      dayPercentSinceUpdate) / PERCENTAGE_DENOMINATOR) / PERCENTAGE_DENOMINATOR;

    require(
      (_newPrice + maxPriceDecrease >= curPrice) && (_newPrice <= curPrice + maxPriceIncrease),
      "OEL:price is insane, price update is halted"
    );
  }

  /**
   * @custom:visibility -> internal
   *
   * @notice syncing the price of g-derivatives after checking the merkle proofs and the sanity of the price.
   * @param _price price of the derivative denominated in gETH.denominator()
   * @param _priceProof merkle proofs
   */
  function _priceSync(
    SML.PooledStaking storage STAKE,
    DSML.IsolatedStorage storage DATASTORE,
    uint256 _poolId,
    uint256 _price,
    bytes32[] calldata _priceProof
  ) internal {
    require(
      STAKE.ORACLE_UPDATE_TIMESTAMP > STAKE.gETH.priceUpdateTimestamp(_poolId),
      "OEL:no price change"
    );

    bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_poolId, _price))));
    require(
      MerkleProof.verify(_priceProof, STAKE.PRICE_MERKLE_ROOT, leaf),
      "OEL:NOT all proofs are valid"
    );

    _sanityCheck(STAKE, DATASTORE, _poolId, _price);

    STAKE.gETH.setPricePerShare(_price, _poolId);
  }

  /**
   * @custom:visibility -> external
   *
   * @notice external function to set a derivative price on Portal
   * @param price price of the derivative denominated in gETH.denominator()
   * @param priceProof merkle proofs
   */
  function priceSync(
    SML.PooledStaking storage STAKE,
    DSML.IsolatedStorage storage DATASTORE,
    uint256 poolId,
    uint256 price,
    bytes32[] calldata priceProof
  ) external {
    _priceSync(STAKE, DATASTORE, poolId, price, priceProof);
  }

  /**
   * @custom:visibility -> external
   *
   * @notice external function to set a multiple derivatives price at once, saves gas.
   * @param prices price of the derivative denominated in gETH.denominator()
   * @param priceProofs merkle proofs
   */
  function priceSyncBatch(
    SML.PooledStaking storage STAKE,
    DSML.IsolatedStorage storage DATASTORE,
    uint256[] calldata poolIds,
    uint256[] calldata prices,
    bytes32[][] calldata priceProofs
  ) external {
    require(poolIds.length == prices.length);
    require(poolIds.length == priceProofs.length);

    for (uint256 i = 0; i < poolIds.length; ++i) {
      _priceSync(STAKE, DATASTORE, poolIds[i], prices[i], priceProofs[i]);
    }
  }
}
