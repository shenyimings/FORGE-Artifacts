pragma solidity 0.5.12;

import "../interfaces/IAventusStorage.sol";
import "./LValidators.sol";
import "./LMerkleRootsStorage.sol";
import "./LAventusTime.sol";
import "./LAVTManager.sol";

library LMerkleRoots {

  // See IMerkleRootsManager interface for logs description
  event LogMerkleRootRegistered(address indexed rootOwner, bytes32 indexed rootHash, uint rootDeposit, string treeContentURL);
  event LogMerkleRootDepositUnlocked(address indexed rootOwner, bytes32 indexed rootHash);

  modifier onlyRegisteredValidator(IAventusStorage _storage) {
    require(LValidators.isRegistered(_storage, msg.sender), "Sender must be a registered validator");
    _;
  }

  modifier onlyIfRootNotRegistered(IAventusStorage _storage, bytes32 _rootHash) {
    require(!merkleRootIsRegistered(_storage, _rootHash), "Merkle root is already registered");
    _;
  }

  modifier onlyAfterUnlockTime(IAventusStorage _storage, bytes32 _rootHash) {
    uint timeNow = LAventusTime.getCurrentTime(_storage);
    require(timeNow >= getRootDepositUnlockTime(_storage, _rootHash), "Must be after root deposit unlock time");
    _;
  }

  function registerMerkleRoot(IAventusStorage _storage, bytes32 _rootHash, string calldata _treeContentURL)
    external
    onlyRegisteredValidator(_storage)
    onlyIfRootNotRegistered(_storage, _rootHash)
  {
    require(bytes(_treeContentURL).length != 0, "Tree content URL must not be empty");

    uint deposit = getNewMerkleRootDeposit(_storage);
    LAVTManager.lockDeposit(_storage, msg.sender, deposit);

    uint currentTime = LAventusTime.getCurrentTime(_storage);
    LMerkleRootsStorage.setRootRegistrationTime(_storage, _rootHash, currentTime);
    LMerkleRootsStorage.setRootOwner(_storage, _rootHash, msg.sender);
    LMerkleRootsStorage.setDeposit(_storage, _rootHash, deposit);
    LValidators.updateExpiryTimeIfNecessary(_storage, msg.sender, currentTime);

    emit LogMerkleRootRegistered(msg.sender, _rootHash, deposit, _treeContentURL);
  }

  function unlockMerkleRootDeposit(IAventusStorage _storage, bytes32 _rootHash)
    external
    onlyAfterUnlockTime(_storage, _rootHash)
  {
    uint deposit = LMerkleRootsStorage.getDeposit(_storage, _rootHash);
    require(deposit != 0, 'Root has no deposit');
    address rootOwner = LMerkleRootsStorage.getRootOwner(_storage, _rootHash);
    LMerkleRootsStorage.setDeposit(_storage, _rootHash, 0);
    LAVTManager.unlockDeposit(_storage, rootOwner, deposit);
    emit LogMerkleRootDepositUnlocked(rootOwner, _rootHash);
  }

  function finaliseAutoChallenge(IAventusStorage _storage, bytes32 _rootHash)
    external
    returns (address rootOwner_)
  {
    uint deposit = LMerkleRootsStorage.getDeposit(_storage, _rootHash);
    rootOwner_ = LMerkleRootsStorage.getRootOwner(_storage, _rootHash);

    if (deposit != 0) {
      LValidators.validatorFailedRootChallenge(_storage, rootOwner_);
      LMerkleRootsStorage.setDeposit(_storage, _rootHash, 0);
      LAVTManager.unlockDeposit(_storage, rootOwner_, deposit);
      LAVTManager.decreaseAVT(_storage, rootOwner_, deposit);
      LAVTManager.increaseAVT(_storage, msg.sender, deposit);
    }
  }

  function getRootRegistrationTime(IAventusStorage _storage, bytes32 _rootHash)
    public
    view
    returns (uint registrationTime_)
  {
    registrationTime_ = LMerkleRootsStorage.getRootRegistrationTime(_storage, _rootHash);
  }

  function getRootDepositUnlockTime(IAventusStorage _storage, bytes32 _rootHash)
    public
    view
    returns (uint unlockTime_)
  {
    uint registrationTime = getRootRegistrationTime(_storage, _rootHash);
    uint rootDepositLockPeriod = LMerkleRootsStorage.getRootDepositLockPeriod(_storage);
    unlockTime_ = registrationTime + rootDepositLockPeriod;
  }

  function getNewMerkleRootDeposit(IAventusStorage _storage)
    public
    view
    returns (uint deposit_)
  {
    deposit_ = LMerkleRootsStorage.getRootDeposit(_storage);
  }

  function merkleRootIsRegistered(IAventusStorage _storage, bytes32 _rootHash)
    public
    view
    returns (bool merkleRootIsRegistered_)
  {
    merkleRootIsRegistered_ = LMerkleRootsStorage.getRootOwner(_storage, _rootHash) != address(0);
  }

  // NOTE: IAventusStorage is not used here but is required for proxying
  function generateMerkleRoot(IAventusStorage, bytes32[] memory _merklePath, bytes32 _leafHash)
    public
    pure
    returns (bytes32 rootHash_)
  {
    bytes32 computedHash = _leafHash;

    for (uint i = 0; i < _merklePath.length; i++) {
      bytes32 pathElement = _merklePath[i];

      if (computedHash < pathElement)
        computedHash = keccak256(abi.encodePacked(computedHash, pathElement));
      else
        computedHash = keccak256(abi.encodePacked(pathElement, computedHash));
    }

    rootHash_ = computedHash;
  }
}