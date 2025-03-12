// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "../TimviGovernanceToken.sol";


contract RandomTokenMock is TimviGovernanceToken {

    function mint(address to, uint amount) external {
        _mint(to, amount);
    }
}
