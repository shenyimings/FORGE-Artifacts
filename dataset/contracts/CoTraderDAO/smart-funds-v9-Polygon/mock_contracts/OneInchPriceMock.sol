pragma solidity ^0.6.12;

contract OneInchPriceMock {
  function getRate(address srcToken, address dstToken) external view returns (uint256 weightedRate){
    weightedRate = 1;
  }
}
