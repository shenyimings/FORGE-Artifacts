// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BEP20Harness is ERC20 {
    uint8 public decimalsInternal = 18;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        decimalsInternal = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return decimalsInternal;
    }
}
