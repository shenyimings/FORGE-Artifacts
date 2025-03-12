//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract GameFi is ERC20Burnable {

    uint256 public constant INITIAL_SUPPLY = 15 * 10**(6 + 18); // 15M tokens

    constructor(address owner) ERC20("GameFi", "GAFI") {
        _mint(owner, INITIAL_SUPPLY);
    }
}
