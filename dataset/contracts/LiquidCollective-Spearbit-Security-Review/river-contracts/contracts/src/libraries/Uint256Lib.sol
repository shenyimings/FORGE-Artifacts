//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

library Uint256Lib {
    function toLittleEndian64(uint256 _value) internal pure returns (uint256 result) {
        result = 0;
        uint256 temp_value = _value;
        for (uint256 i = 0; i < 8;) {
            result = (result << 8) | (temp_value & 0xFF);
            temp_value >>= 8;
            unchecked {
                ++i;
            }
        }

        assert(0 == temp_value); // fully converted
        result <<= (24 * 8);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256 max) {
        return (a > b ? b : a);
    }
}
