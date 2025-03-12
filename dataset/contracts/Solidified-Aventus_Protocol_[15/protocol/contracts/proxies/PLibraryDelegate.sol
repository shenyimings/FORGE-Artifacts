pragma solidity 0.5.12;

import "../interfaces/IAventusStorage.sol";
import "./PDelegate.sol";
import "../Versioned.sol";

contract PLibraryDelegate is PDelegate, Versioned {

  function libraryDelegateFwd(string memory _libraryInstanceKey)
    internal
  {
    // NOTE: The first parameter from msg.data MUST be the AventusStorage contract
    // address or this will not work!
    bytes32 versionKey = keccak256(abi.encodePacked(_libraryInstanceKey, "-", getVersionMajorMinor()));
    address target = IAventusStorage(addressFromMsgData(msg.data)).getAddress(versionKey);
    delegatedFwd(target, msg.data);
  }

  // The first 4 bytes of msg.data are the method name. The next 32 bytes are
  // the 20 bytes of address padded to bytes32. Loading these 36 bytes of data into
  // an address variable will yield the address we require (the first 16 bytes will be ignored)
  function addressFromMsgData(bytes memory _data)
    private
    pure
    returns (address result_)
  {
    assert(_data.length >= 36);
    assembly {
      result_ := mload(add(_data, 36))
    }
  }
}