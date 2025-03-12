pragma solidity ^0.6.0;

import "./MintableERC20.sol";

contract MockXYZ is MintableERC20 {
    constructor() public MintableERC20("Symthetix Token", "SMX", 18) {}
}
