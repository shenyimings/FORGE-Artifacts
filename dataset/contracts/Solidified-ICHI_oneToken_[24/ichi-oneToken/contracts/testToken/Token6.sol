// SPDX-License-Identifier: Unlicensed

pragma solidity 0.7.6;

import "../oz_modified/ICHIERC20.sol";

contract Token6 is ICHIERC20 {

    constructor() {
        initERC20("Token with 6 decimals", "Token6");
        _mint(msg.sender, 10000 * 10 ** 6);
        _setupDecimals(6);
    }

}
