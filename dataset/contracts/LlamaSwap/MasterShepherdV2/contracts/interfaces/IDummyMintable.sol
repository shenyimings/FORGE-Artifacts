// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";

interface IDummyMintable is IBEP20 {
    function mint(uint256 amount) external;
}