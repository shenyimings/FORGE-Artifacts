// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";

interface INFTUpgradeable is IERC721Upgradeable, IERC721MetadataUpgradeable {
    event Minted(address toAddress, uint256 tokenId, string pkg);
    
    struct NFTUpgradeableConfig {
        string baseURI;
        address creator;
    }
    
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function grantRole(bytes32 role, address account) external;
    function setPaused(bool paused_) external;
    function paused() external view returns (bool);
    function burn(uint256 tokenId) external;
    function setConfig(NFTUpgradeableConfig memory config_) external;
    function tokenCount() external view returns (uint256);
    function creator() external view returns (address);
}