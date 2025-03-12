// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

// contracts
import {Test} from "../../lib/forge-std/src/Test.sol";

// libraries
import {PRBMathUD60x18} from "../../lib/prb-math/contracts/PRBMathUD60x18.sol";
import {PRBMathSD59x18} from "../../lib/prb-math/contracts/PRBMathSD59x18.sol";
import "../../lib/prb-math/contracts/PRBMath.sol";
import {SafeCast} from "../../lib/openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import {Math} from "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {SignedMath} from "../../lib/openzeppelin-contracts/contracts/utils/math/SignedMath.sol";
import {LibMath} from "../../contracts/lib/LibMath.sol";

contract LibMathExternalHarness {
    function toUint256(int256 x) external pure returns (uint256) {
        return LibMath.toUint256(x);
    }

    function toInt256(uint256 x) external pure returns (int256) {
        return LibMath.toInt256(x);
    }

    function toUint128(uint256 x) external pure returns (uint128) {
        return LibMath.toUint128(x);
    }

    function toInt128(int256 x) external pure returns (int128) {
        return LibMath.toInt128(x);
    }

    function toUint64(uint256 x) external pure returns (uint64) {
        return LibMath.toUint64(x);
    }

    function abs(int256 x) external pure returns (int256) {
        return LibMath.abs(x);
    }

    function min(int256 x, int256 y) external pure returns (int256) {
        return LibMath.min(x, y);
    }

    function min(uint256 x, uint256 y) external pure returns (uint256) {
        return LibMath.min(x, y);
    }

    function wadDiv(int256 x, int256 y) external pure returns (int256) {
        return LibMath.wadDiv(x, y);
    }

    function wadMul(int256 x, int256 y) external pure returns (int256) {
        return LibMath.wadMul(x, y);
    }

    function wadDiv(uint256 x, uint256 y) external pure returns (uint256) {
        return LibMath.wadDiv(x, y);
    }

    function wadMul(uint256 x, uint256 y) external pure returns (uint256) {
        return LibMath.wadMul(x, y);
    }
}

contract LibMathTest is Test {
    int256 internal constant MAX_SD59x18 =
        57896044618658097711785492504343953926634992332820282019728_792003956564819967;
    int256 internal constant MIN_SD59x18 =
        -57896044618658097711785492504343953926634992332820282019728_792003956564819968;

    LibMathExternalHarness public libMath;

    function setUp() public virtual {
        libMath = new LibMathExternalHarness();
    }

    function testFuzz_toUint256(int256 x) public {
        try libMath.toUint256(x) returns (uint256 res) {
            assertEq(res, SafeCast.toUint256(x));
        } catch {
            vm.expectRevert();
            SafeCast.toUint256(x);
        }
    }

    function testFuzz_toInt256(uint256 x) public {
        try libMath.toInt256(x) returns (int256 res) {
            assertEq(res, SafeCast.toInt256(x));
        } catch {
            vm.expectRevert();
            SafeCast.toInt256(x);
        }
    }

    function testFuzz_toUint128(uint256 x) public {
        try libMath.toUint128(x) returns (uint128 res) {
            assertEq(res, SafeCast.toUint128(x));
        } catch {
            vm.expectRevert();
            SafeCast.toUint128(x);
        }
    }

    function testFuzz_toInt128(int256 x) public {
        try libMath.toInt128(x) returns (int128 res) {
            assertEq(res, SafeCast.toInt128(x));
        } catch {
            vm.expectRevert();
            SafeCast.toInt128(x);
        }
    }

    function testFuzz_toUint64(uint256 x) public {
        try libMath.toUint64(x) returns (uint64 res) {
            assertEq(res, SafeCast.toUint64(x));
        } catch {
            vm.expectRevert();
            SafeCast.toUint64(x);
        }
    }

    function testFuzz_abs(int256 x) public {
        try libMath.abs(x) returns (int256 res) {
            assertEq(res, PRBMathSD59x18.abs(x));
        } catch (bytes memory reason) {
            vm.expectRevert(reason);
            PRBMathSD59x18.abs(x);
        }
    }

    function testFuzz_min(int256 x, int256 y) public {
        assertEq(libMath.min(x, y), SignedMath.min(x, y));
    }

    function testFuzz_min(uint256 x, uint256 y) public {
        assertEq(libMath.min(x, y), Math.min(x, y));
    }

    function testFuzz_wadDiv(int256 x, int256 y) public {
        try libMath.wadDiv(x, y) returns (int256 res) {
            assertEq(res, PRBMathSD59x18.div(x, y));
        } catch (bytes memory reason) {
            vm.expectRevert(reason);
            PRBMathSD59x18.div(x, y);
        }
    }

    function testFuzz_wadMul(int256 x, int256 y) public {
        try libMath.wadMul(x, y) returns (int256 res) {
            assertEq(res, PRBMathSD59x18.mul(x, y));
        } catch (bytes memory reason) {
            vm.expectRevert(reason);
            PRBMathSD59x18.mul(x, y);
        }
    }

    function testFuzz_wadDiv(uint256 x, uint256 y) public {
        try libMath.wadDiv(x, y) returns (uint256 res) {
            assertEq(res, PRBMathUD60x18.div(x, y));
        } catch (bytes memory reason) {
            vm.expectRevert(reason);
            PRBMathUD60x18.div(x, y);
        }
    }

    function testFuzz_wadMul(uint256 x, uint256 y) public {
        try libMath.wadMul(x, y) returns (uint256 res) {
            assertEq(res, PRBMathUD60x18.mul(x, y));
        } catch (bytes memory reason) {
            vm.expectRevert(reason);
            PRBMathUD60x18.mul(x, y);
        }
    }
}
