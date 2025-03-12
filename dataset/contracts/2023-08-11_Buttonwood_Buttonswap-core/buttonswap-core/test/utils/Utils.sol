// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

library Utils {
    function isValidPrivateKey(uint256 privateKey) internal pure returns (bool) {
        // See https://cryptobook.nakov.com/digital-signatures/ecdsa-sign-verify-messages
        if (privateKey == 0) {
            // The ECDSA docs say 0 is fine but it results in invalid private key errors so prevent it anyway
            return false;
        }
        if (privateKey >= 115792089237316195423570985008687907852837564279074904382605163141518161494337) {
            return false;
        }
        return true;
    }

    function getDelta(uint256 a, uint256 b) public pure returns (uint256) {
        if (a > b) {
            return a - b;
        }
        return b - a;
    }

    function getDelta224(uint224 a, uint224 b) public pure returns (uint224) {
        if (a > b) {
            return a - b;
        }
        return b - a;
    }

    function getDelta112(uint112 a, uint112 b) public pure returns (uint112) {
        if (a > b) {
            return a - b;
        }
        return b - a;
    }
}
