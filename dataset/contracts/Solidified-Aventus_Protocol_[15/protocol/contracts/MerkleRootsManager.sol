pragma solidity 0.5.12;

import "./interfaces/IMerkleRootsManager.sol";
import "./interfaces/IAventusStorage.sol";
import "./libraries/LMerkleRoots.sol";
import "./Owned.sol";
import "./Versioned.sol";

contract MerkleRootsManager is IMerkleRootsManager, Owned, Versioned {

    IAventusStorage public s;

    constructor(IAventusStorage _s)
      public
    {
      s = _s;
    }

    function registerMerkleRoot(bytes32 _rootHash, string calldata _treeContentURL)
      external
    {
      LMerkleRoots.registerMerkleRoot(s, _rootHash, _treeContentURL);
    }

    function getMerkleRootDepositUnlockTime(bytes32 _rootHash)
      external
      view
      returns (uint deregistrationTime_)
    {
      return LMerkleRoots.getRootDepositUnlockTime(s, _rootHash);
    }

    function unlockMerkleRootDeposit(bytes32 _rootHash)
      external
    {
      LMerkleRoots.unlockMerkleRootDeposit(s, _rootHash);
    }

    function getNewMerkleRootDeposit()
      external
      view
      returns (uint deposit_)
    {
      deposit_ = LMerkleRoots.getNewMerkleRootDeposit(s);
    }
}