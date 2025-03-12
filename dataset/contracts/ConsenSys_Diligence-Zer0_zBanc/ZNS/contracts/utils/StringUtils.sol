// SPDX-License-Identifier: MIT
// Source:
// https://github.com/ensdomains/ens-contracts/blob/master/contracts/ethregistrar/StringUtils.sol
pragma solidity 0.8.18;


library StringUtils {
    /**
     * @dev Returns the length of a given string
     *
     * @param s The string to measure the length of
     * @return The length of the input string
     */
    function strlen(string memory s) internal pure returns (uint256) {
        uint256 len;
        uint256 i = 0;
        uint256 byteLength = bytes(s).length;
        for (len = 0; i < byteLength; len++) {
            bytes1 b = bytes(s)[i];
            if (b < 0x80) {
                i += 1;
            } else if (b < 0xE0) {
                i += 2;
            } else if (b < 0xF0) {
                i += 3;
            } else if (b < 0xF8) {
                i += 4;
            } else if (b < 0xFC) {
                i += 5;
            } else {
                i += 6;
            }
        }
        return len;
    }

    /**
     * @dev Confirm that a given string has only alphanumeric characters [a-z0-9-]
     * @param s The string to validate
     */
    function validate(string memory s) internal pure {
        bytes memory nameBytes = bytes(s);
        uint256 length = nameBytes.length;

        // solhint-disable-next-line var-name-mixedcase
        uint256 MAX_INT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        require(
            length > 0 && length < MAX_INT,
            "StringUtils: Domain label too long or nonexistent"
        );

        for (uint256 i; i < length;) {
            bytes1 b = nameBytes[i];
            // Valid strings are lower case a-z, 0-9, or a hyphen
            require(
                (b > 0x60 && b < 0x7B) || (b > 0x2F && b < 0x3A) || b == 0x2D,
                "StringUtils: Invalid domain label"
            );
            unchecked {
                ++i;
            }
        }
    }
}