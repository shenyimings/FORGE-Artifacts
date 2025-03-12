pragma solidity 0.4.24;


/**
  @title PoaProxyCommon acts as a convention between:
  - PoaCommon (and its inheritants: PoaToken & PoaCrowdsale)
  - PoaProxy

  It dictates where to read and write storage
*/
contract PoaProxyCommon {
  /*****************************
  * Start Proxy Common Storage *
  *****************************/

  // PoaTokenMaster logic contract used by proxies
  address public poaTokenMaster;

  // PoaCrowdsaleMaster logic contract used by proxies
  address public poaCrowdsaleMaster;

  // Registry used for getting other contract addresses
  address public registry;

  /***************************
  * End Proxy Common Storage *
  ***************************/


  /*********************************
  * Start Common Utility Functions *
  *********************************/

  /// @notice Gets a given contract address by bytes32 in order to save gas
  function getContractAddress(string _name)
    public
    view
    returns (address _contractAddress)
  {
    bytes4 _signature = bytes4(keccak256("getContractAddress32(bytes32)"));
    bytes32 _name32 = keccak256(abi.encodePacked(_name));

    assembly {
      let _registry := sload(registry_slot) // load registry address from storage
      let _pointer := mload(0x40)          // Set _pointer to free memory pointer
      mstore(_pointer, _signature)         // Store _signature at _pointer
      mstore(add(_pointer, 0x04), _name32) // Store _name32 at _pointer offset by 4 bytes for pre-existing _signature

      // staticcall(g, a, in, insize, out, outsize) => returns 0 on error, 1 on success
      let result := staticcall(
        gas,       // g = gas: whatever was passed already
        _registry, // a = address: address in storage
        _pointer,  // in = mem in  mem[in..(in+insize): set to free memory pointer
        0x24,      // insize = mem insize  mem[in..(in+insize): size of signature (bytes4) + bytes32 = 0x24
        _pointer,  // out = mem out  mem[out..(out+outsize): output assigned to this storage address
        0x20       // outsize = mem outsize  mem[out..(out+outsize): output should be 32byte slot (address size = 0x14 <  slot size 0x20)
      )

      // revert if not successful
      if iszero(result) {
        revert(0, 0)
      }

      _contractAddress := mload(_pointer) // Assign result to return value
      mstore(0x40, add(_pointer, 0x24))   // Advance free memory pointer by largest _pointer size
    }
  }

  /*******************************
  * End Common Utility Functions *
  *******************************/
}
