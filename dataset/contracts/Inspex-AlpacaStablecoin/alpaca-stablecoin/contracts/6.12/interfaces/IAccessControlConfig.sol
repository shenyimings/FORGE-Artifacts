// SPDX-License-Identifier: AGPL-3.0-or-later
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/

pragma solidity 0.6.12;

interface IAccessControlConfig {
  function hasRole(bytes32 role, address account) external view returns (bool);

  function OWNER_ROLE() external view returns (bytes32);

  function GOV_ROLE() external view returns (bytes32);

  function PRICE_ORACLE_ROLE() external view returns (bytes32);

  function ADAPTER_ROLE() external view returns (bytes32);

  function LIQUIDATION_ENGINE_ROLE() external view returns (bytes32);

  function STABILITY_FEE_COLLECTOR_ROLE() external view returns (bytes32);

  function SHOW_STOPPER_ROLE() external view returns (bytes32);

  function POSITION_MANAGER_ROLE() external view returns (bytes32);

  function MINTABLE_ROLE() external view returns (bytes32);

  function BOOK_KEEPER_ROLE() external view returns (bytes32);
}
