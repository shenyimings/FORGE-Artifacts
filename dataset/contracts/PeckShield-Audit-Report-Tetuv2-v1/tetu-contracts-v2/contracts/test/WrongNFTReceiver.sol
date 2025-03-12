// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

contract WrongNFTReceiver {

  function onERC721Received(
    address,
    address,
    uint256,
    bytes calldata
  ) external pure returns (bytes4) {
    revert("stub revert");
  }

}
