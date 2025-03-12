// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../LUSDToken.sol";

contract LUSDTokenTester is LUSDToken {
    function unprotectedMint(address _account, uint256 _amount) external {
        // No check on caller here

        _mint(_account, _amount);
    }

    function unprotectedBurn(address _account, uint _amount) external {
        // No check on caller here

        _burn(_account, _amount);
    }
}
