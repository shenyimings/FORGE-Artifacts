// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IPauseable.sol";
import "../misc/Context.sol";

abstract contract Pausable is IPauseable, Context {

  bool private _paused;

  constructor() {
    _paused = false;
  }

  function paused() public view override virtual returns (bool) {
    return _paused;
  }

  modifier whenNotPaused() {
    require(!paused(), "P");
    _;
  }

  modifier whenPaused() {
    require(paused(), "NP");
    _;
  }

  function _pause() internal virtual whenNotPaused {
    _paused = true;
    emit Paused(_msgSender());
  }

  function _unpause() internal virtual whenPaused {
    _paused = false;
    emit Unpaused(_msgSender());
  }
}