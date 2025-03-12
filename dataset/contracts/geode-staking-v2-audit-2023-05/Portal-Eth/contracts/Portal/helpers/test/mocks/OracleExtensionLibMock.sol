// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import {StakeModule} from "../../../modules/StakeModule/StakeModule.sol";
import {StakeModuleLib} from "../../../modules/StakeModule/libs/StakeModuleLib.sol";
import {OracleExtensionLib} from "../../../modules/StakeModule/libs/OracleExtensionLib.sol";
import {DataStoreModuleLib} from "../../../modules/DataStoreModule/libs/DataStoreModuleLib.sol";

contract OracleExtensionLibMock is StakeModule {
  using StakeModuleLib for StakeModuleLib.PooledStaking;
  using OracleExtensionLib for StakeModuleLib.PooledStaking;
  using DataStoreModuleLib for DataStoreModuleLib.IsolatedStorage;

  function initialize(address _gETH_position, address _oracle_position) external initializer {
    __StakeModule_init(_gETH_position, _oracle_position);
  }

  function pause() external virtual override {
    _pause();
  }

  function unpause() external virtual override {
    _unpause();
  }

  /**
   * @custom:section                           ** DATA MANIPULATORS **
   */
  function $writeUint(uint256 _id, bytes32 _key, uint256 _data) external {
    DATASTORE.writeUint(_id, _key, _data);
  }

  function $writeBytes(uint256 _id, bytes32 _key, bytes calldata _data) external {
    DATASTORE.writeBytes(_id, _key, _data);
  }

  function $writeAddress(uint256 _id, bytes32 _key, address _data) external {
    DATASTORE.writeAddress(_id, _key, _data);
  }

  function $set_ORACLE_POSITION(address _data) external {
    STAKE.ORACLE_POSITION = _data;
  }

  function $set_VALIDATORS_INDEX(uint256 _data) external {
    STAKE.VALIDATORS_INDEX = _data;
  }

  function $set_VERIFICATION_INDEX(uint256 _data) external {
    STAKE.VERIFICATION_INDEX = _data;
  }

  function $set_MONOPOLY_THRESHOLD(uint256 _data) external {
    STAKE.MONOPOLY_THRESHOLD = _data;
  }

  function $set_ORACLE_UPDATE_TIMESTAMP(uint256 _data) external {
    STAKE.ORACLE_UPDATE_TIMESTAMP = _data;
  }

  function $set_package(uint256 _type, uint256 package) external {
    STAKE.packages[_type] = package;
  }

  function $set_middleware(uint256 _type, uint256 middleware) external {
    STAKE.middlewares[_type][middleware] = true;
  }

  function $set_PricePerShare(uint256 price, uint256 poolId) external {
    STAKE.gETH.setPricePerShare(price, poolId);
  }

  /**
   * @custom:section                           ** INTERNAL **
   */
  function $_alienateValidator(bytes calldata _pk) external {
    return STAKE._alienateValidator(DATASTORE, STAKE.VERIFICATION_INDEX, _pk);
  }

  function $_sanityCheck(uint256 _id, uint256 _newPrice) external {
    return STAKE._sanityCheck(DATASTORE, _id, _newPrice);
  }

  /**
   * @notice fallback functions
   */

  receive() external payable {}
}
