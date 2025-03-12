// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

interface ITangibleRevenueShare {
    function claimForToken(address contractAddress, uint256 tokenId) external;

    function revenueToken() external view returns (address);
}
