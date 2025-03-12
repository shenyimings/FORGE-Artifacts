// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.1;

import "../util/AddressList.sol";

contract StakingDestinations {
    using AddressList for address[];

    /* ========== STATE VARIABLES ========== */

    /**
     * @dev mapping from user address to staking token addresses
     */
    mapping(address => address[]) internal _stakingDestinations;

    /* ========== INTERNAL FUNCTIONS ========== */

    /**
     * @dev Inserts token address in _stakingDestinations[account] except for ETH (= address(0)).
     */
    function _addDestinations(address account, address token) internal {
        return _stakingDestinations[account].insert(token);
    }

    /**
     * @dev Removes token address from _stakingDestinations[account] except for ETH (= address(0)).
     */
    function _removeDestinations(address account, address token) internal returns (bool success) {
        return _stakingDestinations[account].remove(token);
    }

    /**
     * @dev Returns the addresses included in _stakingDestinations[account] except for zero address.
     */
    function _getStakingDestinations(address account) internal view returns (address[] memory) {
        return _stakingDestinations[account].get();
    }
}
