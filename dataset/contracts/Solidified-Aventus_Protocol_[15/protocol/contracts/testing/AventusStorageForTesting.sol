pragma solidity 0.5.12;

contract AventusStorageForTesting {

  uint testValue;

  function setTestValue(uint value)
    external
  {
    testValue = value;
  }

  function getTestValue()
    external
    view
    returns (uint)
  {
    return testValue;
  }
}