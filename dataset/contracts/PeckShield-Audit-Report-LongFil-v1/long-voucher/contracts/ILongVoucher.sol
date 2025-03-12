// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@solvprotocol/erc-3525/extensions/IERC721Enumerable.sol";
import "@solvprotocol/erc-3525/extensions/IERC3525Metadata.sol";
import "@solvprotocol/erc-3525/extensions/IERC3525SlotEnumerable.sol";

interface ILongVoucher is IERC3525Metadata, IERC721Enumerable, IERC3525SlotEnumerable {
    function existsToken(uint256 tokenId_) external view returns (bool);

    function existsSlot(uint256 slot_) external view returns (bool);

    function slotManagerCount() external view returns (uint256);

    function slotManagerByIndex(uint256 index_) external view returns (address);

    function managerOf(uint256 slot_) external view returns (address);

    function mint(address to_, uint256 slot_, uint256 value_) external returns (uint256);

    function burn(uint256 tokenId_) external;
}