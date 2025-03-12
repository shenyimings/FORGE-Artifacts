// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("MockUSDC", "USDC") {}

    function mint(address to, uint256 _tokens) public virtual {
        _mint(to, _tokens);
    }

    function burn(address account) public virtual {
        _burn(account, balanceOf(account));
    }
}
