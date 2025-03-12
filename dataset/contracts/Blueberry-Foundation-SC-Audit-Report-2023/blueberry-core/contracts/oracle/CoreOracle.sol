// SPDX-License-Identifier: MIT
/*
██████╗ ██╗     ██╗   ██╗███████╗██████╗ ███████╗██████╗ ██████╗ ██╗   ██╗
██╔══██╗██║     ██║   ██║██╔════╝██╔══██╗██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝
██████╔╝██║     ██║   ██║█████╗  ██████╔╝█████╗  ██████╔╝██████╔╝ ╚████╔╝
██╔══██╗██║     ██║   ██║██╔══╝  ██╔══██╗██╔══╝  ██╔══██╗██╔══██╗  ╚██╔╝
██████╔╝███████╗╚██████╔╝███████╗██████╔╝███████╗██║  ██║██║  ██║   ██║
╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝
*/

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "../utils/BlueBerryConst.sol" as Constants;
import "../utils/BlueBerryErrors.sol" as Errors;
import "../interfaces/ICoreOracle.sol";
import "../interfaces/IERC20Wrapper.sol";

/**
 * @author BlueberryProtocol
 * @title Core Oracle
 * @notice Oracle contract which provides price feeds to Bank contract
 */
contract CoreOracle is ICoreOracle, OwnableUpgradeable, PausableUpgradeable {
    /// @dev Mapping from token to oracle routes. => Aggregator | LP Oracle | AdapterOracle ...
    mapping(address => address) public routes;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __Ownable_init();
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Set oracle source routes for tokens
    /// @param tokens List of tokens
    /// @param oracleRoutes List of oracle source routes
    function setRoutes(
        address[] calldata tokens,
        address[] calldata oracleRoutes
    ) external onlyOwner {
        if (tokens.length != oracleRoutes.length)
            revert Errors.INPUT_ARRAY_MISMATCH();
        for (uint256 idx = 0; idx < tokens.length; idx++) {
            address token = tokens[idx];
            address route = oracleRoutes[idx];
            if (token == address(0) || route == address(0))
                revert Errors.ZERO_ADDRESS();

            routes[token] = route;
            emit SetRoute(token, route);
        }
    }

    /// @notice Return USD price of given token, multiplied by 10**18.
    /// @param token The ERC-20 token to get the price of.
    function _getPrice(
        address token
    ) internal view whenNotPaused returns (uint256) {
        address route = routes[token];
        if (route == address(0)) revert Errors.NO_ORACLE_ROUTE(token);
        uint256 px = IBaseOracle(route).getPrice(token);
        if (px == 0) revert Errors.PRICE_FAILED(token);
        return px;
    }

    /// @notice Return USD price of given token, multiplied by 10**18.
    /// @param token The ERC-20 token to get the price of.
    function getPrice(address token) external view override returns (uint256) {
        return _getPrice(token);
    }

    /// @notice Return whether the oracle supports given ERC20 token
    /// @param token The ERC20 token to check the support
    function _isTokenSupported(address token) internal view returns (bool) {
        address route = routes[token];
        if (route == address(0)) return false;
        try IBaseOracle(route).getPrice(token) returns (uint256 price) {
            return price != 0;
        } catch {
            return false;
        }
    }

    /// @notice Return whether the oracle supports given ERC20 token
    /// @param token The ERC20 token to check the support
    function isTokenSupported(
        address token
    ) external view override returns (bool) {
        return _isTokenSupported(token);
    }

    /// @notice Return whether the oracle supports underlying token of given wrapper.
    /// @dev Only validate wrappers of Blueberry protocol such as WERC20
    /// @param token ERC1155 token address to check the support
    /// @param tokenId ERC1155 token id to check the support
    function isWrappedTokenSupported(
        address token,
        uint256 tokenId
    ) external view override returns (bool) {
        address uToken = IERC20Wrapper(token).getUnderlyingToken(tokenId);
        return _isTokenSupported(uToken);
    }

    /**
     * @dev Return the USD value of the token and amount.
     * @param token ERC20 token address
     * @param amount ERC20 token amount
     */
    function _getTokenValue(
        address token,
        uint256 amount
    ) internal view returns (uint256 value) {
        uint256 decimals = IERC20MetadataUpgradeable(token).decimals();
        value = (_getPrice(token) * amount) / 10 ** decimals;
    }

    /**
     * @notice Return the USD value of wrapped ERC1155 tokens
     * @param token ERC1155 Wrapper token address to get collateral value of
     * @param id ERC1155 token id to get collateral value of
     * @param amount Token amount to get collateral value of, based 1e18
     */
    function getWrappedTokenValue(
        address token,
        uint256 id,
        uint256 amount
    ) external view override returns (uint256 positionValue) {
        address uToken = IERC20Wrapper(token).getUnderlyingToken(id);
        positionValue = _getTokenValue(uToken, amount);
    }

    /**
     * @dev Return the USD value of the token and amount.
     * @param token ERC20 token address
     * @param amount ERC20 token amount
     */
    function getTokenValue(
        address token,
        uint256 amount
    ) external view override returns (uint256) {
        return _getTokenValue(token, amount);
    }
}
