// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/Strings.sol";

library StringConverter {
    using Strings for uint256;
    using Strings for address;

    function toString(uint256 value) internal pure returns (string memory) {
        return value.toString();
    }

    function toString(address addr) internal pure returns (string memory) {
        return addr.toHexString();
    }

    function uint2decimal(
        uint256 self,
        uint8 decimals
    ) internal pure returns (bytes memory) {
        uint256 base = 10 ** decimals;
        string memory round = uint256(self / base).toString();
        string memory fraction = uint256(self % base).toString();
        uint256 fractionLength = bytes(fraction).length;

        bytes memory fullStr = abi.encodePacked(round, ".");
        if (fractionLength < decimals) {
            for (uint8 i = 0; i < decimals - fractionLength; i++) {
                fullStr = abi.encodePacked(fullStr, "0");
            }
        }

        return abi.encodePacked(fullStr, fraction);
    }

    function trim(
        bytes memory self,
        uint256 cutLength
    ) internal pure returns (bytes memory newString) {
        newString = new bytes(self.length - cutLength);
        uint256 nlength = newString.length;
        for (uint i = 0; i < nlength; ) {
            newString[i] = self[i];
            unchecked {
                ++i;
            }
        }
    }

    function addThousandsSeparator(
        bytes memory self
    ) internal pure returns (bytes memory newString) {
        if (self.length <= 6) {
            return self;
        }
        newString = new bytes(self.length + (self.length - 4) / 3);
        uint256 oriIndex = self.length - 1;
        uint256 newIndex = newString.length - 1;
        for (uint256 i = 0; i < newString.length; ) {
            unchecked {
                newString[newIndex] = self[oriIndex];
                if (i >= 5 && i % 4 == 1 && newString.length - i > 1) {
                    newIndex--;
                    newString[newIndex] = 0x2c;
                    i++;
                }
                i++;
                newIndex--;
                oriIndex--;
            }
        }
    }
}
