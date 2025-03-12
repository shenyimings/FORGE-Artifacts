// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import './TransferAdapterCollateralBase.sol';

contract TransferAdapterERC721Default is TransferAdapterCollateralBase {
    constructor(address settings_, address bespoke_settings_)
        TransferAdapterCollateralBase(settings_, bespoke_settings_)
    {}

    function _transferCollateralIn(
        address collection,
        address from,
        uint256 tokenId,
        uint256 amount
    ) internal override {
        IERC721(collection).safeTransferFrom(from, address(this), tokenId);
    }

    function _transferCollateralOut(
        address collection,
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal override {
        IERC721(collection).safeTransferFrom(address(this), to, tokenId);
    }

    function _transferCollateralOutOnForeclose(
        address collection,
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal override {
        IERC721(collection).safeTransferFrom(address(this), to, tokenId);
    }
}
