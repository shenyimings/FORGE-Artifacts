// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

interface IERC721Locker {
    /**
     * @dev Lock the `token`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {unlock} event.
     */
    function unlock(uint256 tokenId) external;

    function onERC721Locked(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);

    function onERC721Unlocked(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}
