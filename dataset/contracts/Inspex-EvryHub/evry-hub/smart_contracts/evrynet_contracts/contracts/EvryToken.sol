// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


import "../node_modules/@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract EvryToken is ERC20Burnable  {

    uint256 public constant INITIAL_SUPPLY = 1000 * 10**(6 + 18); // 1000M tokens
    // Default decimals is 18
    constructor(address owner) ERC20("Evrynet Coin", "EVRY") {
        _mint(owner, INITIAL_SUPPLY);
    }
}