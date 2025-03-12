// SPDX-License-Identifier: Unlicensed

pragma solidity 0.7.6;

import "../oz_modified/ICHIERC20.sol";

contract Token18 is ICHIERC20 {

    constructor() {
        initERC20("Token with 18 decimals", "Token18");
        _mint(msg.sender, 10000 * 10 ** 18);
        _setupDecimals(18);
    }

}
