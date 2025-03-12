pragma solidity ^0.6.0;

import "./MintableERC20.sol";

contract MockBAT is MintableERC20 {
    constructor() public MintableERC20("BAT Token", "SMX", 8) {}
}
