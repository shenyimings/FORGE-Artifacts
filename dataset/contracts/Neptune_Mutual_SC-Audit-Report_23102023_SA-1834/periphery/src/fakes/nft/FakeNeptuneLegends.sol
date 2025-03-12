// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../../util/WithPausability.sol";
import "../../util/TokenRecovery.sol";
import "./FakeNeptuneLegendsState.sol";

contract FakeNeptuneLegends is AccessControlUpgradeable, ERC721BurnableUpgradeable, ERC2981Upgradeable, WithPausability, TokenRecovery, FakeNeptuneLegendsState {
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(string calldata tokenUri, address admin, address minter) external initializer {
    __AccessControl_init();
    __ERC721_init("Neptune Legends", "NLG");
    __ERC2981_init();
    __Pausable_init();

    _uri = tokenUri;

    _setRoleAdmin(NS_ROLES_MINTER, DEFAULT_ADMIN_ROLE);
    _setRoleAdmin(NS_ROLES_PAUSER, DEFAULT_ADMIN_ROLE);
    _setRoleAdmin(NS_ROLES_ROYALTY_ADMIN, DEFAULT_ADMIN_ROLE);
    _setRoleAdmin(NS_ROLES_RECOVERY_AGENT, DEFAULT_ADMIN_ROLE);

    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _grantRole(NS_ROLES_RECOVERY_AGENT, admin);
    _grantRole(NS_ROLES_MINTER, minter);
  }

  function _baseURI() internal view override returns (string memory) {
    return _uri;
  }

  function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize) internal override whenNotPaused {
    // Only enter if this isn't a mint operation
    if (from != address(0)) {
      if (_soulbound[tokenId]) {
        revert SoulboundError(tokenId);
      }
    }

    super._beforeTokenTransfer(from, to, tokenId, batchSize);
  }

  function mint(MintInfo calldata info) external override {
    //_throwIfSenderIsNot(NS_ROLES_MINTER);

    if (_minted[info.id]) {
      revert AlreadyMintedError(info.id);
    }

    _soulbound[info.id] = info.soulbound;
    _minted[info.id] = true;

    if (info.soulbound) {
      emit SoulBound(info.id);
    }

    _safeMint(info.sendTo, info.id, "");
  }

  function mintMany(MintInfo[] calldata info) external override {
    //_throwIfSenderIsNot(NS_ROLES_MINTER);

    for (uint256 i = 0; i < info.length; i++) {
      _soulbound[info[i].id] = info[i].soulbound;

      if (info[i].soulbound) {
        emit SoulBound(info[i].id);
      }

      if (_minted[info[i].id]) {
        revert AlreadyMintedError(info[i].id);
      }

      _minted[info[i].id] = true;
      _safeMint(info[i].sendTo, info[i].id, "");
    }
  }

  function setBaseUri(string calldata baseUri) external {
    //_throwIfSenderIsNot(DEFAULT_ADMIN_ROLE);

    if (bytes(baseUri).length == 0) {
      revert InvalidArgumentError("baseUri");
    }

    emit BaseUriSet(_baseURI(), baseUri);
    _uri = baseUri;
  }

  function setDefaultRoyalty(address receiver, uint96 feeNumerator) external {
    //_throwIfSenderIsNot(NS_ROLES_ROYALTY_ADMIN);

    _setDefaultRoyalty(receiver, feeNumerator);
    emit DefaultRoyaltySet(_msgSender(), receiver, feeNumerator);
  }

  function deleteDefaultRoyalty() external {
    //_throwIfSenderIsNot(NS_ROLES_ROYALTY_ADMIN);

    _deleteDefaultRoyalty();
    emit DefaultRoyaltyDeleted(_msgSender());
  }

  function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external {
    //_throwIfSenderIsNot(NS_ROLES_ROYALTY_ADMIN);

    _setTokenRoyalty(tokenId, receiver, feeNumerator);
    emit TokenRoyaltySet(_msgSender(), tokenId, receiver, feeNumerator);
  }

  function resetTokenRoyalty(uint256 tokenId) external {
    //_throwIfSenderIsNot(NS_ROLES_ROYALTY_ADMIN);

    _resetTokenRoyalty(tokenId);
    emit TokenRoyaltyReset(_msgSender(), tokenId);
  }

  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                                          Recoverable
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  function recoverEther(address sendTo) external {
    //_throwIfSenderIsNot(NS_ROLES_RECOVERY_AGENT);

    _recoverEther(sendTo);
  }

  function recoverToken(IERC20Upgradeable malicious, address sendTo) external {
    //_throwIfSenderIsNot(NS_ROLES_RECOVERY_AGENT);

    _recoverToken(malicious, sendTo);
  }

  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                                            Pausable
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  function setPausers(address[] calldata accounts, bool[] calldata statuses) external {
    //_throwIfSenderIsNot(DEFAULT_ADMIN_ROLE);

    _setPausers(_pausers, accounts, statuses);
  }

  function pause() external {
    //_throwIfSenderIsNot(NS_ROLES_PAUSER);

    _pause();
  }

  function unpause() external {
    //_throwIfSenderIsNot(DEFAULT_ADMIN_ROLE);

    _unpause();
  }

  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                                             Views
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  function feeDenominator() external pure returns (uint96) {
    return _feeDenominator();
  }

  function supportsInterface(bytes4 interfaceId) public pure virtual override(AccessControlUpgradeable, ERC721Upgradeable, ERC2981Upgradeable) returns (bool) {
    if (type(IAccessControlUpgradeable).interfaceId == interfaceId) {
      return true;
    }

    if (type(IERC721Upgradeable).interfaceId == interfaceId) {
      return true;
    }

    if (type(ERC2981Upgradeable).interfaceId == interfaceId) {
      return true;
    }

    if (type(IERC721MetadataUpgradeable).interfaceId == interfaceId) {
      return true;
    }

    return false;
  }
}
