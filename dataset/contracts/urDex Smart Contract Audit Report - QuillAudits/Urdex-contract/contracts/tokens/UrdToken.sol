// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.17;

import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UrdToken is ERC20Burnable {
    uint256 public constant MAX_SUPPLY = 100_000_000 ether;

    constructor() ERC20("URD Token", "URD") {
        _mint(_msgSender(), MAX_SUPPLY);
    }
}
