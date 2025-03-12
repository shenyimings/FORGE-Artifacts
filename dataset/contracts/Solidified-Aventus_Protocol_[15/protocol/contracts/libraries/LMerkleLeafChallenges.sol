pragma solidity 0.5.12;

import "../interfaces/IAventusStorage.sol";
import "./LMerkleLeafChecks.sol";
import "./LMerkleRoots.sol";

library LMerkleLeafChallenges {

  uint constant nodeLength = 64;
  bytes4 constant checkLeafFormatIdentifier = bytes4(keccak256("checkLeafFormat(bytes)"));

  // See IMerkleLeafChallenges for logs descriptions.
  event LogMerkleLeafChallengeSucceeded(address indexed rootOwner, bytes32 indexed rootHash, bytes32 leafHash,
      string challengeReason);

  function challengeLeafRules(IAventusStorage _storage, bytes calldata _leafData, bytes32[] calldata _merklePath)
    external
  {
    bytes32 leafHash = keccak256(_leafData);
    bytes32 merkleRoot = getMerkleRootIfRegistered(_storage, leafHash, _merklePath);

    uint rootRegistrationTime = LMerkleRoots.getRootRegistrationTime(_storage, merkleRoot);

    string memory challengeReason = LMerkleLeafChecks.checkLeafRules(_storage, _leafData, rootRegistrationTime);

    require(bytes(challengeReason).length != 0, "Challenge failed - leaf passes all rules");

    challengeSuccess(_storage, merkleRoot, leafHash, challengeReason);
  }

  function challengeLeafConsistency(IAventusStorage _storage, bytes calldata _leafData, bytes32[] calldata _merklePath)
    external
  {
    require(_leafData.length != nodeLength, "Challenge failed - nodes cannot be challenged");

    bytes32 leafHash = keccak256(_leafData);
    bytes32 merkleRoot = getMerkleRootIfRegistered(_storage, leafHash, _merklePath);

    string memory challengeReason = callCheckLeafFormat(_storage, _leafData);

    if (bytes(challengeReason).length == 0)
      challengeReason = LMerkleLeafChecks.checkLeafConsistency(_storage, _leafData);

    require(bytes(challengeReason).length != 0, "Challenge failed - leaf is consistent");

    challengeSuccess(_storage, merkleRoot, leafHash, challengeReason);
  }

  function challengeLeafDuplication(IAventusStorage _storage, bytes calldata _duplicateLeafData,
      bytes32[] calldata _duplicateMerklePath, bytes calldata _existingLeafData, bytes32[] calldata _existingMerklePath)
    external
  {
    bytes32 duplicateLeafHash = keccak256(abi.encodePacked(_duplicateLeafData));
    bytes32 duplicateRoot = getMerkleRootIfRegistered(_storage, duplicateLeafHash, _duplicateMerklePath,
        "Challenge failed - duplicate leaf does not exist");
    bytes32 existingLeafHash = keccak256(abi.encodePacked(_existingLeafData));
    bytes32 existingRoot = getMerkleRootIfRegistered(_storage, existingLeafHash, _existingMerklePath,
        "Challenge failed - existing leaf does not exist");

    require(rootsAreOrdered(_storage, existingRoot, duplicateRoot), "Challenge failed - duplicate leaf was registered first");

    if (duplicateRoot == existingRoot) {
      bool sameSibling = duplicateLeafHash == _existingMerklePath[0];
      require(!sameSibling, "Challenge failed - identical sibling hash is not counted as a duplicate");
      bool samePath = keccak256(abi.encodePacked(_duplicateMerklePath)) == keccak256(abi.encodePacked(_existingMerklePath));
      require(!samePath, "Challenge failed - same leaf in same tree is not counted as a duplicate");
    }

    require(LMerkleLeafChecks.checkLeafDuplication(_duplicateLeafData, _existingLeafData),
        "Challenge failed - not a duplicate");

    return challengeSuccess(_storage, duplicateRoot, duplicateLeafHash, "Is a duplicate transaction leaf");
  }

  function challengeLeafLifecycle(IAventusStorage _storage, bytes calldata _leafData,
      bytes32[] calldata _merklePath, bytes calldata _previousLeafData)
    external
  {
    bytes32 leafHash = keccak256(_leafData);
    bytes32 merkleRoot = getMerkleRootIfRegistered(_storage, leafHash, _merklePath);

    string memory challengeReason = LMerkleLeafChecks.checkLeafLifecycle(_leafData, _previousLeafData);
    require(bytes(challengeReason).length != 0, "Challenge failed - leaf is consistent with previous leaf");

    return challengeSuccess(_storage, merkleRoot, leafHash, challengeReason);
  }

  function callCheckLeafFormat(IAventusStorage _storage, bytes memory _leafData)
    private
    returns (string memory result_)
  {
    address lMerkleLeafChecksAddress = _storage.getAddress(keccak256(abi.encodePacked("LMerkleLeafChecksAddress")));
    bytes memory encodedFunctionCall = abi.encodeWithSelector(checkLeafFormatIdentifier, _leafData);
    (bool leafIsCorrectlyFormatted,) = lMerkleLeafChecksAddress.delegatecall(encodedFunctionCall);

    if (!leafIsCorrectlyFormatted)
      result_ = "Leaf is incorrectly formatted";
  }

  function getMerkleRootIfRegistered(IAventusStorage _storage, bytes32 _leafHash, bytes32[] memory _merklePath,
      string memory _errorMsg)
    private
    view
    returns (bytes32 merkleRoot_)
  {
    merkleRoot_ = LMerkleRoots.generateMerkleRoot(_storage, _merklePath, _leafHash);
    require(LMerkleRoots.merkleRootIsRegistered(_storage, merkleRoot_), _errorMsg);
  }

  function getMerkleRootIfRegistered(IAventusStorage _storage, bytes32 _leafHash, bytes32[] memory _merklePath)
    private
    view
    returns (bytes32 merkleRoot_)
  {
    string memory errorMsg = "Leaf and path do not refer to a registered merkle root";
    merkleRoot_ = getMerkleRootIfRegistered(_storage, _leafHash, _merklePath, errorMsg);
  }

  function challengeSuccess(IAventusStorage _storage, bytes32 _merkleRoot, bytes32 _leafHash, string memory _challengeReason)
    private
  {
    address rootOwner = LMerkleRoots.finaliseAutoChallenge(_storage, _merkleRoot);
    emit LogMerkleLeafChallengeSucceeded(rootOwner, _merkleRoot, _leafHash, _challengeReason);
  }

  function rootsAreOrdered(IAventusStorage _storage, bytes32 _firstRoot, bytes32 _secondRoot)
    private
    view
    returns (bool ordered_)
  {
    uint firstRootRegistrationTime = LMerkleRoots.getRootRegistrationTime(_storage, _firstRoot);
    uint secondRootRegistrationTime = LMerkleRoots.getRootRegistrationTime(_storage, _secondRoot);
    ordered_ = firstRootRegistrationTime <= secondRootRegistrationTime;
  }
}