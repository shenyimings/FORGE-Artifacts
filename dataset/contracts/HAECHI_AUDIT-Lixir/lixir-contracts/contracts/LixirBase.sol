pragma solidity ^0.7.6;

import 'contracts/libraries/LixirRoles.sol';
import 'contracts/LixirRegistry.sol';


/**
  @notice An abstract contract that gives access to the registry
  and contains common modifiers for restricting access to
  functions based on role. 
 */
abstract contract LixirBase {
  LixirRegistry public immutable registry;

  constructor(address _registry) {
    registry = LixirRegistry(_registry);
  }

  modifier onlyRole(bytes32 role) {
    require(registry.hasRole(role, msg.sender));
    _;
  }
  modifier onlyGovOrDelegate {
    require(registry.isGovOrDelegate(msg.sender));
    _;
  }
  modifier hasRole(bytes32 role, address account) {
    require(registry.hasRole(role, account));
    _;
  }
}
