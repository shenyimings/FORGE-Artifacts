// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract FakeToken is ERC20PresetMinterPauser {
    using SafeMath for uint256;

    constructor(string memory name, string memory symbol) ERC20PresetMinterPauser(name, symbol) {}
}
