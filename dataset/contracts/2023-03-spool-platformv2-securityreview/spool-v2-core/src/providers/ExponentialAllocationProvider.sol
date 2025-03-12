// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../interfaces/IAllocationProvider.sol";
import "../interfaces/IRiskManager.sol";
import "../interfaces/Constants.sol";

contract ExponentialAllocationProvider is IAllocationProvider {
    /*
    * Minimum value signed 64.64-bit fixed point number may have.
    */
    int256 private constant MIN_64x64 = -0x80000000000000000000000000000000;

    /*
    * Maximum value signed 64.64-bit fixed point number may have.
    */
    int256 private constant MAX_64x64 = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    function fromInt(int256 x) internal pure returns (int256) {
        unchecked {
            require(x >= -0x8000000000000000 && x <= 0x7FFFFFFFFFFFFFFF);
            return int256(x << 64);
        }
    }

    function toInt(int256 x) internal pure returns (int64) {
        unchecked {
            return int64(x >> 64);
        }
    }

    function log_2(int256 x) internal pure returns (int256) {
        unchecked {
            require(x > 0);

            int256 msb = 0;
            int256 xc = x;
            if (xc >= 0x10000000000000000) {
                xc >>= 64;
                msb += 64;
            }
            if (xc >= 0x100000000) {
                xc >>= 32;
                msb += 32;
            }
            if (xc >= 0x10000) {
                xc >>= 16;
                msb += 16;
            }
            if (xc >= 0x100) {
                xc >>= 8;
                msb += 8;
            }
            if (xc >= 0x10) {
                xc >>= 4;
                msb += 4;
            }
            if (xc >= 0x4) {
                xc >>= 2;
                msb += 2;
            }
            if (xc >= 0x2) msb += 1; // No need to shift xc anymore

            int256 result = msb - 64 << 64;
            uint256 ux = uint256(int256(x)) << uint256(127 - msb);
            for (int256 bit = 0x8000000000000000; bit > 0; bit >>= 1) {
                ux *= ux;
                uint256 b = ux >> 255;
                ux >>= 127 + b;
                result += bit * int256(b);
            }

            return int256(result);
        }
    }

    function exp_2(int256 x) internal pure returns (int256) {
        unchecked {
            require(x < 0x400000000000000000); // Overflow

            if (x < -0x400000000000000000) return 0; // Underflow

            uint256 result = 0x80000000000000000000000000000000;

            if (x & 0x8000000000000000 > 0) {
                result = result * 0x16A09E667F3BCC908B2FB1366EA957D3E >> 128;
            }
            if (x & 0x4000000000000000 > 0) {
                result = result * 0x1306FE0A31B7152DE8D5A46305C85EDEC >> 128;
            }
            if (x & 0x2000000000000000 > 0) {
                result = result * 0x1172B83C7D517ADCDF7C8C50EB14A791F >> 128;
            }
            if (x & 0x1000000000000000 > 0) {
                result = result * 0x10B5586CF9890F6298B92B71842A98363 >> 128;
            }
            if (x & 0x800000000000000 > 0) {
                result = result * 0x1059B0D31585743AE7C548EB68CA417FD >> 128;
            }
            if (x & 0x400000000000000 > 0) {
                result = result * 0x102C9A3E778060EE6F7CACA4F7A29BDE8 >> 128;
            }
            if (x & 0x200000000000000 > 0) {
                result = result * 0x10163DA9FB33356D84A66AE336DCDFA3F >> 128;
            }
            if (x & 0x100000000000000 > 0) {
                result = result * 0x100B1AFA5ABCBED6129AB13EC11DC9543 >> 128;
            }
            if (x & 0x80000000000000 > 0) {
                result = result * 0x10058C86DA1C09EA1FF19D294CF2F679B >> 128;
            }
            if (x & 0x40000000000000 > 0) {
                result = result * 0x1002C605E2E8CEC506D21BFC89A23A00F >> 128;
            }
            if (x & 0x20000000000000 > 0) {
                result = result * 0x100162F3904051FA128BCA9C55C31E5DF >> 128;
            }
            if (x & 0x10000000000000 > 0) {
                result = result * 0x1000B175EFFDC76BA38E31671CA939725 >> 128;
            }
            if (x & 0x8000000000000 > 0) {
                result = result * 0x100058BA01FB9F96D6CACD4B180917C3D >> 128;
            }
            if (x & 0x4000000000000 > 0) {
                result = result * 0x10002C5CC37DA9491D0985C348C68E7B3 >> 128;
            }
            if (x & 0x2000000000000 > 0) {
                result = result * 0x1000162E525EE054754457D5995292026 >> 128;
            }
            if (x & 0x1000000000000 > 0) {
                result = result * 0x10000B17255775C040618BF4A4ADE83FC >> 128;
            }
            if (x & 0x800000000000 > 0) {
                result = result * 0x1000058B91B5BC9AE2EED81E9B7D4CFAB >> 128;
            }
            if (x & 0x400000000000 > 0) {
                result = result * 0x100002C5C89D5EC6CA4D7C8ACC017B7C9 >> 128;
            }
            if (x & 0x200000000000 > 0) {
                result = result * 0x10000162E43F4F831060E02D839A9D16D >> 128;
            }
            if (x & 0x100000000000 > 0) {
                result = result * 0x100000B1721BCFC99D9F890EA06911763 >> 128;
            }
            if (x & 0x80000000000 > 0) {
                result = result * 0x10000058B90CF1E6D97F9CA14DBCC1628 >> 128;
            }
            if (x & 0x40000000000 > 0) {
                result = result * 0x1000002C5C863B73F016468F6BAC5CA2B >> 128;
            }
            if (x & 0x20000000000 > 0) {
                result = result * 0x100000162E430E5A18F6119E3C02282A5 >> 128;
            }
            if (x & 0x10000000000 > 0) {
                result = result * 0x1000000B1721835514B86E6D96EFD1BFE >> 128;
            }
            if (x & 0x8000000000 > 0) {
                result = result * 0x100000058B90C0B48C6BE5DF846C5B2EF >> 128;
            }
            if (x & 0x4000000000 > 0) {
                result = result * 0x10000002C5C8601CC6B9E94213C72737A >> 128;
            }
            if (x & 0x2000000000 > 0) {
                result = result * 0x1000000162E42FFF037DF38AA2B219F06 >> 128;
            }
            if (x & 0x1000000000 > 0) {
                result = result * 0x10000000B17217FBA9C739AA5819F44F9 >> 128;
            }
            if (x & 0x800000000 > 0) {
                result = result * 0x1000000058B90BFCDEE5ACD3C1CEDC823 >> 128;
            }
            if (x & 0x400000000 > 0) {
                result = result * 0x100000002C5C85FE31F35A6A30DA1BE50 >> 128;
            }
            if (x & 0x200000000 > 0) {
                result = result * 0x10000000162E42FF0999CE3541B9FFFCF >> 128;
            }
            if (x & 0x100000000 > 0) {
                result = result * 0x100000000B17217F80F4EF5AADDA45554 >> 128;
            }
            if (x & 0x80000000 > 0) {
                result = result * 0x10000000058B90BFBF8479BD5A81B51AD >> 128;
            }
            if (x & 0x40000000 > 0) {
                result = result * 0x1000000002C5C85FDF84BD62AE30A74CC >> 128;
            }
            if (x & 0x20000000 > 0) {
                result = result * 0x100000000162E42FEFB2FED257559BDAA >> 128;
            }
            if (x & 0x10000000 > 0) {
                result = result * 0x1000000000B17217F7D5A7716BBA4A9AE >> 128;
            }
            if (x & 0x8000000 > 0) {
                result = result * 0x100000000058B90BFBE9DDBAC5E109CCE >> 128;
            }
            if (x & 0x4000000 > 0) {
                result = result * 0x10000000002C5C85FDF4B15DE6F17EB0D >> 128;
            }
            if (x & 0x2000000 > 0) {
                result = result * 0x1000000000162E42FEFA494F1478FDE05 >> 128;
            }
            if (x & 0x1000000 > 0) {
                result = result * 0x10000000000B17217F7D20CF927C8E94C >> 128;
            }
            if (x & 0x800000 > 0) {
                result = result * 0x1000000000058B90BFBE8F71CB4E4B33D >> 128;
            }
            if (x & 0x400000 > 0) {
                result = result * 0x100000000002C5C85FDF477B662B26945 >> 128;
            }
            if (x & 0x200000 > 0) {
                result = result * 0x10000000000162E42FEFA3AE53369388C >> 128;
            }
            if (x & 0x100000 > 0) {
                result = result * 0x100000000000B17217F7D1D351A389D40 >> 128;
            }
            if (x & 0x80000 > 0) {
                result = result * 0x10000000000058B90BFBE8E8B2D3D4EDE >> 128;
            }
            if (x & 0x40000 > 0) {
                result = result * 0x1000000000002C5C85FDF4741BEA6E77E >> 128;
            }
            if (x & 0x20000 > 0) {
                result = result * 0x100000000000162E42FEFA39FE95583C2 >> 128;
            }
            if (x & 0x10000 > 0) {
                result = result * 0x1000000000000B17217F7D1CFB72B45E1 >> 128;
            }
            if (x & 0x8000 > 0) {
                result = result * 0x100000000000058B90BFBE8E7CC35C3F0 >> 128;
            }
            if (x & 0x4000 > 0) {
                result = result * 0x10000000000002C5C85FDF473E242EA38 >> 128;
            }
            if (x & 0x2000 > 0) {
                result = result * 0x1000000000000162E42FEFA39F02B772C >> 128;
            }
            if (x & 0x1000 > 0) {
                result = result * 0x10000000000000B17217F7D1CF7D83C1A >> 128;
            }
            if (x & 0x800 > 0) {
                result = result * 0x1000000000000058B90BFBE8E7BDCBE2E >> 128;
            }
            if (x & 0x400 > 0) {
                result = result * 0x100000000000002C5C85FDF473DEA871F >> 128;
            }
            if (x & 0x200 > 0) {
                result = result * 0x10000000000000162E42FEFA39EF44D91 >> 128;
            }
            if (x & 0x100 > 0) {
                result = result * 0x100000000000000B17217F7D1CF79E949 >> 128;
            }
            if (x & 0x80 > 0) {
                result = result * 0x10000000000000058B90BFBE8E7BCE544 >> 128;
            }
            if (x & 0x40 > 0) {
                result = result * 0x1000000000000002C5C85FDF473DE6ECA >> 128;
            }
            if (x & 0x20 > 0) {
                result = result * 0x100000000000000162E42FEFA39EF366F >> 128;
            }
            if (x & 0x10 > 0) {
                result = result * 0x1000000000000000B17217F7D1CF79AFA >> 128;
            }
            if (x & 0x8 > 0) {
                result = result * 0x100000000000000058B90BFBE8E7BCD6D >> 128;
            }
            if (x & 0x4 > 0) {
                result = result * 0x10000000000000002C5C85FDF473DE6B2 >> 128;
            }
            if (x & 0x2 > 0) {
                result = result * 0x1000000000000000162E42FEFA39EF358 >> 128;
            }
            if (x & 0x1 > 0) {
                result = result * 0x10000000000000000B17217F7D1CF79AB >> 128;
            }

            result >>= uint256(int256(63 - (x >> 64)));
            require(result <= uint256(int256(MAX_64x64)));

            return int256(int256(result));
        }
    }

    function div(int256 x, int256 y) internal pure returns (int256) {
        unchecked {
            require(y != 0);
            int256 result = (int256(x) << 64) / y;
            require(result >= MIN_64x64 && result <= MAX_64x64);
            return int256(result);
        }
    }

    function fromUint(uint256 x) internal pure returns (int256) {
        unchecked {
            require(x <= 0x7FFFFFFFFFFFFFFF);
            return int256(int256(x << 64));
        }
    }

    function mul(int256 x, int256 y) internal pure returns (int256) {
        unchecked {
            int256 result = int256(x) * y >> 64;
            require(result >= MIN_64x64 && result <= MAX_64x64);
            return int256(result);
        }
    }

    function calculateAllocation(AllocationCalculationInput calldata data) external pure returns (uint256[] memory) {
        if (data.apys.length != data.riskScores.length) {
            revert ApysOrRiskScoresLengthMismatch(data.apys.length, data.riskScores.length);
        }

        uint256 resultSum = 0;

        uint256[] memory results = new uint256[](data.apys.length);

        uint8[21] memory riskArray =
            [190, 181, 172, 163, 154, 145, 136, 127, 118, 109, 100, 91, 82, 73, 64, 55, 46, 37, 28, 19, 10];

        uint8 riskt = uint8(data.riskTolerance + 10); // from 0 - 20
        int256 _100 = fromInt(100);
        for (uint8 i; i < data.apys.length; ++i) {
            uint256 uintApy = (data.apys[i] > 0 ? uint256(data.apys[i]) : 0);
            int256 partRiskTolerance = fromUint(uint256(riskArray[uint8(20 - riskt)]));

            partRiskTolerance = div(partRiskTolerance, _100);
            int256 partApy = fromUint(uintApy);
            partApy = div(partApy, _100);

            int256 apy = exp_2(mul(partRiskTolerance, log_2(partApy)));

            apy = exp_2(apy);

            int256 risk = fromUint(data.riskScores[i]);

            results[i] = uint256(div(apy, risk));

            resultSum += results[i];
        }

        uint256 residual = FULL_PERCENT;
        for (uint8 i; i < results.length; ++i) {
            results[i] = FULL_PERCENT * results[i] / resultSum;
            residual -= results[i];
        }

        results[0] += residual;

        return results;
    }
}
