// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

contract AaveControllerMock {
  uint256 public speeds;
  function setSpeeds(uint256 speed) public {
    speeds = speed;
  }

  function getAssetData(address) external view returns (uint256,uint256,uint256) {
    return (0, speeds, 0);
  }
}
