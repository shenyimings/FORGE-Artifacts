// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

interface ITangiblePiNFT {
    function claim(uint256 tokenId, uint256 amount) external;

    function claimableIncome(uint256 tokenId)
        external
        view
        returns (uint256, uint256);
}
