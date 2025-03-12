// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Time} from "lib/openzeppelin-contracts/contracts/utils/types/Time.sol";
import {Nonces} from "lib/openzeppelin-contracts/contracts/utils/Nonces.sol";

contract MockERC20VotesChangingClock is ERC20, ERC20Permit, ERC20Votes {
  bool public useBlockNumber;

  constructor() ERC20("MyToken", "MTK") ERC20Permit("MyToken") {}

  function mint(address to, uint256 amount) public {
    _mint(to, amount);
  }

  function CLOCK_MODE() public view override returns (string memory) {
    if (useBlockNumber) return "mode=blocknumber";
    if (clock() != Time.timestamp()) revert ERC6372InconsistentClock();
    return "mode=timestamp";
  }

  function clock() public view override returns (uint48) {
    return useBlockNumber ? Time.blockNumber() : Time.timestamp();
  }

  function setUseBlockNumber(bool _useBlockNumber) public {
    useBlockNumber = _useBlockNumber;
  }

  // The following functions are overrides required by Solidity.

  function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
    super._update(from, to, value);
    delegate(to);
  }

  function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
    return super.nonces(owner);
  }
}
