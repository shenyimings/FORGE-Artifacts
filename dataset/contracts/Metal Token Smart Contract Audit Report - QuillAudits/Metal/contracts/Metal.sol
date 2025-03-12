// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Blacklistable.sol";

contract Metal is Blacklistable, ERC20 {
    constructor() ERC20("METAL Token", "METAL") {
        _mint(msg.sender, 2750000000 * 10 ** decimals());
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override notBlacklisted(from) {}
}