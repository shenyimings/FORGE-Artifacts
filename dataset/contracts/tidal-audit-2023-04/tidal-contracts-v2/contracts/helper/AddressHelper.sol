// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IPool {
    function admin() external view returns(address);
    function committeeIndexPlusOne(address who_) external view returns(uint256);
}

contract AddressHelper is Ownable {

  address[] public poolArray;

  function setPoolArray(address[] calldata poolArray_) external onlyOwner {
      delete poolArray;
      for (uint256 i = 0; i < poolArray_.length; ++i) {
          poolArray.push(poolArray_[i]);
      }
  }

  function getAddressInfo(
      address who_
  ) external view returns(address pool_, uint256 role_) {
      for (uint256 i = 0; i < poolArray.length; ++i) {
          IPool pool = IPool(poolArray[i]);
          if (pool.admin() == who_) {
              return (poolArray[i], 0);
          } else {
              uint256 indexPlusOne = pool.committeeIndexPlusOne(who_);
              if (indexPlusOne > 0) {
                  return (poolArray[i], indexPlusOne);
              }
          }
      }

      return (address(0), 0);
  }
}
