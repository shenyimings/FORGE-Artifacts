// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./SwapHelper.sol";

contract SwapHelperMainnet is SwapHelper {
    constructor()
        SwapHelper(ISwapRouter02(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
    {}
}
