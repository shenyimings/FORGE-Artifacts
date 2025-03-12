/**SPDX-License-Identifier: MIT */
pragma solidity ^0.8.0;

import "./BEP20Token.sol";

contract NortToken is BEP20Token {
    uint8 constant DECIMALS = 18;
    uint256 constant TOTAL_SUPPLY = 100_000_000 * 10**uint256(DECIMALS);

    constructor(string memory name_, string memory symbol_)
        BEP20Token(name_, symbol_, DECIMALS, TOTAL_SUPPLY)
    {
        require(_msgSender() != address(0));
    }

    //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}
}
