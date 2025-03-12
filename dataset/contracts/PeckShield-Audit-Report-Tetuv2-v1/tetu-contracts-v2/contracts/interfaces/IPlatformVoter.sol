// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IPlatformVoter {

  enum AttributeType {
    UNKNOWN,
    INVEST_FUND_RATIO,
    GAUGE_RATIO,
    STRATEGY_COMPOUND
  }

  struct Vote {
    AttributeType _type;
    address target;
    uint weight;
    uint weightedValue;
    uint timestamp;
  }

  function detachTokenFromAll(uint tokenId, address owner) external;

}
