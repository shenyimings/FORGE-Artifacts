pragma solidity ^0.7.6;

import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import '@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol';

/**
  @notice an access control contract with roles used to handle
  permissioning throughout the `Vault` and `Strategy` contracts.
 */
contract LixirRegistry is AccessControl {
  address public immutable uniV3Factory;
  IWETH9 public immutable weth9;

  /// king
  bytes32 public constant gov_role = keccak256('v1_gov_role');
  /// same privileges as `gov_role`
  bytes32 public constant delegate_role = keccak256('v1_delegate_role');
  /// configuring options within the strategy contract & vault
  bytes32 public constant strategist_role = keccak256('v1_strategist_role');
  /// can `emergencyExit` a vault
  bytes32 public constant pauser_role = keccak256('v1_pauser_role');
  /// can `rebalance` the vault via the strategy contract
  bytes32 public constant keeper_role = keccak256('v1_keeper_role');
  /// can `createVault`s from the factory contract
  bytes32 public constant deployer_role = keccak256('v1_deployer_role');
  /// verified vault in the registry
  bytes32 public constant vault_role = keccak256('v1_vault_role');
  /// can initialize vaults
  bytes32 public constant strategy_role = keccak256('v1_strategy_role');
  bytes32 public constant vault_implementation_role =
    keccak256('v1_vault_implementation_role');
  bytes32 public constant eth_vault_implementation_role =
    keccak256('v1_eth_vault_implementation_role');
  /// verified vault factory in the registry
  bytes32 public constant factory_role = keccak256('v1_factory_role');
  /// can `setPerformanceFee` on a vault
  bytes32 public constant fee_setter_role = keccak256('fee_setter_role');

  address public feeTo;

  address public emergencyReturn;

  uint24 public constant PERFORMANCE_FEE_PRECISION = 1e6;

  event FeeToChanged(address indexed previousFeeTo, address indexed newFeeTo);

  event EmergencyReturnChanged(
    address indexed previousEmergencyReturn,
    address indexed newEmergencyReturn
  );

  constructor(
    address _governance,
    address _delegate,
    address _uniV3Factory,
    address _weth9
  ) {
    uniV3Factory = _uniV3Factory;
    weth9 = IWETH9(_weth9);
    _setupRole(gov_role, _governance);
    _setupRole(delegate_role, _delegate);
    // gov is its own admin
    _setRoleAdmin(gov_role, gov_role);
    _setRoleAdmin(delegate_role, gov_role);
    _setRoleAdmin(strategist_role, delegate_role);
    _setRoleAdmin(fee_setter_role, delegate_role);
    _setRoleAdmin(pauser_role, delegate_role);
    _setRoleAdmin(keeper_role, delegate_role);
    _setRoleAdmin(deployer_role, delegate_role);
    _setRoleAdmin(factory_role, delegate_role);
    _setRoleAdmin(strategy_role, delegate_role);
    _setRoleAdmin(vault_implementation_role, delegate_role);
    _setRoleAdmin(eth_vault_implementation_role, delegate_role);
    _setRoleAdmin(vault_role, factory_role);
  }

  function addRole(bytes32 role, bytes32 roleAdmin) public {
    require(isGovOrDelegate(msg.sender));
    require(getRoleAdmin(role) == bytes32(0) && getRoleMemberCount(role) == 0);
    _setRoleAdmin(role, roleAdmin);
  }

  function isGovOrDelegate(address account) public view returns (bool) {
    return hasRole(gov_role, account) || hasRole(delegate_role, account);
  }

  function setFeeTo(address _feeTo) external {
    require(isGovOrDelegate(msg.sender));
    address previous = feeTo;
    feeTo = _feeTo;
    emit FeeToChanged(previous, _feeTo);
  }

  function setEmergencyReturn(address _emergencyReturn) external {
    require(isGovOrDelegate(msg.sender));
    address previous = emergencyReturn;
    emergencyReturn = _emergencyReturn;
    emit EmergencyReturnChanged(previous, _emergencyReturn);
  }
}
