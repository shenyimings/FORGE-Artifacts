pragma solidity >=0.8.4 <0.9.0;

library math {
  function ceil(uint256 a, uint256 m) internal pure returns (uint256) {
    if (a == 0) return 0;
    return ((a + m - 1) / m) * m;
  }

  function almostEqual(
    uint256 value0,
    uint256 value1,
    uint256 toleranceBps
  ) internal pure returns (bool) {
    uint256 maxValue = max(value0, value1);
    return
      ((maxValue - min(value0, value1)) * 10000) <= toleranceBps * maxValue;
  }

  function max(uint256 a, uint256 b) internal pure returns (uint256) {
    return a >= b ? a : b;
  }

  function min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }
}
