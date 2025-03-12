pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "./Ownable.sol";
import "@0xsequence/erc-1155/contracts/utils/SafeMath.sol";

/**
 * @dev This contract allows an owner to execute registered calls after an expiration
 *      delay has passed. This contract can then be the owner of another contract to
 *      enforce delayed function calls.
 * @dev Does not support passing ETH in calls for simplicity, but could be added in V2.
 */
contract DelayedOwner is Ownable {
  using SafeMath for uint256;

  // Time transactions must be registered before being executable
  uint256 immutable internal EXECUTION_DELAY;
  
  // Mapping between transaction id and transaction hashes
  mapping(uint256 => bytes32) public txHashes;

  // Events
  event TransactionRegistered(Transaction transaction);
  event TransactionCancelled(Transaction transaction);
  event TransactionExecuted(Transaction transaction);

  // Transaction structure
  struct Transaction {
    Status status;       // Transaction status
    uint256 triggerTime; // Timestamp after which the transaction can be executed
    address target;      // Address of the contract to call
    uint256 id;          // Transaction identifier (unique)
    bytes data;          // calldata to pass
  }

  enum Status {
    NotRegistered, // 0x0 - Transaction was not registered
    Pending,       // 0x1 - Transaction was registered but not executed
    Executed,      // 0x2 - Transaction was executed
    Cancelled      // 0x3 - Transaction was registered and cancelled
  }

  /**
   * @dev Registers the execution delay for this contract 
   * @param _firstOwner Address of the first owner
   * @param _delay Amount of time in seconds the delay will be
   */
  constructor (address _firstOwner, uint256 _delay) Ownable(_firstOwner) {
    EXECUTION_DELAY = _delay;
  }


  /***********************************|
  |           Core Functions          |
  |__________________________________*/

  /**
   * @notice Register a transaction to execute post delay
   * @param _tx Transaction to execute
   */
  function register(Transaction memory _tx) onlyOwner() public {
    require(txHashes[_tx.id] == 0x0, "DelayedOwner#register: TX_ALREADY_REGISTERED");

    // Set trigger time and mark transaction as pending
    _tx.triggerTime = block.timestamp.add(EXECUTION_DELAY);
    _tx.status = Status.Pending;

    // Store transaction
    txHashes[_tx.id] = keccak256(abi.encode(_tx));
    emit TransactionRegistered(_tx);
  }

  /**
   * @notice Cancels a transaction that was registered but not yet executed or cancelled
   * @param _tx Transaction to cancel
   */
  function cancel(Transaction memory _tx) onlyOwner() onlyValidWitnesses(_tx) public {
    require(_tx.status == Status.Pending, "DelayedOwner#cancel: TX_NOT_PENDING");

    // Set status to Cancelled
    _tx.status = Status.Cancelled;

    // Store transaction
    txHashes[_tx.id] = keccak256(abi.encode(_tx));
    emit TransactionCancelled(_tx);
  }

  /**
   * @notice Will execute transaction specified
   * @param _tx Transaction to execute
   */
  function execute(Transaction memory _tx) onlyValidWitnesses(_tx) public {
    require(_tx.status == Status.Pending, "DelayedOwner#execute: TX_NOT_PENDING");
    require(_tx.triggerTime <= block.timestamp, "DelayedOwne#execute: TX_NOT_YET_EXECUTABLE");

    // Mark transaction as executed, preventing re-entrancy and replay
    _tx.status = Status.Executed;

    // Store transaction
    txHashes[_tx.id] = keccak256(abi.encode(_tx));

    // Execute transaction
    (bool success,) = _tx.target.call(_tx.data);
    require(success, "DelayedOwner#execute: TX_FAILED");
    emit TransactionExecuted(_tx); 
  }


  /***********************************|
  |         Utility Functions         |
  |__________________________________*/

  /**
   * @notice Verify if provided transaction object matches registered transaction
   * @param _tx Transaction to validate
   */
  function isValidWitness(Transaction memory _tx) public view returns (bool isValid) {
    return txHashes[_tx.id] == keccak256(abi.encode(_tx));
  }

  /**
   * @notice Will enforce that the provided transaction witness is valid
   * @param _tx Transaction to validate
   */
  modifier onlyValidWitnesses(Transaction memory _tx) {
    require(
      isValidWitness(_tx),
      "DelayedOwner#onlyValidWitnesses: INVALID_TX_WITNESS"
    );

    _;
  }
}

