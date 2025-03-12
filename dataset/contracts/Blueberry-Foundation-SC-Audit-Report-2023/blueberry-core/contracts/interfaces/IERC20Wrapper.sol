// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IERC20Wrapper {
    /// @dev Return the underlying ERC-20 for the given ERC-1155 token id.
    function getUnderlyingToken(
        uint256 tokenId
    ) external view returns (address);

    function pendingRewards(
        uint256 id,
        uint amount
    ) external view returns (address[] memory, uint256[] memory);
}
