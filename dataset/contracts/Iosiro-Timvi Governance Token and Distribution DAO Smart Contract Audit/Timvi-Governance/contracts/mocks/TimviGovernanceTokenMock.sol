// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "../TimviGovernanceToken.sol";


contract TimviGovernanceTokenMock is TimviGovernanceToken {

    function mint(address to, uint amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint amount) external {
        _burn(from, amount);
    }
}
