pragma solidity 0.4.24;

import "./PoaProxyCommon.sol";


/**
  @title This contract manages the storage of:
  - PoaProxy
  - PoaToken
  - PoaCrowdsale

  @notice PoaProxy uses chained "delegatecall()"s to call functions on
  PoaToken and PoaCrowdsale and sets the resulting storage
  here on PoaProxy.

  @dev `getContractAddress("PoaLogger").call()` does not use the return value
  because we would rather contract functions to continue even if the event
  did not successfully trigger on the logger contract.
*/
contract PoaProxy is PoaProxyCommon {
  uint8 public constant version = 1;

  event ProxyUpgraded(address upgradedFrom, address upgradedTo);

  /**
    @notice Stores addresses of our contract registry
    as well as the PoaToken and PoaCrowdsale master
    contracts to forward calls to.
  */
  constructor(
    address _poaTokenMaster,
    address _poaCrowdsaleMaster,
    address _registry
  )
    public
  {
    // Ensure that none of the given addresses are empty
    require(_poaTokenMaster != address(0));
    require(_poaCrowdsaleMaster != address(0));
    require(_registry != address(0));

    // Set addresses in common storage using deterministic storage slots
    poaTokenMaster = _poaTokenMaster;
    poaCrowdsaleMaster = _poaCrowdsaleMaster;
    registry = _registry;
  }

  /*****************************
   * Start Proxy State Helpers *
   *****************************/

  /**
    @notice Ensures that a given address is a contract by
    making sure it has code. Used during upgrading to make
    sure the new addresses to upgrade to are smart contracts.
   */
  function isContract(address _address)
    private
    view
    returns (bool)
  {
    uint256 _size;
    assembly { _size := extcodesize(_address) }

    return _size > 0;
  }

  /***************************
   * End Proxy State Helpers *
   ***************************/


  /*****************************
   * Start Proxy State Setters *
   *****************************/

  /// @notice Update the stored "poaTokenMaster" address to upgrade the PoaToken master contract
  function proxyChangeTokenMaster(address _newMaster)
    public
    returns (bool)
  {
    require(msg.sender == getContractAddress("PoaManager"));
    require(_newMaster != address(0));
    require(poaTokenMaster != _newMaster);
    require(isContract(_newMaster));
    address _oldMaster = poaTokenMaster;
    poaTokenMaster = _newMaster;

    emit ProxyUpgraded(_oldMaster, _newMaster);
    getContractAddress("PoaLogger").call(
      abi.encodeWithSignature(
        "logProxyUpgraded(address,address)",
        _oldMaster,
        _newMaster
      )
    );

    return true;
  }

  /// @notice Update the stored `poaCrowdsaleMaster` address to upgrade the PoaCrowdsale master contract
  function proxyChangeCrowdsaleMaster(address _newMaster)
    public
    returns (bool)
  {
    require(msg.sender == getContractAddress("PoaManager"));
    require(_newMaster != address(0));
    require(poaCrowdsaleMaster != _newMaster);
    require(isContract(_newMaster));
    address _oldMaster = poaCrowdsaleMaster;
    poaCrowdsaleMaster = _newMaster;

    emit ProxyUpgraded(_oldMaster, _newMaster);
    getContractAddress("PoaLogger").call(
      abi.encodeWithSignature(
        "logProxyUpgraded(address,address)",
        _oldMaster,
        _newMaster
      )
    );

    return true;
  }

  /***************************
   * End Proxy State Setters *
   ***************************/

  /**
    @notice Fallback function for all proxied functions using "delegatecall()".
    It will first forward all functions to the "poaTokenMaster" address. If the
    called function isn't found there, then "poaTokenMaster"'s fallback function
    will forward the call to "poaCrowdsale". If the called function also isn't
    found there, it will fail at last.
  */
  function()
    external
    payable
  {
    assembly {
      // Load PoaToken master address from first storage pointer
      let _poaTokenMaster := sload(poaTokenMaster_slot)

      // calldatacopy(t, f, s)
      calldatacopy(
        0x0, // t = mem position to
        0x0, // f = mem position from
        calldatasize // s = size bytes
      )

      // delegatecall(g, a, in, insize, out, outsize) => returns "0" on error, or "1" on success
      let result := delegatecall(
        gas, // g = gas
        _poaTokenMaster, // a = address
        0x0, // in = mem in  mem[in..(in+insize)
        calldatasize, // insize = mem insize  mem[in..(in+insize)
        0x0, // out = mem out  mem[out..(out+outsize)
        0 // outsize = mem outsize  mem[out..(out+outsize)
      )

      // Check if the call was successful
      if iszero(result) {
        // Revert if call failed
        revert(0, 0)
      }

      // returndatacopy(t, f, s)
      returndatacopy(
        0x0, // t = mem position to
        0x0,  // f = mem position from
        returndatasize // s = size bytes
      )
      // Return if call succeeded
      return(
        0x0,
        returndatasize
      )
    }
  }
}
