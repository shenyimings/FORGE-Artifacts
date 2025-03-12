pragma solidity 0.5.16;

import "../BasicRebaser.sol";
import "./MockOracle.sol";

contract MockRebaser is BasicRebaser, MockOracle {

  constructor (address token, address _treasury) BasicRebaser(token, _treasury) public {
  }

}
