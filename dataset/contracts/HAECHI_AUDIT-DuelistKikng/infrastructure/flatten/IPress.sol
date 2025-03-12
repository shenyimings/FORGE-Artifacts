// Root file: contracts/interfaces/IPress.sol

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

interface IPress {
  function newNFT(
    bytes32 _domain,
    string calldata name,
    string calldata symbol
  ) external returns (address);

  function createItem(
    bytes32 _domain,
    address _owner,
    uint256 _itemId
  ) external returns (bool);
}
