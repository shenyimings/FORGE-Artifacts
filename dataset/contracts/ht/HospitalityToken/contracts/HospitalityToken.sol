//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";


contract HospitalityToken is ERC20,ERC20Burnable {

    constructor(uint256 _totalSupply) ERC20("HospitalityToken", "HT") {
        _mint(msg.sender, _totalSupply);
    } 
    
}
