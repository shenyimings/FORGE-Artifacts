interface IOneInchPrice {
  function getRate(address srcToken, address dstToken) external view returns (uint256 weightedRate);
}
