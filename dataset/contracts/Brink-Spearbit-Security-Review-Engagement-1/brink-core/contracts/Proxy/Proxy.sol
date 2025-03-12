// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.10;
pragma abicoder v1;

/**
 * @dev Proxy is deployed for each unique Brink account.
 * @notice The contract fallback function proxies will delegatecall all calls to the contract deployed at the
 * ACCOUNT_IMPLEMENTATION address.
 */
contract Proxy {
  /// @dev Address of the account implementation that deployed Proxy accounts will delegatecall to
  address constant ACCOUNT_IMPLEMENTATION = 0x2da2f7444bA1D9AA3a66ea47C1A51F5019b753eA;

  /// @dev Placeholder address for the proxy owner, replaced with the actual owner before deployment
  address constant OWNER = 0xfefeFEFeFEFEFEFEFeFefefefefeFEfEfefefEfe;

 /**
  * @dev Fallback function performs a delegatecall to the ACCOUNT_IMPLEMENTATION contract.
  * This function will return whatever the ACCOUNT_IMPLEMENTATION call returns, or revert
  * if the ACCOUNT_IMPLEMENTATION call reverts.
  */
  fallback() external payable {
    assembly {
      calldatacopy(0, 0, calldatasize())
      let result := delegatecall(gas(), ACCOUNT_IMPLEMENTATION, 0, calldatasize(), 0, 0)
      returndatacopy(0, 0, returndatasize())
      switch result
      case 0 { revert(0, returndatasize()) }
      default { return(0, returndatasize()) }
    }
  }

  /**
   * @dev The proxy account contract must be able to receive ether. 
   * Contracts that receive Ether directly but do not define a receive Ether function 
   * or a payable fallback function throw an exception, sending back the Ether. 
   */
  receive() external payable {
    // this does nothing and costs minimal gas. It forces the compiler to include the OWNER constant in bytecode
    assembly { mstore(mload(0x40), OWNER) }
  }
}
