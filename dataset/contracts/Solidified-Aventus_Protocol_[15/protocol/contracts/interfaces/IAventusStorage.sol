pragma solidity 0.5.12;

interface IAventusStorage {

  /**
   * @notice Event emitted for a allowAccess transaction.
   */
  event LogStorageAccessAllowed(string accessType, address indexed accessAddress);

  /**
   * @notice Event emitted for a denyAccess transaction.
   */
  event LogStorageAccessDenied(string accessType, address indexed accessAddress);

  /**
   * @notice Allows access to storage.
   * @param _accessType type of access to allow
   * @param _address address of contract that is granted access
   */
  function allowAccess(string calldata _accessType, address _address) external;

  /**
   * @notice Deny access to storage.
   * @param _accessType type of access to deny
   * @param _address address of contract that is denied access
   */
  function denyAccess(string calldata _accessType, address _address) external;

  /**
   * @notice Transfer AVT to address from erc20 contract.
   * @param _to address of contract to transfer AVT to
   * @param _tokens number of tokens to transfer
   */
  function transferAVTTo(address _to, uint _tokens) external;

  /**
   * @notice Transfer AVT to erc20 contract from address.
   * @param _from address of contract to transfer AVT from
   * @param _tokens number of tokens to transfer
   */
  function transferAVTFrom(address _from, uint _tokens) external;

  /**
   * @notice Get a stored uint
   * @param _record The key for finding a given record value
   * @return value_ the value in the requested record
   */
  function getUInt(bytes32 _record) external view returns (uint value_);

  /**
   * @notice Store a uint record
   * @param _record The key that will be used to obtain value
   * @param _value The value to be stored
   */
  function setUInt(bytes32 _record, uint _value) external;

  /**
   * @notice Get a stored string value
   * @param _record The key for finding a given record value
   * @return value_ the value in the requested record
   */
  function getString(bytes32 _record) external view returns (string memory value_);

  /**
   * @notice Store a string record
   * @param _record The key that will be used to obtain value
   * @param _value The value to be stored
   */
  function setString(bytes32 _record, string calldata _value) external;

  /**
   * @notice Get a stored address value
   * @param _record The key for finding a given record value
   * @return value_ the value in the requested record
   */
  function getAddress(bytes32 _record) external view returns (address value_);

  /**
   * @notice Store an address record
   * @param _record The key that will be used to obtain value
   * @param _value The value to be stored
   */
  function setAddress(bytes32 _record, address _value) external;

  /**
   * @notice Get a stored bytes value
   * @param _record The key for finding a given record value
   * @return value_ the value in the requested record
   */
  function getBytes(bytes32 _record) external view returns (bytes memory value_);

  /**
   * @notice Store a bytes record
   * @param _record The key that will be used to obtain value
   * @param _value The value to be stored
   */
  function setBytes(bytes32 _record, bytes calldata _value) external;

  /**
   * @notice Get a stored bytes32 value
   * @param _record The key for finding a given record value
   * @return value_ the value in the requested record
   */
  function getBytes32(bytes32 _record) external view returns (bytes32 value_);

  /**
   * @notice Store a bytes32 record
   * @param _record The key that will be used to obtain value
   * @param _value The value to be stored
   */
  function setBytes32(bytes32 _record, bytes32 _value) external;

  /**
   * @notice Get a stored bool value
   * @param _record The key for finding a given record value
   * @return value_ the value in the requested record
   */
  function getBoolean(bytes32 _record) external view returns (bool value_);

  /**
   * @notice Store a bool record
   * @param _record The key that will be used to obtain value
   * @param _value The value to be stored
   */
  function setBoolean(bytes32 _record, bool _value) external;

  /**
   * @notice Get a stored int value
   * @param _record The key for finding a given record value
   * @return value_ the value in the requested record
   */
  function getInt(bytes32 _record) external view returns (int value_);

  /**
   * @notice Store an int record
   * @param _record The key that will be used to obtain value
   * @param _value The value to be stored
   */
  function setInt(bytes32 _record, int _value) external;
}