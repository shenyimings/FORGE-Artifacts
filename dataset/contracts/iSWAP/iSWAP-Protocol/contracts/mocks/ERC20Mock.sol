// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@boringcrypto/boring-solidity/contracts/mocks/MockERC20.sol";

contract ERC20Mock is MockERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) public MockERC20(supply) {}
}
