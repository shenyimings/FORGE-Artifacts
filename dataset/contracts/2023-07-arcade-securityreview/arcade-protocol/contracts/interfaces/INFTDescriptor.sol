// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface INFTDescriptor {
    function tokenURI(address token, uint256 tokenId) external view returns (string memory);
}