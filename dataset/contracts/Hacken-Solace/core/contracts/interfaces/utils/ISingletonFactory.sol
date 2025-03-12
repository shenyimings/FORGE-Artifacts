// SPDX-License-Identifier: GPL-3.0-or-later
// code borrowed from https://rinkeby.etherscan.io/address/0xce0042B868300000d44A59004Da54A005ffdcf9f#code
pragma solidity 0.8.6;

/**
 * @title Singleton Factory (EIP-2470)
 * @notice Exposes CREATE2 (EIP-1014) to deploy bytecode on deterministic addresses based on initialization code and salt.
 * @author Ricardo Guilherme Schmidt (Status Research & Development GmbH)
 */
interface ISingletonFactory {
    /**
     * @notice Deploys `initCode` using `salt` for defining the deterministic address.
     * @param initCode Initialization code.
     * @param salt Arbitrary value to modify resulting address.
     * @return createdContract Created contract address.
     */
    function deploy(bytes memory initCode, bytes32 salt) external returns (address payable createdContract);
}
