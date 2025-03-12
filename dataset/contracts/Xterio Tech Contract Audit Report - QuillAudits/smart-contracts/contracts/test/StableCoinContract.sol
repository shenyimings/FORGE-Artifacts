// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StableCoinContract is ERC20 {
    constructor() ERC20("StableCoin", "SBC") {
        _mint(msg.sender, 5_000_000_000 * 10 ** 18);
    }
}