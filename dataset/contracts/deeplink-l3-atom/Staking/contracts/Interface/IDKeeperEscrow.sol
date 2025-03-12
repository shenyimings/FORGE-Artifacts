// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/ERC20.sol)

pragma solidity 0.8.4;

interface IDKeeperEscrow {
    function mint(address account, uint256 amount) external;
}
