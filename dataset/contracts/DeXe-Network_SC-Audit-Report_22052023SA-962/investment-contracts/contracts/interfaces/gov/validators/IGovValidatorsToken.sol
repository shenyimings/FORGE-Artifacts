// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * This is the contract that determines the validators
 */
interface IGovValidatorsToken is IERC20 {
    /// @notice Mint new tokens, available only from `Validators` contract
    /// @param account Address
    /// @param amount Token amount to mint. Wei
    function mint(address account, uint256 amount) external;

    /// @notice Burn tokens, available only from `Validators` contract
    /// @param account Address
    /// @param amount Token amount to burn. Wei
    function burn(address account, uint256 amount) external;

    /// @notice Create tokens snapshot
    /// @return Snapshot ID
    function snapshot() external returns (uint256);
}
