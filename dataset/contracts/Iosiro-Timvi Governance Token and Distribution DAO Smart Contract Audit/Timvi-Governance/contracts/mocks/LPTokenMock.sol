// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "../TimviGovernanceToken.sol";

contract LPTokenMock is ERC20Detailed {

    constructor() public ERC20Detailed("Test LP Token", "TLP", 18) {}

    function mint(address to, uint amount) external {
        _mint(to, amount);
    }
}
