// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { MultiSigWallet } from "./MultiSigWallet.sol";

/**
 * @title MultiSigWalletFactory contract
 * @author CloudWalk Inc.
 * @dev The contract factory for creating new multisig wallet contracts.
 */
contract MultiSigWalletFactory {
    /**
     * @dev Emitted when a new multisig wallet is deployed.
     * @param deployer The address of the wallet deployer.
     * @param wallet The address of the deployed wallet.
     * @param id The id of the deployed wallet.
     */
    event NewWallet(address indexed deployer, address indexed wallet, uint indexed id);

    /// @dev An array of wallets deployed by this factory.
    address[] public wallets;

    /**
     * @dev Deploys a new multisig wallet contract.
     * @param owners An array of the owners of the deployed wallet.
     * @param requiredApprovals The number of required approvals to execute transactions.
     * @return The address of the deployed wallet.
     */
    function deployNewWallet(address[] memory owners, uint16 requiredApprovals) external returns (address) {
        address newWallet = address(new MultiSigWallet(owners, requiredApprovals));
        wallets.push(newWallet);
        emit NewWallet(msg.sender, newWallet, wallets.length - 1);
        return newWallet;
    }

    /**
     * @dev Returns the number of deployed wallets.
     */
    function walletsCount() external view returns (uint256) {
        return wallets.length;
    }
}
