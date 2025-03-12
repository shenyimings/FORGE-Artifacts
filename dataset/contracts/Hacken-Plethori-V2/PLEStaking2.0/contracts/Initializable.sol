// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/utils/Context.sol";

abstract contract Initializable is Context {

    event Initialized(address account);

    bool private _initialized;

    constructor() {
        _initialized = false;
    }

    function initialized() public view virtual returns (bool) {
        return _initialized;
    }

    modifier notInitialized() {
        require(!initialized(), "Initializable: Already initialized");
        _;
    }

    modifier onlyInitialized() {
        require(initialized(), "Initializable: Not initialized");
        _;
    }

    function _init() internal virtual notInitialized {
        _initialized = true;
        emit Initialized(_msgSender());
    }
}