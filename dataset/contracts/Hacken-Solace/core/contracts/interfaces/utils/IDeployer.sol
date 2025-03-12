// SPDX-License-Identifier: GPL-3.0-or-later
// code borrowed from EIP-2470
// https://etherscan.io/address/0xce0042B868300000d44A59004Da54A005ffdcf9f#code
pragma solidity 0.8.6;

/**
 * @title IDeployer
 * @notice Exposes `CREATE2` (EIP-1014) to deploy bytecode on deterministic addresses based on initialization code and salt.
 * @author solace.fi
 */
interface IDeployer {

    /// @notice Emitted when a contract is deployed.
    event ContractDeployed(address createdContract);

    /**
     * @notice Deploys `initcode` using `salt` for defining the deterministic address.
     * @param initcode Initialization code.
     * @param salt Arbitrary value to modify resulting address.
     * @return createdContract Created contract address.
     */
    function deploy(bytes memory initcode, bytes32 salt) external returns (address payable createdContract);

    /**
     * @notice Deploys multiple contracts.
     * @param initcodes Initialization codes.
     * @param salts Arbitrary values to modify resulting addresses.
     * @return createdContracts Created contract addresses.
     */
    function deployMultiple(bytes[] memory initcodes, bytes32[] memory salts) external returns (address payable[] memory createdContracts);
}
