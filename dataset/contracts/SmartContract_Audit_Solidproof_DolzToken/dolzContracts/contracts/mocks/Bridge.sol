// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../IDolzToken.sol";

contract Bridge {
    IDolzToken immutable DolzToken;

    constructor(IDolzToken _DolzToken) {
        DolzToken = _DolzToken;
    }

    function deposit(address account, uint256 amount) external {
        DolzToken.mintFromBridge(account, amount);
    }

    function withdraw(address account, uint256 amount) external {
        DolzToken.burnFromBridge(account, amount);
    }
}
