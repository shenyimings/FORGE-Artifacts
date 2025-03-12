pragma solidity 0.4.25;

import '../DateLib.sol';

contract DateLibMock {
    using DateLib for uint256;

    function getHoursInMonth(uint256 a) public pure returns (uint256) {
        return a.getHoursInMonth();
    }
}
