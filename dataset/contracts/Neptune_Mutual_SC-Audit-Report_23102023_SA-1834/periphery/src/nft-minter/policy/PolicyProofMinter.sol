// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../../util/interfaces/IAccessControlUtil.sol";
import "../../util/TokenRecovery.sol";
import "./interfaces/IPolicyProofMinter.sol";
import "./ProofOfPolicy.sol";
import "./PolicyProofMinterState.sol";

contract PolicyProofMinter is IThrowable, IPolicyProofMinter, IAccessControlUtil, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, TokenRecovery, ProofOfPolicy, PolicyProofMinterState {
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(IStore store, INeptuneLegends nft, uint256 min, uint256 max, address admin) external initializer {
    if (address(store) == address(0)) {
      revert InvalidArgumentError("store");
    }

    if (address(nft) == address(0)) {
      revert InvalidArgumentError("nft");
    }

    if (min > max) {
      revert InvalidArgumentError("min");
    }

    if (address(admin) == address(0)) {
      revert InvalidArgumentError("admin");
    }

    __AccessControl_init();
    __Pausable_init();
    __ReentrancyGuard_init();

    _setRoleAdmin(NS_ROLES_PAUSER, DEFAULT_ADMIN_ROLE);
    _setRoleAdmin(NS_ROLES_RECOVERY_AGENT, DEFAULT_ADMIN_ROLE);

    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _grantRole(NS_ROLES_RECOVERY_AGENT, admin);

    _s = store;
    _nft = nft;
    _min = min;
    _max = max;

    emit BoundarySet(_msgSender(), 0, min, 0, max);
  }

  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                             Danger: Publicly Accessible. No RBAC.
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  function mint(ICxToken proofOfPolicy, uint256 tokenId) external whenNotPaused nonReentrant {
    _throwIfInvalidProof(_s, proofOfPolicy, _msgSender());

    if (tokenId < _min || tokenId > _max) {
      revert TokenIdOutOfBoundsError(_min, _max);
    }

    if (_nft._soulbound(tokenId)) {
      revert TokenAlreadySoulbound(tokenId);
    }

    // Check if the given token id was already minted elsewhere
    if (_nft._minted(tokenId)) {
      revert TokenAlreadyMintedError(tokenId);
    }

    // Check if the given token id was already minted here
    if (_souls[tokenId] != address(0)) {
      revert TokenAlreadySoulbound(tokenId);
    }


    _souls[tokenId] = _msgSender();

    _nft.mint(_getMintInfo(tokenId, _msgSender()));

    emit SoulboundMinted(_msgSender(), tokenId);
  }

  function setBoundary(uint256 boundary) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (boundary < _max) {
      revert InvalidBoundaryError(_max, boundary);
    }

    emit BoundarySet(_msgSender(), _min, _min, _max, boundary);

    _max = boundary;
  }

  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                                         Access Control
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  function grantRoles(AccountWithRoles[] calldata detail) external override whenNotPaused {
    if (detail.length == 0) {
      revert InvalidArgumentError("detail");
    }

    for (uint256 i = 0; i < detail.length; i++) {
      for (uint256 j = 0; j < detail[i].roles.length; j++) {
        grantRole(detail[i].roles[j], detail[i].account);
      }
    }
  }

  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                                          Recoverable
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  function recoverEther(address sendTo) external onlyRole(NS_ROLES_RECOVERY_AGENT) {
    _recoverEther(sendTo);
  }

  function recoverToken(IERC20Upgradeable malicious, address sendTo) external onlyRole(NS_ROLES_RECOVERY_AGENT) {
    _recoverToken(malicious, sendTo);
  }

  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                                            Pausable
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  function pause() external onlyRole(NS_ROLES_PAUSER) {
    _pause();
  }

  function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    _unpause();
  }

  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                                             Views
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  function validateProof(ICxToken proofOfPolicy) external view returns (bool) {
    _throwIfInvalidProof(_s, proofOfPolicy, _msgSender());

    return true;
  }

  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                                       Private Functions
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  function _getMintInfo(uint256 tokenId, address account) private pure returns (INeptuneLegends.MintInfo memory) {
    INeptuneLegends.MintInfo memory info;

    info.sendTo = account;
    info.id = tokenId;
    info.soulbound = true;

    return info;
  }
}
