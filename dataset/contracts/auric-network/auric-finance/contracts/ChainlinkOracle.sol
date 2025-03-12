pragma solidity 0.5.16;

import "@chainlink/contracts/src/v0.5/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract ChainlinkOracle {

  using SafeMath for uint256;

  address public constant oracle = 0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6;
  uint256 public constant ozToMg = 311035000;
  uint256 public constant ozToMgPrecision = 1e4;

  constructor () public {
  }

  function getPriceXAU() public view returns (bool, uint256) {
    // answer has 8 decimals, it is the price of 1 oz of gold in USD
    // if the round is not completed, updated at is 0
    (,int256 answer,,uint256 updatedAt,) = AggregatorV3Interface(oracle).latestRoundData();
    // add 10 decimals at the end
    return (updatedAt != 0, uint256(answer).mul(10).mul(ozToMgPrecision).div(ozToMg).mul(1e10));
  }
}

