// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface ITransferAdapterNFT {
    function transferCollateralIn(
        address collection,
        address from,
        uint256 tokenId,
        uint256 amount
    ) external;

    function transferCollateralOut(
        address collection,
        address to,
        uint256 tokenId,
        uint256 amount
    ) external;

    function transferCollateralOutOnForeclose(
        address collection,
        address to,
        uint256 tokenId,
        uint256 amount
    ) external;
}
