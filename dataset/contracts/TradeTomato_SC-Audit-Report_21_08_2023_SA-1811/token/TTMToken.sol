// SPDX-License-Identifier: MIT

//** Tradetomato Token */
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract TTMToken is ERC20Burnable {
    constructor() ERC20("Tradetomato Token", "TTM") {
        _mint(msg.sender, 1_000_000_000 * 10 ** decimals());
    }
}
