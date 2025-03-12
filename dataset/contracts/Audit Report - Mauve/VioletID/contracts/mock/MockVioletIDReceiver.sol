// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {
    IERC1155ReceiverUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155ReceiverUpgradeable.sol";
import { IERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";

contract MockVioletIDReceiver is IERC1155ReceiverUpgradeable {
    address public immutable VIOLET_ID;

    constructor(address _violetId) {
        VIOLET_ID = _violetId;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual override returns (bytes4) {
        return IERC1155ReceiverUpgradeable.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external virtual override returns (bytes4) {
        return IERC1155ReceiverUpgradeable.onERC1155BatchReceived.selector;
    }

    // solhint-disable-next-line no-empty-blocks
    function supportsInterface(bytes4 interfaceId) external view returns (bool) {}

    function transferVID(address to) external {
        IERC1155Upgradeable(VIOLET_ID).safeTransferFrom(address(this), to, 0, 1, "");
    }

    function transferVIDBatch(address to) external {
        IERC1155Upgradeable(VIOLET_ID).safeBatchTransferFrom(address(this), to, new uint256[](0), new uint256[](1), "");
    }
}
