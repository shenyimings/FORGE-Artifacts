/*
 * SPDX-License-Identitifer:    GPL-3.0-or-later
 */

pragma solidity ^0.4.24;

import "@aragon/os/contracts/lib/token/ERC20.sol";


/**
 * @title ERC20ViewOnly
 * @notice Abstract ERC20 interface that is "view-only" by disallowing transfers and allowances. Implementations must track account balances via another mechanism.
 * @dev Implemented functions at this level **NEVER** revert
 */
contract ERC20ViewOnly is ERC20 {
    string private constant ERROR_TOKEN_ONLY = "ERC20_VIEW_ONLY";

    function approve(address, uint256) public returns (bool) {
        revert(ERROR_TOKEN_ONLY);
    }

    function transfer(address, uint256) public returns (bool) {
        revert(ERROR_TOKEN_ONLY);
    }

    function transferFrom(address, address, uint256) public returns (bool) {
        revert(ERROR_TOKEN_ONLY);
    }

    function allowance(address, address) public view returns (uint256) {
        return 0;
    }
}
