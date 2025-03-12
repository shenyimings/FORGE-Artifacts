pragma solidity >=0.6.0;

interface IDUSD {
  function mint(address to, uint256 amount) external;
  function burn(uint256 amount) external;
}