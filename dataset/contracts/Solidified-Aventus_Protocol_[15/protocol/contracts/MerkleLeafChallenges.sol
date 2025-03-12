pragma solidity 0.5.12;

import "./interfaces/IAventusStorage.sol";
import "./interfaces/IMerkleLeafChallenges.sol";
import "./libraries/LMerkleLeafChallenges.sol";
import "./Owned.sol";
import "./Versioned.sol";

contract MerkleLeafChallenges is IMerkleLeafChallenges, Owned, Versioned {

  IAventusStorage public s;

  constructor(IAventusStorage _s)
    public
  {
    s = _s;
  }

  function challengeLeafConsistency(bytes calldata _leafData, bytes32[] calldata _merklePath)
    external
  {
    LMerkleLeafChallenges.challengeLeafConsistency(s, _leafData, _merklePath);
  }

  function challengeLeafRules(bytes calldata _leafData, bytes32[] calldata _merklePath)
    external
  {
    LMerkleLeafChallenges.challengeLeafRules(s, _leafData, _merklePath);
  }

  function challengeLeafDuplication(bytes calldata _duplicateLeafData, bytes32[] calldata _duplicateMerklePath,
      bytes calldata _existingLeafData, bytes32[] calldata _existingMerklePath)
    external
  {
    LMerkleLeafChallenges.challengeLeafDuplication(s, _duplicateLeafData, _duplicateMerklePath, _existingLeafData,
        _existingMerklePath);
  }

  function challengeLeafLifecycle(bytes calldata _leafData, bytes32[] calldata _merklePath,
      bytes calldata _previousLeafData)
    external
  {
    LMerkleLeafChallenges.challengeLeafLifecycle(s, _leafData, _merklePath, _previousLeafData);
  }
}