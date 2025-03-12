// SPDX-License-Identifier: MIT
// Used for adding features for unit tests to the normal token
pragma solidity ^0.8.4;

import "../EUROe.sol";

//slither-disable-next-line unprotected-upgrade
contract MockToken is EUROe {
    function freeMint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    // Used only for checking proper authorization in super
    function checkAuthorizeUpgrade() public {
        super._authorizeUpgrade(address(this));
    }
}
