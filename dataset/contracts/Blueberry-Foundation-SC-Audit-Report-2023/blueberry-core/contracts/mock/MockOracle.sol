// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../utils/BlueBerryErrors.sol" as Errors;
import "../interfaces/IBaseOracle.sol";

contract MockOracle is IBaseOracle, Ownable {
    mapping(address => uint256) public prices; // Mapping from token to price (times 1e18).

    /// The governor sets oracle price for a token.
    event SetPrice(address token, uint256 px);

    /// @dev Return the USD based price of the given input, multiplied by 10**18.
    /// @param token The ERC-20 token to check the value.
    function getPrice(address token) external view override returns (uint256) {
        return prices[token];
    }

    /// @dev Set the prices of the given token addresses.
    /// @param tokens The token addresses to set the prices.
    /// @param pxs The price data points, representing token value in USD, based 1e18.
    function setPrice(address[] memory tokens, uint256[] memory pxs)
        external
        onlyOwner
    {
        if (tokens.length != pxs.length) revert Errors.INPUT_ARRAY_MISMATCH();
        for (uint256 idx = 0; idx < tokens.length; idx++) {
            prices[tokens[idx]] = pxs[idx];
            emit SetPrice(tokens[idx], pxs[idx]);
        }
    }
}
