// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";
contract USDT is ERC20 {

    constructor( address owner) ERC20("USDT", "USDT") {
    _mint(owner,1000000000*10**decimals());       
    }
    function decimals()public view override returns(uint8)
    {
        return 6;
    }
}
