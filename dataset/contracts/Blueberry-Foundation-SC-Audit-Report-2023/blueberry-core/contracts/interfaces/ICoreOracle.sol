// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "./IBaseOracle.sol";

interface ICoreOracle is IBaseOracle {
    /// The owner sets oracle routes
    event SetRoute(address indexed token, address route);

    /// @notice Return whether the oracle given ERC20 token
    /// @param token The ERC20 token to check the support
    function isTokenSupported(address token) external view returns (bool);

    /// @notice Return whether the oracle supports underlying token of given wrapper.
    /// @dev Only validate wrappers of Blueberry protocol such as WERC20
    /// @param token ERC1155 token address to check the support
    /// @param tokenId ERC1155 token id to check the support
    function isWrappedTokenSupported(
        address token,
        uint256 tokenId
    ) external view returns (bool);

    /**
     * @dev Return the USD value of wrapped ERC1155 tokens
     * @param token ERC1155 token address to get collateral value
     * @param id ERC1155 token id to get collateral value
     * @param amount Token amount to get collateral value, based 1e18
     */
    function getWrappedTokenValue(
        address token,
        uint256 id,
        uint256 amount
    ) external view returns (uint256);

    /**
     * @dev Return the USD value of the token and amount.
     * @param token ERC20 token address
     * @param amount ERC20 token amount
     */
    function getTokenValue(
        address token,
        uint256 amount
    ) external view returns (uint256);
}
