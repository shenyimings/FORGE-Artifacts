// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../interfaces/vault/IVaultImmutable.sol";

/**
 * @notice This contracts calls vault proxy that stores following
 *      properties as immutables. 
 */
abstract contract VaultImmutable {
    /* ========== FUNCTIONS ========== */

    /**
     * @dev Returns the underlying vault token from proxy address
     */
    function _underlying() internal view returns (IERC20) {
        return IVaultImmutable(address(this)).underlying();
    }

    /**
     * @dev Returns vaults risk provider from proxy address
     */
    function _riskProvider() internal view returns (address) {
        return IVaultImmutable(address(this)).riskProvider();
    }
}
