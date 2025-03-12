// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./SafeMath.sol";

contract CraftyFi is ERC20 {
    using SafeMath for uint256;
    constructor() ERC20("CraftyFi", "CFY") {
        _mint(msg.sender, 100000000 * 10 ** 18);
    }
}
