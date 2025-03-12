// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@helix-foundation/contracts/currency/ECO.sol";

contract PeanutECO is ECO {
    constructor(Policy a, address b, uint256 c, address d) ECO(a, b, c, d) {}

    function freeMint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}
