// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.6;


/**
 * @title GasGriefer
 * @author solace.fi
 * @notice Used to test safety of ETH transfers to arbitrary contracts. Will use as much gas is given and more.
 */
contract GasGriefer {

    uint256 public acc;

    receive () external payable {
        _grief();
    }

    fallback () external payable {
        _grief();
    }

    function _grief() internal {
        for(uint256 i = 0; i < type(uint256).max; i++) {
            acc += 1;
        }
    }
}
