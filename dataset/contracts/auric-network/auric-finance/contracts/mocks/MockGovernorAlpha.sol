pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "../governance/GovernorAlpha.sol";

contract MockGovernorAlpha is GovernorAlpha {

  constructor(address timelock_, address ausc_) public
  GovernorAlpha(timelock_, ausc_)
  {}

  function votingPeriod() public pure returns (uint256) { return 100; }
}
