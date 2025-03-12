// SPDX-License-Identifier: MIT
// TODO This interface was generated from `cast interface`, so some types are not as strong as they
// could be.
pragma solidity ^0.8.23;

import {RoleDescription} from "../lib/UDVTs.sol";

/// @title LlamaPolicy Interface
/// @author Llama (devsdosomething@llama.xyz)
/// @notice This is the interface for LlamaPolicy.
interface ILlamaPolicy {
  event Approval(address indexed owner, address indexed spender, uint256 indexed id);
  event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
  event ExpiredRoleRevoked(address indexed caller, address indexed policyholder, uint8 indexed role);
  event Initialized(uint8 version);
  event PolicyMetadataSet(address policyMetadata, address indexed policyMetadataLogic, bytes initializationData);
  event RoleAssigned(address indexed policyholder, uint8 indexed role, uint64 expiration, uint96 quantity);
  event RoleInitialized(uint8 indexed role, bytes32 description);
  event RolePermissionAssigned(
    uint8 indexed role, bytes32 indexed permissionId, PermissionData permissionData, bool hasPermission
  );
  event Transfer(address indexed from, address indexed to, uint256 indexed id);

  struct LlamaPolicyConfig {
    RoleDescription[] roleDescriptions;
    RoleHolderData[] roleHolders;
    RolePermissionData[] rolePermissions;
    string color;
    string logo;
  }

  struct PermissionData {
    address target;
    bytes4 selector;
    address strategy;
  }

  struct Checkpoint {
    uint64 timestamp;
    uint64 expiration;
    uint96 quantity;
  }

  struct History {
    Checkpoint[] _checkpoints;
  }

  struct RoleHolderData {
    uint8 role;
    address policyholder;
    uint96 quantity;
    uint64 expiration;
  }

  struct RolePermissionData {
    uint8 role;
    PermissionData permissionData;
    bool hasPermission;
  }

  function approve(address, uint256) external pure;
  function balanceOf(address owner) external view returns (uint256);
  function canCreateAction(uint8 role, bytes32 permissionId) external view returns (bool hasPermission);
  function contractURI() external view returns (string memory);
  function getApproved(uint256) external view returns (address);
  function getPastQuantity(address policyholder, uint8 role, uint256 timestamp) external view returns (uint96);
  function getPastRoleSupplyAsNumberOfHolders(uint8 role, uint256 timestamp)
    external
    view
    returns (uint96 numberOfHolders);
  function getPastRoleSupplyAsQuantitySum(uint8 role, uint256 timestamp) external view returns (uint96 totalQuantity);
  function getQuantity(address policyholder, uint8 role) external view returns (uint96);
  function getRoleSupplyAsNumberOfHolders(uint8 role) external view returns (uint96 numberOfHolders);
  function getRoleSupplyAsQuantitySum(uint8 role) external view returns (uint96 totalQuantity);
  function hasPermissionId(address policyholder, uint8 role, bytes32 permissionId) external view returns (bool);
  function hasRole(address policyholder, uint8 role) external view returns (bool);
  function hasRole(address policyholder, uint8 role, uint256 timestamp) external view returns (bool);
  function initialize(
    string memory _name,
    LlamaPolicyConfig memory config,
    address policyMetadataLogic,
    address executor,
    PermissionData memory bootstrapPermissionData
  ) external;
  function initializeRole(RoleDescription description) external;
  function isApprovedForAll(address, address) external view returns (bool);
  function isRoleExpired(address policyholder, uint8 role) external view returns (bool);
  function llamaExecutor() external view returns (address);
  function llamaPolicyMetadata() external view returns (address);
  function name() external view returns (string memory);
  function numRoles() external view returns (uint8);
  function ownerOf(uint256 id) external view returns (address owner);
  function revokeExpiredRole(uint8 role, address policyholder) external;
  function revokePolicy(address policyholder) external;
  function roleBalanceCheckpoints(address policyholder, uint8 role, uint256 start, uint256 end)
    external
    view
    returns (History memory);
  function roleBalanceCheckpoints(address policyholder, uint8 role) external view returns (History memory);
  function roleBalanceCheckpointsLength(address policyholder, uint8 role) external view returns (uint256);
  function roleExpiration(address policyholder, uint8 role) external view returns (uint64);
  function roleSupplyCheckpoints(uint8 role, uint256 start, uint256 end) external view returns (History memory);
  function roleSupplyCheckpoints(uint8 role) external view returns (History memory);
  function roleSupplyCheckpointsLength(uint8 role) external view returns (uint256);
  function safeTransferFrom(address, address, uint256) external pure;
  function safeTransferFrom(address, address, uint256, bytes memory) external pure;
  function setAndInitializePolicyMetadata(address llamaPolicyMetadataLogic, bytes memory config) external;
  function setApprovalForAll(address, bool) external pure;
  function setRoleHolder(uint8 role, address policyholder, uint96 quantity, uint64 expiration) external;
  function setRolePermission(uint8 role, PermissionData memory permissionData, bool hasPermission) external;
  function supportsInterface(bytes4 interfaceId) external view returns (bool);
  function symbol() external view returns (string memory);
  function tokenURI(uint256 tokenId) external view returns (string memory);
  function totalSupply() external view returns (uint256);
  function transferFrom(address, address, uint256) external pure;
  function updateRoleDescription(uint8 role, RoleDescription description) external;
}
