// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { LibERC20 } from "src/erc20/LibERC20.sol";

/// Create a fixture to test the library LibERC20

contract LibERC20Fixture {
    function transferFrom(
        address _token,
        address _from,
        address _to,
        uint256 _value
    ) external {
        LibERC20.transferFrom(_token, _from, _to, _value);
    }

    function transfer(
        address _token,
        address _to,
        uint256 _value
    ) external {
        LibERC20.transfer(_token, _to, _value);
    }
}
