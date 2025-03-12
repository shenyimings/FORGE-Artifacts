// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../helpers/Blacklistable.sol";
import "../helpers/Freezeable.sol";

/**
 * @title MainnetBridge
 * @dev A smart contract for bridging MTC(BSC) to Metatime Mainnet.
 */
contract MainnetBridge is Blacklistable, Freezeable {
    /// @notice basic transaction payload for bridge
    struct Transaction {
        address receiver; // Address of the receiver on the mainnet chain.
        uint256 amount; // The amount of tokens to be bridged.
    }

    /// @notice A mapping of transaction hash to Transaction structure.
    mapping(bytes32 => Transaction) public history;

    /// @notice bridge has completed
    event Bridge(
        bytes32 indexed txHash,
        address indexed receiver,
        uint256 indexed amount
    );

    /**
     * @dev Modifier that checks if a transaction with the given hash does not exist in the history.
     * @param txHash The hash of the transaction.
     */
    modifier notExist(bytes32 txHash) {
        require(
            history[txHash].amount == 0,
            "MainnetBridge: Transaction is already setted"
        );
        _;
    }

    /**
     * @dev The receive function is a special function that allows the contract to accept MTC transactions.
     */
    receive() external payable {}

    /**
     * @dev Bridges a transaction to mainnet chain.
     * @param txHash The hash of the transaction.
     * @param receiver The address of the receiver on mainnet chain.
     * @param amount The amount to be bridged.
     */
    function bridge(
        bytes32 txHash,
        address receiver,
        uint256 amount
    )
        external
        payable
        isNotFreezed
        notExist(txHash)
        isBlacklisted(receiver)
        onlyOwnerRole(msg.sender)
    {
        history[txHash] = Transaction(receiver, amount);
        _transfer(receiver, amount);
        emit Bridge(txHash, receiver, amount);
    }

    /**
     * @dev Transfers funds to a specified receiver.
     * @param receiver The address of the receiver.
     * @param amount The amount to be transferred.
     */
    function transfer(
        address receiver,
        uint256 amount
    )
        external
        payable
        isFreezed
        onlyManagerRole(receiver)
        onlyOwnerRole(msg.sender)
    {
        _transfer(receiver, amount);
    }

    /**
     * @dev Internal function to perform the actual transfer.
     * @param receiver The address of the receiver.
     * @param amount The amount to be transferred.
     */
    function _transfer(address receiver, uint256 amount) internal {
        require(amount > 0, "MainnetBridge: Amount must be higher than 0");
        require(
            receiver != address(0),
            "MainnetBridge: Receiver cannot be zero address"
        );
        (bool sent, ) = payable(receiver).call{value: amount}("");
        require(sent, "MainnetBridge: Transfer failed");
    }
}
