// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/Context.sol";
import "./ERC20Pausable.sol";


abstract contract ERC20Lockable is Context, ERC20Pausable {
    
    struct LockInfo {
        uint256 lockedAmount;
        uint256 unlockTimestamp;
    }

    mapping(address => LockInfo) internal _locks;

  function lock(address lockFor, uint256 lockAmount, uint256 unlockTimestamp) external {
    require(
      _msgSender() == _owner,
      "ERC20Lockable: only owner can lock tokens"
    );

    _locks[lockFor].lockedAmount = lockAmount;
    _locks[lockFor].unlockTimestamp = unlockTimestamp;
  }

  function retrieveLockInfo(address account) public view returns (uint256 lockedAmount, uint256 unlockTimestamp){
    return (_locks[account].lockedAmount, _locks[account].unlockTimestamp);
  }

 /**
   * @dev Hook that restricts transfers according to the 'lock-in' period.
   *
   * See {ERC20-_beforeTokenTransfer}.
   *
   * Requirements:
   *
   * - transferred amount should not include tokens that are 'locked-in'.
   */
  function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
    super._beforeTokenTransfer(from, to, amount);

    uint256 lockedAmount;
    uint256 unlockTimestamp;
    (lockedAmount, unlockTimestamp) = retrieveLockInfo(from);
    if (unlockTimestamp != 0 && block.timestamp < unlockTimestamp) {
      require(amount <= balanceOf(from) - lockedAmount,"ERC20Lockable: transfer amount exceeds the non-locked balance");
    }
    }
}