// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../../util/TokenRecovery.sol";
import "../../util/WithPausability.sol";
import "../../util/WhitelistedTransfer.sol";
import "./FakeVoteEscrowBoosterV2.sol";
import "../../escrow/interfaces/IVoteEscrowToken.sol";

contract FakeVoteEscrowTokenV2 is IVoteEscrowToken, ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, WithPausability, WhitelistedTransfer, TokenRecovery, FakeVoteEscrowBoosterV2 {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(address contractOwner, address underlyingToken, address feeToAccount, string memory tokenName, string memory tokenSymbol) external initializer {
    _underlyingToken = underlyingToken;
    _feeTo = feeToAccount;
    _whitelist[address(this)] = true;

    __ERC20_init(tokenName, tokenSymbol);
    __Ownable_init();
    __Pausable_init();
    __ReentrancyGuard_init();

    transferOwnership(contractOwner);
  }

  function upgradeToV2(address treasury) external onlyOwner {
    if (_lastInitializedOn > 0) {
      revert AlreadyInitializedError();
    }

    _treasury = treasury;
    _lastInitializedOn = block.timestamp;
    _members[_msgSender()] = true;
    _boosts[_msgSender()] = 10;
    _name = "Fake";
  }

  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                                         Lock & Unlock
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  function _unlockWithPenalty(uint256 penalty) internal {
    uint256 amount = _unlock(_msgSender(), penalty);

    // Pull and burn veToken
    _transfer(_msgSender(), address(this), amount);
    _burn(address(this), amount);

    // Transfer underlying token
    IERC20Upgradeable(_underlyingToken).safeTransfer(_msgSender(), amount - penalty);

    if (penalty > 0) {
      IERC20Upgradeable(_underlyingToken).safeTransfer(_feeTo, penalty);
    }
  }

  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                             Danger!!! External & Public Functions
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  function unlock() external override nonReentrant {
    if (block.timestamp < _unlockAt[_msgSender()]) {
      revert VoteEscrowUnlockError(_unlockAt[_msgSender()]);
    }

    _unlockWithPenalty(0);
  }

  function unlockPrematurely() external override nonReentrant {
    if (block.timestamp > _unlockAt[_msgSender()]) {
      revert VoteEscrowAlreadyUnlockedError();
    }

    if (block.number < _minUnlockHeights[_msgSender()]) {
      revert VoteEscrowUnlockOffsetError(_minUnlockHeights[_msgSender()]);
    }

    uint256 penalty = (_balances[_msgSender()] * 2500) / 10_000;
    _unlockWithPenalty(penalty);
  }

  function lock(uint256 amount, uint256 durationInWeeks) external override nonReentrant {
    _lock(_msgSender(), amount, durationInWeeks);

    // Zero value locks signify lock extension
    if (amount > 0) {
      IERC20Upgradeable(_underlyingToken).safeTransferFrom(_msgSender(), address(this), amount);
      _mint(_msgSender(), amount);
    }
  }

  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                                      Transfer Restriction
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  function updateWhitelist(address[] calldata accounts, bool[] memory statuses) external onlyOwner {
    _updateTransferWhitelist(_whitelist, accounts, statuses);
  }

  function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override whenNotPaused {
    _throwIfNonWhitelistedTransfer(_whitelist, from, to, amount);
  }

  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                                          Recoverable
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  function recoverEther(address sendTo) external onlyOwner {
    _recoverEther(sendTo);
  }

  function recoverToken(IERC20Upgradeable malicious, address sendTo) external onlyOwner {
    _recoverToken(malicious, sendTo);
  }

  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                                            Pausable
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  function setPausers(address[] calldata accounts, bool[] calldata statuses) external onlyOwner {
    _setPausers(_pausers, accounts, statuses);
  }

  function pause() external {
    if (_pausers[_msgSender()] == false) {
      revert AccessDeniedError("Pauser");
    }

    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                                             Boost
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  function calculateBoost(uint256 duration) external pure override returns (uint256) {
    return _calculateBoost(duration);
  }

  function getVotingPower(address account) external view override returns (uint256) {
    return _getVotingPower(_balances[account], _unlockAt[account], block.timestamp);
  }
}
