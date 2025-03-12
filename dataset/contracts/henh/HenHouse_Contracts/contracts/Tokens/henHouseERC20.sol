// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./HenHouseRouter.sol";

contract HenHouseERC20 is Ownable, ERC20 {
    using SafeMath for uint256;

    HenHouseRouter public router;

    constructor(string memory name, string memory symbol, address _henHouseRouter) ERC20(name, symbol) {
        router = HenHouseRouter(_henHouseRouter);
    }
}