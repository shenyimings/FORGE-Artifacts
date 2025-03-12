pragma solidity 0.5.12;

interface IMerkleRootsManager {

  /**
   * @notice Event emitted for a registerMerkleRoot transaction.
   */
  event LogMerkleRootRegistered(address indexed rootOwner, bytes32 indexed rootHash, uint rootDeposit, string treeContentURL);

  /**
   * @notice Event emitted for an unlockMerkleRootDeposit transaction.
   */
  event LogMerkleRootDepositUnlocked(address indexed rootOwner, bytes32 indexed rootHash);

  /**
   * @notice Register the given merkleRoot on the Aventus Protocol.
   * @param _rootHash Root hash of the merkle tree
   * @param _treeContentURL url linking to raw leaf data for all leaves on this tree
   */
  function registerMerkleRoot(bytes32 _rootHash, string calldata _treeContentURL) external;

  /**
   * @notice Get the timestamp for when the given root deposit can be unlocked. This is a combination of the root registration
   * time and the root deposit lock period.
   * @param _rootHash Root hash of the tree to get the deposit unlock time for
   */
  function getMerkleRootDepositUnlockTime(bytes32 _rootHash) external view returns (uint deregistrationTime_);

  /**
   * @notice Deregister the given merkle root from the Aventus Protocol.
   * @param _rootHash Root hash of the tree deposit to be unlocked
   */
  function unlockMerkleRootDeposit(bytes32 _rootHash) external;

  /**
   * @notice Get the required deposit for a new merkle root registration at the time of calling
   */
  function getNewMerkleRootDeposit() external view returns (uint deposit_);
}