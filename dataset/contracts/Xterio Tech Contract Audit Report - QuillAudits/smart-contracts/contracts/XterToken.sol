// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract XterToken is ERC20 {
    constructor(address wallet) ERC20("Xterio", "XTER") {
        _mint(wallet, 1_000_000_000 * 10**18);
    }
}
