// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";


contract PoolToken is ERC20PresetMinterPauser {
    using SafeMath for uint256;

    string internal constant prefix = "lp";

    constructor(string memory name, string memory symbol) ERC20PresetMinterPauser(name, createPoolTokenSymbol(symbol)) {}

    function createPoolTokenSymbol(string memory symbol) internal pure returns (string memory){
        return string(abi.encodePacked(prefix, symbol));
    }
}