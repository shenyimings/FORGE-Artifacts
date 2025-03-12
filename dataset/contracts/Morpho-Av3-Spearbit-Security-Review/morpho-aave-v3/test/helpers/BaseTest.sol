// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Types} from "src/libraries/Types.sol";
import {Events} from "src/libraries/Events.sol";
import {Errors} from "src/libraries/Errors.sol";
import {Constants} from "src/libraries/Constants.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {Math} from "@morpho-utils/math/Math.sol";
import {WadRayMath} from "@morpho-utils/math/WadRayMath.sol";
import {PercentageMath} from "@morpho-utils/math/PercentageMath.sol";

import {stdStorage, StdStorage} from "@forge-std/StdStorage.sol";
import {console2} from "@forge-std/console2.sol";
import {console} from "@forge-std/console.sol";
import {Test} from "@forge-std/Test.sol";

contract BaseTest is Test {
    uint256 internal constant BLOCK_TIME = 12;
    uint256 internal constant DEFAULT_MAX_ITERATIONS = 10;

    /// @dev Asserts a is approximately equal to b, with a maximum absolute difference of DUST_THRESHOLD.
    function assertApproxEqDust(uint256 a, uint256 b, string memory err) internal {
        assertApproxEqAbs(a, b, Constants.DUST_THRESHOLD, err);
    }

    /// @dev Asserts a is approximately less than or equal to b, with a maximum absolute difference of maxDelta.
    function assertApproxLeAbs(uint256 a, uint256 b, uint256 maxDelta, string memory err) internal {
        assertLe(a, b, err);
        assertApproxEqAbs(a, b, maxDelta, err);
    }

    /// @dev Asserts a is approximately greater than or equal to b, with a maximum absolute difference of maxDelta.
    function assertApproxGeAbs(uint256 a, uint256 b, uint256 maxDelta, string memory err) internal {
        assertGe(a, b, err);
        assertApproxEqAbs(a, b, maxDelta, err);
    }

    /// @dev Rolls & warps the given number of blocks forward the blockchain.
    function _forward(uint256 blocks) internal {
        vm.roll(block.number + blocks);
        vm.warp(block.timestamp + blocks * BLOCK_TIME); // Block speed should depend on test network.
    }

    /// @dev Bounds the fuzzing input to a realistic number of blocks.
    function _boundBlocks(uint256 blocks) internal view returns (uint256) {
        return bound(blocks, 1, type(uint32).max / 4);
    }

    /// @dev Bounds the fuzzing input to a non-zero address.
    function _boundAddressNotZero(address onBehalf) internal view returns (address) {
        return address(uint160(bound(uint256(uint160(onBehalf)), 1, type(uint160).max)));
    }
}
