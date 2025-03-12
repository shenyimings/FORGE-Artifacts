pragma solidity ^0.8.7;

/**
 * @title Interface for ELVaultFactory
 * @notice Vault factory
 */

interface IELVaultFactory {
    /**
     * @notice create vault contract proxy
     * @param operatorId operator id
     */
    function create(uint256 operatorId) external returns (address);

    /**
     * @notice Get information about an operator vault contract address
     * @param operatorId operator id
     */
    function getNodeOperatorVaultContract(uint256 operatorId) external view returns (address vaultContractAddress);
}
