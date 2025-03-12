// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @dev Required interface of an NiimferNFT contract.
 */
interface INiimferNFT is IERC721 {
    struct NiimferInfo {
        uint256 sales_version;
        uint16 eventId;
        uint16 rareId;
    }

    /**
     * @dev Returns the total burned `niimfers`.
     */
    function totalBurned() external view returns (uint256);

    /**
     * @dev Returns whether the `niimfer token` exists.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function exists(uint256 tokenId) external view returns (bool);

    /**
     * @dev Returns the address who lock the `niimfer token`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function lockedBy(uint256 tokenId) external view returns (address);

    /**
     * @dev Lock the `niimfer token`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {lock} event.
     */
    function lock(uint256 tokenId, address locker) external;

    /**
     * @dev Unlock the `niimfer token`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {unlock} event.
     */
    function unlock(uint256 tokenId) external;

    /**
     * @dev Burn the `niimfer token`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {burn} event.
     */
    function burn(uint256 tokenId) external;

    function addTagToNiimfer(
        uint256 tokenId,
        uint256 sales_version,
        uint16 eventId,
        uint16 rareId
    ) external;

    event OnUpdateOfficialAccount(address account);
    event OnAddTagToNiimfer(uint256 tokenId, uint256 sales_version, uint16 eventId, uint16 rareId);
}
