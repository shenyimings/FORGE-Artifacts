// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import {IDataStoreModule} from "./IDataStoreModule.sol";
import {StakeModuleLib as SML} from "../../modules/StakeModule/libs/StakeModuleLib.sol";

interface IStakeModule is IDataStoreModule {
  function pause() external;

  function unpause() external;

  function StakeParams()
    external
    view
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
    );

  function getValidator(bytes calldata pubkey) external view returns (SML.Validator memory);

  function getPackageVersion(uint256 _type) external view returns (uint256);

  function isMiddleware(uint256 _type, uint256 _version) external view returns (bool);

  function initiateOperator(
    uint256 id,
    uint256 fee,
    uint256 validatorPeriod,
    address maintainer
  ) external payable;

  function deployLiquidityPool(uint256 poolId) external;

  function initiatePool(
    uint256 fee,
    uint256 middlewareVersion,
    address maintainer,
    bytes calldata NAME,
    bytes calldata middleware_data,
    bool[3] calldata config
  ) external payable returns (uint256 poolId);

  function setPoolVisibility(uint256 poolId, bool makePrivate) external;

  function setWhitelist(uint256 poolId, address whitelist) external;

  function changeMaintainer(uint256 poolId, address newMaintainer) external;

  function getMaintenanceFee(uint256 id) external view returns (uint256);

  function switchMaintenanceFee(uint256 id, uint256 newFee) external;

  function increaseWalletBalance(uint256 id) external payable returns (bool);

  function decreaseWalletBalance(uint256 id, uint256 value) external returns (bool);

  function isPrisoned(uint256 operatorId) external view returns (bool);

  function blameOperator(bytes calldata pk) external;

  function getValidatorPeriod(uint256 id) external view returns (uint256);

  function switchValidatorPeriod(uint256 operatorId, uint256 newPeriod) external;

  function operatorAllowance(uint256 poolId, uint256 operatorId) external view returns (uint256);

  function delegate(
    uint256 poolId,
    uint256[] calldata operatorIds,
    uint256[] calldata allowances,
    uint256 fallbackOperator
  ) external;

  function isWhitelisted(uint256 poolId, address staker) external view returns (bool);

  function isPrivatePool(uint256 poolId) external view returns (bool);

  function isPriceValid(uint256 poolId) external view returns (bool);

  function isMintingAllowed(uint256 poolId) external view returns (bool);

  function deposit(
    uint256 poolId,
    uint256 price,
    bytes32[] calldata priceProof,
    uint256 mingETH,
    uint256 deadline,
    address receiver
  ) external payable returns (uint256 boughtgETH, uint256 mintedgETH);

  function canStake(bytes calldata pubkey) external view returns (bool);

  function proposeStake(
    uint256 poolId,
    uint256 operatorId,
    bytes[] calldata pubkeys,
    bytes[] calldata signatures1,
    bytes[] calldata signatures31
  ) external;

  function stake(uint256 operatorId, bytes[] calldata pubkeys) external;

  function updateVerificationIndex(
    uint256 validatorVerificationIndex,
    bytes[] calldata alienatedPubkeys
  ) external;

  function regulateOperators(uint256[] calldata feeThefts, bytes[] calldata proofs) external;

  function reportBeacon(
    bytes32 priceMerkleRoot,
    bytes32 balanceMerkleRoot,
    uint256 allValidatorsCount
  ) external;

  function priceSync(uint256 poolId, uint256 price, bytes32[] calldata priceProof) external;

  function priceSyncBatch(
    uint256[] calldata poolIds,
    uint256[] calldata prices,
    bytes32[][] calldata priceProofs
  ) external;
}
