pragma solidity 0.5.16;

import "./BasicRebaser.sol";
import "./ChainlinkOracle.sol";
import "./UniswapOracle.sol";

contract Rebaser is BasicRebaser, UniswapOracle, ChainlinkOracle {

  constructor (address token, address _treasury)
  BasicRebaser(token, _treasury)
  UniswapOracle(token) public {
  }

}
