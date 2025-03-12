// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.1;

import "../util/AddressList.sol";

contract Whitelist {
    using AddressList for address[];

    /* ========== STATE VARIABLES ========== */

    /**
     * @dev mapping from user address to whitelist token addresses
     */
    address[] internal _whitelist;

    /* ========== INTERNAL FUNCTIONS ========== */

    /**
     * @dev Inserts token address in _whitelist except for ETH (= address(0)).
     */
    function _addWhitelist(address token) internal {
        return _whitelist.insert(token);
    }

    /**
     * @dev Removes token address from _whitelist except for ETH (= address(0)).
     */
    function _removeWhitelist(address token) internal returns (bool success) {
        return _whitelist.remove(token);
    }

    /**
     * @dev Returns the addresses included in _whitelist except for zero address.
     */
    function _getWhitelist() internal view returns (address[] memory) {
        return _whitelist.get();
    }
}
