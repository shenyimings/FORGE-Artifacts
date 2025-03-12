// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../external/@openzeppelin/proxy/Proxy.sol";
import "../interfaces/vault/IVaultImmutable.sol";
import "../interfaces/vault/IVaultDetails.sol";

/**
 * @notice This contract is a non-upgradable proxy for Spool vault implementation.
 *
 * @dev
 * It is used to lower the gas cost of vault creation.
 * The contract holds vault specific immutable variables.
 */
contract VaultNonUpgradableProxy is Proxy, IVaultImmutable {
    /* ========== STATE VARIABLES ========== */

    /// @notice The address of vault implementation
    address public immutable vaultImplementation;

    /// @notice Vault underlying asset
    IERC20 public override immutable underlying;

    /// @notice Vault risk provider address
    address public override immutable riskProvider;

    /// @notice A number from -10 to 10 indicating the risk tolerance of the vault
    int8 public override immutable riskTolerance;

    /* ========== CONSTRUCTOR ========== */
    
    /**
     * @notice Sets the vault specific immutable values.
     *
     * @param _vaultImplementation implementation contract address of the vault
     * @param vaultImmutables vault immutable values
     */
    constructor(
        address _vaultImplementation,
        VaultImmutables memory vaultImmutables
    ) {
        vaultImplementation = _vaultImplementation;
        underlying = vaultImmutables.underlying;
        riskProvider = vaultImmutables.riskProvider;
        riskTolerance = vaultImmutables.riskTolerance;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    /**
     * @notice Return contract address of vault implementation.
     *
     * @return vault implementation contract address
     */
    function _implementation() internal view override returns (address) {
        return vaultImplementation;
    }
}
