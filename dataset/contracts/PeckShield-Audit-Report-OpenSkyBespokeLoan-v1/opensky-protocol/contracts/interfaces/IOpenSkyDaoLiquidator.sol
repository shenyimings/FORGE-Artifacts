// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IOpenSkyDaoLiquidator {
    event Liquidate(uint256 indexed loanId, address indexed nftAddress, uint256 tokenId, address operator);
    event WithdrawERC721(address indexed token, uint256 tokenId, address indexed to);

    function startLiquidate(uint256 loanId) external;
}
