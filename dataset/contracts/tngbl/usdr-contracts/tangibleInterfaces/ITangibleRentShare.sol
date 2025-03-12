// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

interface ITangibleRentShare {
    function forToken(address contractAddress, uint256 tokenId)
        external
        returns (address);
}
