pragma solidity 0.5.12;

interface IMerkleLeafChallenges {

  /**
   * @notice Event emitted when a leaf has been successfully challenged.
   */
  event LogMerkleLeafChallengeSucceeded(address indexed rootOwner, bytes32 indexed rootHash, bytes32 leafHash,
      string challengeReason);

  /**
   * @notice Challenge a leaf which contains data which is provably inconsistent or incorrect
   * @param _leafData abiEncoded data of leaf content (field values and their types)
   * @param _merklePath path of hashes to the root from the hashed leaf
   */
  function challengeLeafConsistency(bytes calldata _leafData, bytes32[] calldata _merklePath) external;

  /**
   * @notice Challenge a leaf which contains data that has broken the rules
   * @param _leafData abiEncoded data of leaf content (field values and their types)
   * @param _merklePath path of hashes to the root from the hashed leaf
   */
  function challengeLeafRules(bytes calldata _leafData, bytes32[] calldata _merklePath) external;

  /**
   * @notice Challenge a leaf which contains data which already exists in another leaf
   * @param _duplicateLeafData abiEncoded data of challenged leaf content (field values and their types)
   * @param _duplicateMerklePath path of hashes to the root from the hashed challenged leaf
   * @param _existingLeafData abiEncoded data of the existing leaf content (field values and their types)
   * @param _existingMerklePath path of hashes to the root from the hashed existing leaf
   */
  function challengeLeafDuplication(bytes calldata _duplicateLeafData, bytes32[] calldata _duplicateMerklePath,
      bytes calldata _existingLeafData, bytes32[] calldata _existingMerklePath) external;

  /**
   * @notice Challenge a leaf which breaks the rules imposed by a previously published valid leaf
   * @param _leafData abiEncoded data of leaf content (field values and their types)
   * @param _merklePath path of hashes to the root from the hashed leaf
   * @param _previousLeafData abiEncoded data of the prior valid leaf content (field values and their types)
   */
  function challengeLeafLifecycle(bytes calldata _leafData, bytes32[] calldata _merklePath,
      bytes calldata _previousLeafData) external;
}