pragma solidity ^0.7.6;

library LixirRoles {
  bytes32 constant gov_role = keccak256('v1_gov_role');
  bytes32 constant delegate_role = keccak256('v1_delegate_role');
  bytes32 constant vault_role = keccak256('v1_vault_role');
  bytes32 constant strategist_role = keccak256('v1_strategist_role');
  bytes32 constant pauser_role = keccak256('v1_pauser_role');
  bytes32 constant keeper_role = keccak256('v1_keeper_role');
  bytes32 constant deployer_role = keccak256('v1_deployer_role');
  bytes32 constant strategy_role = keccak256('v1_strategy_role');
  bytes32 constant vault_implementation_role =
    keccak256('v1_vault_implementation_role');
  bytes32 constant eth_vault_implementation_role =
    keccak256('v1_eth_vault_implementation_role');
  bytes32 constant factory_role = keccak256('v1_factory_role');
  bytes32 constant fee_setter_role = keccak256('fee_setter_role');
}

