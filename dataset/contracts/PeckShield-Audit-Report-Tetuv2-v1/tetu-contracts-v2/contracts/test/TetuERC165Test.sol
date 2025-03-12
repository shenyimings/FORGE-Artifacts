// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../tools/TetuERC165.sol";

/// @author bogdoslav
contract TetuERC165Test is TetuERC165 {

  // *************************************************************
  //                        EXTERNAL FUNCTIONS
  // *************************************************************

  function isInterfaceSupported(address contractAddress, bytes4 interfaceId) external view returns (bool) {
    return _isInterfaceSupported(contractAddress, interfaceId);
  }

  function requireInterface(address contractAddress, bytes4 interfaceId) external view {
    _requireInterface(contractAddress, interfaceId);
  }

  function isERC20(address contractAddress) external view returns (bool) {
    return _isERC20(contractAddress);
  }

  function requireERC20(address contractAddress) external view {
    _requireERC20(contractAddress);
  }

}
