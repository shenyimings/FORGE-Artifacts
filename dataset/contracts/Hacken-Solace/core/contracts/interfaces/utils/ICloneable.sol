// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

/**
 * @title Factory for arbitrary code deployment using the "CREATE" and "CREATE2" opcodes
 */
interface ICloneable {

    /***************************************
    EVENTS
    ***************************************/

    /// @notice Emitted when a contract is deployed.
    event ContractDeployed(address indexed deployment);

    /***************************************
    VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice calculate the deployment address for a given target and salt
     * @param salt input for deterministic address calculation
     * @return deployment address
     */
    function calculateMinimalProxyDeploymentAddress(bytes32 salt) external view returns (address);
}
