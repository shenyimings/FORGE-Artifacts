pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

interface IFrensMetaHelper {

  //function getColor(address a) external pure returns(string memory);

  function getEthDecimalString(uint amountInWei) external pure returns(string memory);

  // function getOperatorsForPool(address poolAddress) external view returns (uint32[] memory, string memory);

  function getPoolString(uint id) external view returns (string memory);

  function getEns(address addr) external view returns(bool, string memory);

  function getDepositStringForId(uint id) external view returns(string memory);
}
