interface IYearnToken {
  function token() external view returns(address);
  function deposit(uint _amount) external;
  function withdraw(uint _shares) external;
  function getPricePerFullShare() external view returns (uint);
}
