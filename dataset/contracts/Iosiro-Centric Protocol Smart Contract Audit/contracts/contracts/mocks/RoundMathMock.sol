pragma solidity 0.4.25;

import '../RoundMath.sol';

contract RoundMathContract {
    using RoundMath for uint256;

    function roundDiv(uint256 a, uint256 b) public pure returns (uint256) {
        return a.roundDiv(b);
    }

    function ceilDiv(uint256 a, uint256 b) public pure returns (uint256) {
        return a.ceilDiv(b);
    }
}
