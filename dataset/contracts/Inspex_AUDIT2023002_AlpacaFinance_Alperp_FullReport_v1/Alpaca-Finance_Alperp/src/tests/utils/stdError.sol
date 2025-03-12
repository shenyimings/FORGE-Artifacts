// SPDX-License-Identifier: MIT
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/

pragma solidity 0.8.17;

library stdError {
  bytes public constant assertionError =
    abi.encodeWithSignature("Panic(uint256)", 0x01);
  bytes public constant arithmeticError =
    abi.encodeWithSignature("Panic(uint256)", 0x11);
  bytes public constant divisionError =
    abi.encodeWithSignature("Panic(uint256)", 0x12);
  bytes public constant enumConversionError =
    abi.encodeWithSignature("Panic(uint256)", 0x21);
  bytes public constant encodeStorageError =
    abi.encodeWithSignature("Panic(uint256)", 0x22);
  bytes public constant popError =
    abi.encodeWithSignature("Panic(uint256)", 0x31);
  bytes public constant indexOOBError =
    abi.encodeWithSignature("Panic(uint256)", 0x32);
  bytes public constant memOverflowError =
    abi.encodeWithSignature("Panic(uint256)", 0x41);
  bytes public constant zeroVarError =
    abi.encodeWithSignature("Panic(uint256)", 0x51);
  // DEPRECATED: Use Vm's `expectRevert` without any arguments instead
  bytes public constant lowLevelError = bytes(""); // `0x`
}
