// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Lptoken is ERC20 {
    constructor() ERC20("Lptoken", "Lptoken") {
        _mint(msg.sender, 100000000 * 10**18);
    }
}
