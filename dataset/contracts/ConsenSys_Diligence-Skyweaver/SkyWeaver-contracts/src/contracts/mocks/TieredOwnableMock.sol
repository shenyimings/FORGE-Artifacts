pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;


import "../utils/TieredOwnable.sol";

contract TieredOwnableMock is TieredOwnable {

  constructor(address _firstOwner) TieredOwnable(_firstOwner) public {}

  function onlyMaxTier() external onlyOwnerTier(HIGHEST_OWNER_TIER) returns(bool) {
    return true;
  }

  function onlyTierFive() external onlyOwnerTier(5) returns(bool) {
    return true;
  }

  function onlyTierZero() external onlyOwnerTier(0) returns(bool) {
    return true;
  }

  function anyone() external returns(bool) {
    return true;
  }
}