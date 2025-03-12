// SPDX-License-Identifier: MIT
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/
pragma solidity 0.8.17;

import "src/interfaces/ChainLinkPriceFeedInterface.sol";

/// @title MockChainlinkPriceFeed - for testing purposes ONLY.
contract MockChainlinkPriceFeed is ChainlinkPriceFeedInterface {
  int256 public answer;
  uint80 public roundId;

  uint8 public decimals;

  address public gov;

  mapping(uint80 => int256) public answers;
  mapping(address => bool) public isAdmin;

  constructor() {
    gov = msg.sender;
    isAdmin[msg.sender] = true;
  }

  function setAdmin(address _account, bool _isAdmin) external {
    require(msg.sender == gov, "PriceFeed: forbidden");
    isAdmin[_account] = _isAdmin;
  }

  function setLatestAnswer(int256 _answer) external {
    require(isAdmin[msg.sender], "PriceFeed: forbidden");
    roundId = roundId + 1;
    answer = _answer;
    answers[roundId] = _answer;
  }

  function getRoundData(uint80 _roundId)
    external
    view
    override
    returns (
      uint80,
      int256,
      uint256,
      uint256,
      uint80
    )
  {
    return (_roundId, answers[_roundId], 0, 0, 0);
  }

  function latestRoundData()
    external
    view
    override
    returns (
      uint80,
      int256,
      uint256,
      uint256,
      uint80
    )
  {
    return (roundId, answers[roundId], 0, 0, 0);
  }
}
