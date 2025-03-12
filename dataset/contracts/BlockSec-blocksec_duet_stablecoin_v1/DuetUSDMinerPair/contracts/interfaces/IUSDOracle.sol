pragma solidity >=0.6.0;

interface IUSDOracle {
  function getPrice(address token) external view returns (uint256);
}
