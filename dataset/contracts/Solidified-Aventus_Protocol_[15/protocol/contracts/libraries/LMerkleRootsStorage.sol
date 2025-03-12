pragma solidity 0.5.12;

import "../interfaces/IAventusStorage.sol";

library LMerkleRootsStorage {

  string constant merkleRootTable = "MerkleRoot";
  string constant merkleRootsTable = "MerkleRoots";
  bytes32 constant rootDepositHash = keccak256(abi.encodePacked(merkleRootsTable, "RootDeposit"));
  bytes32 constant rootDepositLockPeriodHash = keccak256(abi.encodePacked(merkleRootsTable, "RootDepositLockPeriod"));

  function getRootDeposit(IAventusStorage _storage)
    external
    view
    returns (uint rootDeposit_)
  {
    rootDeposit_ = _storage.getUInt(rootDepositHash);
  }

  function getRootDepositLockPeriod(IAventusStorage _storage)
    external
    view
    returns (uint rootDepositLockPeriod_)
  {
    rootDepositLockPeriod_ = _storage.getUInt(rootDepositLockPeriodHash);
  }

  function getRootOwner(IAventusStorage _storage, bytes32 _rootHash)
    external
    view
    returns (address owner_)
  {
    owner_ = _storage.getAddress(keccak256(abi.encodePacked(merkleRootTable, _rootHash, "Owner")));
  }

  function setRootOwner(IAventusStorage _storage, bytes32 _rootHash, address _owner)
    external
  {
    _storage.setAddress(keccak256(abi.encodePacked(merkleRootTable, _rootHash, "Owner")), _owner);
  }

  function getDeposit(IAventusStorage _storage, bytes32 _rootHash)
    external
    view
    returns (uint deposit_)
  {
    deposit_ = _storage.getUInt(keccak256(abi.encodePacked(merkleRootTable, _rootHash, "Deposit")));
  }

  function setDeposit(IAventusStorage _storage, bytes32 _rootHash, uint _deposit)
    external
  {
    _storage.setUInt(keccak256(abi.encodePacked(merkleRootTable, _rootHash, "Deposit")), _deposit);
  }

  function setRootRegistrationTime(IAventusStorage _storage, bytes32 _rootHash, uint _registrationTime)
    external
  {
    _storage.setUInt(keccak256(abi.encodePacked(merkleRootTable, _rootHash, "RegistrationTime")), _registrationTime);
  }

  function getRootRegistrationTime(IAventusStorage _storage, bytes32 _rootHash)
    public
    view
    returns (uint registrationTime_)
  {
    registrationTime_ = _storage.getUInt(keccak256(abi.encodePacked(merkleRootTable, _rootHash, "RegistrationTime")));
  }
}