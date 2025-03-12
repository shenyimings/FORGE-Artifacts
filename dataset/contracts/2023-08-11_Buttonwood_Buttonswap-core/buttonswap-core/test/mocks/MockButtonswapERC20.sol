// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import {ButtonswapERC20} from "../../src/ButtonswapERC20.sol";

contract MockButtonswapERC20 is ButtonswapERC20 {
    function mockMint(address to, uint256 value) public {
        _mint(to, value);
    }

    function mockBurn(address from, uint256 value) public {
        _burn(from, value);
    }
}
