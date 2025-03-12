// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IOpenSkyDutchAuctionLiquidator {
    event StartLiquidation(
        uint256 indexed loanId,
        uint256 indexed auctionId,
        uint256 borrowBalance,
        address indexed nftAddress,
        uint256 tokenId,
        address operator
    );

    event CancelLiquidation(
        uint256 indexed loanId,
        uint256 indexed auctionId,
        address indexed nftAddress,
        uint256 tokenId,
        address operator
    );

    event EndLiquidation(
        uint256 indexed loanId,
        uint256 indexed auctionId,
        address indexed nftAddress,
        uint256 tokenId,
        address operator
    );

    event TransferToAnotherLiquidator(
        uint256 indexed loanId,
        address indexed newLiquidator,
        address indexed nftAddress,
        uint256 tokenId,
        address operator
    );

    function startLiquidation(uint256 loanId) external;

    function cancelLiquidation(uint256 loanId) external;
 
    function endLiquidationByAuctionId(uint256 auctionId, uint256 amount) external;

    function transferToAnotherLiquidator(uint256 loanId, address liquidator) external;

    function getAuctionId(uint256 loanId) external view returns (uint256);

    function getLoanId(uint256 auctionId) external view returns (uint256);
}
