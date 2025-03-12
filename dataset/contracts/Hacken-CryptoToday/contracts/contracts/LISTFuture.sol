//SPDX-License-Identifier: MIT

pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/// @title List futures unlockable after a year
/// @author Noah Jelich
/// @notice The LISTFuture tokens are replacable 1:1 for LIST tokens 1 year after the fair launch
/// @dev The main use of this contract is for the team tokens, which constitute 10% of the tokens
contract LISTFuture is ERC20Capped, Ownable, Pausable {
  struct Balance {
    address account;
    uint256 amount;
  }

  /// @dev the number of team addresses is going to be less than a dozen
  /// @param cap set to 10% of the LIST token cap
  /// @param balances team addresses that will be receiving shares
  constructor(uint256 cap, Balance[] memory balances) ERC20("CryptoToday Futures", "$LISTF") ERC20Capped(cap) {
    for (uint256 i = 0; i < balances.length; i++) {
      _mint(balances[i].account, balances[i].amount);
    }
  }

  /// @notice burn function to be used when converting futures into proper LIST tokens
  function burnFrom(address account, uint256 amount) public virtual {
    uint256 currentAllowance = allowance(account, _msgSender());
    require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
    unchecked {
      _approve(account, _msgSender(), currentAllowance - amount);
    }
    _burn(account, amount);
  }
}
