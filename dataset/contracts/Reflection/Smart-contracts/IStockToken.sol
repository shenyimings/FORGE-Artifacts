// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IStockToken {
    /// @dev    Mint function to mint the stock token
    /// @param to (address)
    /// @param _amount (uint256)
    function mint(address to, uint256 _amount) external;

    /// @dev    Burn function to burn out Tokens
    /// @param from (address)
    /// @param _amount (uint256)
    function burn(address from, uint256 _amount) external;
}
