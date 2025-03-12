// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @title MultiSigWallet
 * @dev A smart contract for managing multi-signature wallets.
 */
contract MultiSigWallet is Initializable {
    /// @notice Struct to represent a transaction
    struct Transaction {
        address to; // The target address of the transaction
        uint value; // The amount of ETH to send
        bytes data; // The data to include in the transaction
        bool executed; // A flag indicating if the transaction is executed
        uint numConfirmations; // The number of confirmations received for the transaction
    }

    /// @notice An array to store the transactions
    Transaction[] public transactions;
    /// @notice An array to store the addresses of the wallet owners
    address[] public owners;
    /// @notice The number of confirmations required for transactions
    uint public numConfirmationsRequired;

    /// @notice A mapping to check if a transaction is confirmed by a specific owner
    mapping(uint => mapping(address => bool)) public isConfirmed;
    /// @notice A mapping to check if an address is an owner
    mapping(address => bool) public isOwner;

    /// @notice mtc deposited
    event Deposit(address indexed sender, uint amount, uint balance);
    /// @notice transaction submitted
    event SubmitTransaction(
        address indexed owner,
        uint indexed txIndex,
        address indexed to,
        uint value,
        bytes data
    );
    /// @notice transaction submitted
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    /// @notice confirmation revoked
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    /// @notice transaction executed
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);

    /**
     * @dev Modifier to check if the caller is an owner.
     */
    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    /**
     * @dev Modifier to check if the transaction index exists.
     * @param _txIndex The index of the transaction.
     */
    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    /**
     * @dev Modifier to check if the transaction is not executed.
     * @param _txIndex The index of the transaction.
     */
    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    /**
     * @dev Modifier to check if the transaction is not confirmed by the caller.
     * @param _txIndex The index of the transaction.
     */
    modifier notConfirmed(uint _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }

    /**
     * @dev The receive function is a special function that allows the contract to accept MTC transactions.
     * It emits a Deposit event to record the deposit details.
     */
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    /**
     * @dev Initialize the contract with owners and required confirmations.
     * @param _owners An array of owner addresses.
     * @param _numConfirmationsRequired The number of confirmations required for transactions.
     */
    function initialize(
        address[] memory _owners,
        uint _numConfirmationsRequired
    ) external initializer {
        require(_owners.length > 0, "owners required");
        require(
            _numConfirmationsRequired > 0 &&
                _numConfirmationsRequired <= _owners.length,
            "invalid number of required confirmations"
        );

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    /**
     * @dev Submit a new transaction for approval.
     * @param _to The address to which the transaction is directed.
     * @param _value The amount of ETH to send.
     * @param _data The data to include in the transaction.
     */
    function submitTransaction(
        address _to,
        uint _value,
        bytes memory _data
    ) public onlyOwner {
        uint txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    /**
     * @dev Confirm a pending transaction.
     * @param _txIndex The index of the transaction to confirm.
     */
    function confirmTransaction(
        uint _txIndex
    )
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    /**
     * @dev Execute a confirmed transaction.
     * @param _txIndex The index of the transaction to execute.
     */
    function executeTransaction(
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    /**
     * @dev Revoke a previous confirmation for a transaction.
     * @param _txIndex The index of the transaction to revoke confirmation from.
     */
    function revokeConfirmation(
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    /**
     * @dev Get the list of wallet owners.
     * @return An array of owner addresses.
     */
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    /**
     * @dev Get the total count of pending transactions.
     * @return The count of pending transactions.
     */
    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }

    /**
     * @dev Get details of a specific transaction.
     * @param _txIndex The index of the transaction to query.
     * @return to - The transaction target address.
     * @return value - The transaction amount in ETH.
     * @return data - The transaction data.
     * @return executed - A boolean indicating if the transaction has been executed.
     * @return numConfirmations - The number of confirmations received for the transaction.
     */
    function getTransaction(
        uint _txIndex
    )
        public
        view
        returns (
            address to,
            uint value,
            bytes memory data,
            bool executed,
            uint numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }
}
