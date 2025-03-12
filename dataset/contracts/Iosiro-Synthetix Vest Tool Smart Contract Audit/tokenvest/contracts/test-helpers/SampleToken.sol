//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SampleToken is ERC20 {

    constructor() ERC20("SampleToken", "ST") { }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}