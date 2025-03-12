// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../libraries/SquareRoot.sol";

contract TestingSquareRoot {
    function sqrt(uint256 input, SquareRoot.Precision precision) external pure returns (uint256) {
        return SquareRoot.sqrt(input, 10 ** 18, precision);
    }
}
