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

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../utils/BlueBerryErrors.sol" as Errors;
import "../interfaces/IWERC20.sol";

/**
 * @title WERC20
 * @author BlueberryProtocol
 * @notice Wrapped ERC20 is the wrapper of LP positions
 * @dev Leveraged LP Tokens will be wrapped here and be held in BlueberryBank and do not generate yields.
 *      LP Tokens are identified by tokenIds encoded from lp token address
 */
contract WERC20 is ERC1155Upgradeable, ReentrancyGuardUpgradeable, IWERC20 {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __ReentrancyGuard_init();
        __ERC1155_init("WERC20");
    }

    /// @dev Encode given underlying token address to tokenId
    function _encodeTokenId(address uToken) internal pure returns (uint) {
        return uint256(uint160(uToken));
    }

    /// @dev Decode given tokenId to underlyingToken address
    function _decodeTokenId(uint tokenId) internal pure returns (address) {
        return address(uint160(tokenId));
    }

    /// @dev Return the underlying ERC-20 for the given ERC-1155 token id.
    /// @param tokenId token id (corresponds to token address for wrapped ERC20)
    function getUnderlyingToken(
        uint256 tokenId
    ) external pure override returns (address token) {
        token = _decodeTokenId(tokenId);
        if (_encodeTokenId(token) != tokenId)
            revert Errors.INVALID_TOKEN_ID(tokenId);
    }

    /// @notice Return pending rewards from the farming pool
    /// @dev Reward tokens can be multiple tokens
    /// @param tokenId Token Id
    /// @param amount amount of share
    function pendingRewards(
        uint256 tokenId,
        uint amount
    ) public view override returns (address[] memory, uint256[] memory) {}

    /// @dev Return the underlying ERC20 balance for the user.
    /// @param token token address to get balance of
    /// @param user user address to get balance of
    function balanceOfERC20(
        address token,
        address user
    ) external view override returns (uint256) {
        return balanceOf(user, _encodeTokenId(token));
    }

    /// @dev Mint ERC1155 token for the given ERC20 token.
    /// @param token token address to wrap
    /// @param amount token amount to wrap
    function mint(
        address token,
        uint256 amount
    ) external override nonReentrant {
        uint256 balanceBefore = IERC20Upgradeable(token).balanceOf(
            address(this)
        );
        IERC20Upgradeable(token).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
        uint256 balanceAfter = IERC20Upgradeable(token).balanceOf(
            address(this)
        );
        _mint(
            msg.sender,
            _encodeTokenId(token),
            balanceAfter - balanceBefore,
            ""
        );
    }

    /// @dev Burn ERC1155 token to redeem ERC20 token back.
    /// @param token token address to burn
    /// @param amount token amount to burn
    function burn(
        address token,
        uint256 amount
    ) external override nonReentrant {
        _burn(msg.sender, _encodeTokenId(token), amount);
        IERC20Upgradeable(token).safeTransfer(msg.sender, amount);
    }
}
