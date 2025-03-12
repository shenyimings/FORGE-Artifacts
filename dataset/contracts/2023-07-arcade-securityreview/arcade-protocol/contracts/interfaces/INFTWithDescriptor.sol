// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface INFTWithDescriptor {
    // ============= Events ==============

    event SetDescriptor(address indexed caller, address indexed descriptor);

    // ================ Resource Metadata ================

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function setDescriptor(address descriptor) external;
}
