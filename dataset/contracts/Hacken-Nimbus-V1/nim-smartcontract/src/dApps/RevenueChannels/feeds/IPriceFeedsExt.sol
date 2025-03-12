pragma solidity 0.5.17;


interface IPriceFeedsExt {
  function latestAnswer() external view returns (int256);
}
