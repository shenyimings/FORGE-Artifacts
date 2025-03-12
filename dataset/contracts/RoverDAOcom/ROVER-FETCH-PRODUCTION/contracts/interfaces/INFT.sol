interface INFT {
  function isIndexUsed(uint256) external view returns(bool);
  function createNewFor(address, uint256) external;
}
