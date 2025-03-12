// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "./Authorized.sol";

contract AttributeMap is Authorized {
  mapping(address => uint) internal _attributeMap;

  // ------------- Public Views -------------
  function isExemptFeeSender(address target) public view returns (bool) {
    return checkMapAttribute(_attributeMap[target], 0);
  }

  function isExemptFeeReceiver(address target) public view returns (bool) {
    return checkMapAttribute(_attributeMap[target], 1);
  }

  function isExemptSwapperMaker(address target) public view returns (bool) {
    return checkMapAttribute(_attributeMap[target], 2);
  }

  function isExemptReflect(address target) public view returns (bool) {
    return checkMapAttribute(_attributeMap[target], 3);
  }

  function isSpecialFeeWalletSender(address target) public view returns (bool) {
    return checkMapAttribute(_attributeMap[target], 4);
  }

  function isSpecialFeeWalletReceiver(address target) public view returns (bool) {
    return checkMapAttribute(_attributeMap[target], 5);
  }

  // ------------- Internal PURE GET Functions -------------
  function checkMapAttribute(uint mapValue, uint8 shift) internal pure returns (bool) {
    return (mapValue >> shift) & 1 == 1;
  }

  function isExemptFeeSender(uint mapValue) internal pure returns (bool) {
    return checkMapAttribute(mapValue, 0);
  }

  function isExemptFeeReceiver(uint mapValue) internal pure returns (bool) {
    return checkMapAttribute(mapValue, 1);
  }

  function isExemptSwapperMaker(uint mapValue) internal pure returns (bool) {
    return checkMapAttribute(mapValue, 2);
  }

  function isExemptReflect(uint mapValue) internal pure returns (bool) {
    return checkMapAttribute(mapValue, 3);
  }

  function isSpecialFeeWalletSender(uint mapValue) internal pure returns (bool) {
    return checkMapAttribute(mapValue, 4);
  }

  function isSpecialFeeWalletReceiver(uint mapValue) internal pure returns (bool) {
    return checkMapAttribute(mapValue, 5);
  }

  // ------------- Internal PURE SET Functions -------------
  function setMapAttribute(uint mapValue, uint8 shift, bool include) internal pure returns (uint) {
    return include ? applyMapAttribute(mapValue, shift) : removeMapAttribute(mapValue, shift);
  }

  function applyMapAttribute(uint mapValue, uint8 shift) internal pure returns (uint) {
    return (1 << shift) | mapValue;
  }

  function removeMapAttribute(uint mapValue, uint8 shift) internal pure returns (uint) {
    return (1 << shift) ^ (type(uint).max & mapValue);
  }

  // ------------- Public Internal SET Functions -------------
  function setExemptFeeSender(uint mapValue, bool operation) internal pure returns (uint) {
    return setMapAttribute(mapValue, 0, operation);
  }

  function setExemptFeeReceiver(uint mapValue, bool operation) internal pure returns (uint) {
    return setMapAttribute(mapValue, 1, operation);
  }

  function setExemptSwapperMaker(uint mapValue, bool operation) internal pure returns (uint) {
    return setMapAttribute(mapValue, 2, operation);
  }

  function setExemptReflect(uint mapValue, bool operation) internal pure returns (uint) {
    return setMapAttribute(mapValue, 3, operation);
  }

  function setSpecialFeeWalletSender(uint mapValue, bool operation) internal pure returns (uint) {
    return setMapAttribute(mapValue, 4, operation);
  }

  function setSpecialFeeWalletReceiver(uint mapValue, bool operation) internal pure returns (uint) {
    return setMapAttribute(mapValue, 5, operation);
  }

  // ------------- Public Authorized SET Functions -------------
  function setExemptFeeSender(address target, bool operation) public isAuthorized(2) {
    _attributeMap[target] = setExemptFeeSender(_attributeMap[target], operation);
  }

  function setExemptFeeReceiver(address target, bool operation) public isAuthorized(2) {
    _attributeMap[target] = setExemptFeeReceiver(_attributeMap[target], operation);
  }

  function setExemptSwapperMaker(address target, bool operation) public isAuthorized(2) {
    _attributeMap[target] = setExemptSwapperMaker(_attributeMap[target], operation);
  }

  function setExemptReflect(address target, bool operation) public isAuthorized(2) {
    _attributeMap[target] = setExemptReflect(_attributeMap[target], operation);
  }

  function setSpecialFeeWalletSender(address target, bool operation) public isAuthorized(2) {
    _attributeMap[target] = setSpecialFeeWalletSender(_attributeMap[target], operation);
  }

  function setSpecialFeeWalletReceiver(address target, bool operation) public isAuthorized(2) {
    _attributeMap[target] = setSpecialFeeWalletReceiver(_attributeMap[target], operation);
  }
}
