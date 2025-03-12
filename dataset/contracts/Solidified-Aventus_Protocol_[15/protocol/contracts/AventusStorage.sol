pragma solidity 0.5.12;

import "./proxies/PDelegate.sol";
import "./interfaces/IAventusStorage.sol";
import "./interfaces/IERC20.sol";
import "./Owned.sol";

// Persistent storage on the blockchain

contract AventusStorage is Owned, PDelegate, IAventusStorage {

  bytes32 constant avtContractAddressKey = keccak256(abi.encodePacked("AVTERC20Instance"));

  event LogStorageAccessAllowed(string accessType, address indexed accessAddress);
  event LogStorageAccessDenied(string accessType, address indexed accessAddress);

  modifier onlyWithWriteAccess() {
    isAllowedAccess("write");
    _;
  }

  modifier onlyWithTransferAVTAccess() {
    isAllowedAccess("transferAVT");
    _;
  }

  mapping(bytes32 => bool) accessAllowed;
  mapping(bytes32 => uint) UInt;
  mapping(bytes32 => string) String;
  mapping(bytes32 => address) Address;
  mapping(bytes32 => bytes) Bytes;
  mapping(bytes32 => bytes32) Bytes32;
  mapping(bytes32 => bool) Boolean;
  mapping(bytes32 => int) Int;

  function allowAccess(string calldata _accessType, address _address)
    external
    onlyOwner
  {
    accessAllowed[getKey(_accessType, _address)] = true;
    emit LogStorageAccessAllowed(_accessType, _address);
  }

  function denyAccess(string calldata _accessType, address _address)
    external
    onlyOwner
  {
    accessAllowed[getKey(_accessType, _address)] = false;
    emit LogStorageAccessDenied(_accessType, _address);
  }

  function transferAVTTo(address _to, uint _tokens)
    external
    onlyWithTransferAVTAccess
  {
    IERC20 avt = IERC20(doGetAddress(avtContractAddressKey));
    // ONLY_IF_ASSERTS_OFF avt.transfer(_to, _tokens);
    assert(avt.transfer(_to, _tokens));
  }

  function transferAVTFrom(address _from, uint _tokens)
    external
    onlyWithTransferAVTAccess
  {
    IERC20 avt = IERC20(doGetAddress(avtContractAddressKey));
    // ONLY_IF_ASSERTS_OFF avt.transferFrom(_from, address(this), _tokens);
    assert(avt.transferFrom(_from, address(this), _tokens));
  }

  /**
   * @dev In case we need to extend functionality - avoids copying state
   */
  function ()
    external
  {
    address target = doGetAddress(keccak256(abi.encodePacked("StorageInstance")));

    require(target != address(0), "Extended functionality StorageContract not found");

    delegatedFwd(target, msg.data);
  }

  function getUInt(bytes32 _record)
    external
    view
    returns (uint value_)
  {
    value_ = UInt[_record];
  }

  function setUInt(bytes32 _record, uint _value)
    external
    onlyWithWriteAccess
  {
    UInt[_record] = _value;
  }

  function getString(bytes32 _record)
    external
    view
    returns (string memory value_)
  {
    value_ = String[_record];
  }

  function setString(bytes32 _record, string calldata _value)
    external
    onlyWithWriteAccess
  {
    String[_record] = _value;
  }

  function getAddress(bytes32 _record)
    external
    view
    returns (address value_)
  {
    value_ = doGetAddress(_record);
  }

  function setAddress(bytes32 _record, address _value)
    external
    onlyWithWriteAccess
  {
    Address[_record] = _value;
  }

  function getBytes(bytes32 _record)
    external
    view
    returns (bytes memory value_)
  {
    value_ = Bytes[_record];
  }

  function setBytes(bytes32 _record, bytes calldata _value)
    external
    onlyWithWriteAccess
  {
    Bytes[_record] = _value;
  }

  function getBytes32(bytes32 _record)
    external
    view
    returns (bytes32 value_)
  {
    value_ = Bytes32[_record];
  }

  function setBytes32(bytes32 _record, bytes32 _value)
    external
    onlyWithWriteAccess
  {
    Bytes32[_record] = _value;
  }

  function getBoolean(bytes32 _record)
    external
    view
    returns (bool value_)
  {
    value_ = Boolean[_record];
  }

  function setBoolean(bytes32 _record, bool _value)
    external
    onlyWithWriteAccess
  {
    Boolean[_record] = _value;
  }

  function getInt(bytes32 _record)
    external
    view
    returns (int value_)
  {
    value_ = Int[_record];
  }

  function setInt(bytes32 _record, int _value)
    external
    onlyWithWriteAccess
  {
    Int[_record] = _value;
  }

  function doGetAddress(bytes32 _record)
    internal
    view
    returns (address value_)
  {
    value_ = Address[_record];
  }

  function isAllowedAccess(string memory _accessType)
    private
    view
  {
    require(msg.sender == owner || accessAllowed[getKey(_accessType, msg.sender)], "Access denied for storage");
  }

  function getKey(string memory _accessType, address _address)
    private
    pure
    returns (bytes32 key_)
  {
    key_ = keccak256(abi.encodePacked(_accessType, _address));
  }
}