// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IOpenSkyDutchAuctionLiquidator {
    event StartLiquidate(
        uint256 indexed loanId,
        uint256 indexed auctionId,
        uint256 borrowBalance,
        address indexed nftAddress,
        uint256 tokenId,
        address operator
    );

    event CancelLiquidate(
        uint256 indexed loanId,
        uint256 indexed auctionId,
        address indexed nftAddress,
        uint256 tokenId,
        address operator
    );

    event EndLiquidate(
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

    function startLiquidate(uint256 loanId) external;

    function cancelLiquidate(uint256 loanId) external;
    
    function endLiquidateByAuctionId(uint256 auctionId) payable external;

    function transferToAnotherLiquidator(uint256 loanId, address liquidator) external;

    function getAuctionId(uint256 loanId) external view returns (uint256);

    function getLoanId(uint256 auctionId) external view returns (uint256);
}
