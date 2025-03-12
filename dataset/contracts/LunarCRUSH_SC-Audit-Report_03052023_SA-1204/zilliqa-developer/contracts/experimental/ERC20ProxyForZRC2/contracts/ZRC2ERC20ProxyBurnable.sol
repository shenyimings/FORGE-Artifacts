// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ScillaConnector} from "./ScillaConnector.sol";
import {ZRC2ERC20Proxy} from "./ZRC2ERC20Proxy.sol";

contract ZRC2ERC20ProxyBurnable is ZRC2ERC20Proxy {
  using ScillaConnector for address;
  using SafeCast for uint256;

  /** Just chains down to the base constructor */
  constructor(address zrc2_address) ZRC2ERC20Proxy(zrc2_address) { }

  /**
   * @dev Destroys a `value` amount of tokens from the caller.
   *
   * See {ERC20-_burn}.
   */
  function burn(uint256 value) public virtual {
    uint128 value128 = value.toUint128();
    zrc2_proxy.call("Burn", value128);
  }

  /**
   * @dev Destroys a `value` amount of tokens from `account`, deducting from
   * the caller's allowance.
   *
   * See {ERC20-_burn} and {ERC20-allowance}.
   *
   * Requirements:
   *
   * - the caller must have allowance for ``accounts``'s tokens of at least
   * `value`.
   */
  function burnFrom(address account, uint256 value) public virtual {
    address self = address(msg.sender);

    _transferFrom(account, self, value);
    burn(value);
  }
}
