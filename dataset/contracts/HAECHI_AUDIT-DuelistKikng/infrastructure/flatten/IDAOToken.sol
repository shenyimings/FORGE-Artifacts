// Root file: contracts/interfaces/IDAOToken.sol

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

interface IDAOToken {
  function init(
    string memory name,
    string memory symbol,
    address genesis,
    uint256 supply
  ) external returns (bool);

  function totalSupply() external view returns (uint256);

  function calculatePower(address owner) external view returns (uint256);
}
