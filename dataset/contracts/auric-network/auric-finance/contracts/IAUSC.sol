pragma solidity 0.5.16;

interface IAUSC {
  function rebase(uint256 epoch, uint256 supplyDelta, bool positive) external;
  function mint(address to, uint256 amount) external;
}
