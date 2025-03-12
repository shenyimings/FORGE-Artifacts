// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {IERC20} from "./../../../src/interfaces/IERC20.sol";

/// @title MockSUSD contract for testing
/// @author JaredBorders (jaredborders@pm.me)
contract MockSUSD is IERC20 {
    function decimals() external pure override returns (uint8) {
        return 18;
    }

    function balanceOf(address) external pure override returns (uint256) {
        return 0;
    }

    function transfer(address, uint256) external pure override returns (bool) {
        return true;
    }

    function approve(address, uint256) external pure override returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256)
        external
        pure
        override
        returns (bool)
    {
        return true;
    }
}
