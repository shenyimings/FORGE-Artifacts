pragma solidity 0.6.12;

interface AToken {
  function getIncentivesController() external view returns (address);
  function redeem(uint256 amount) external;
  function name() external view returns(string memory);
  function burn(address user, address receiverOfUnderlying, uint256 amount, uint256 index) external;
}
