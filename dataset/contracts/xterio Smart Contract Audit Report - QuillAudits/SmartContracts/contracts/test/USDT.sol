// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDT is ERC20 {

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    constructor() ERC20("StableCoin USDT", "USDT") {
        _mint(msg.sender, 9_000_000 * 10 ** decimals());
    }
}