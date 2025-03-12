// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBasicERC1155 {
    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;

    function setURI(string calldata newuri) external;
}
