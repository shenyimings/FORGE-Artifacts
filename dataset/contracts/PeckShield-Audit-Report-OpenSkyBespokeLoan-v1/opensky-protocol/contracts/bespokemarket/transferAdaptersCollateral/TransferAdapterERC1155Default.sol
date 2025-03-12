// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import './TransferAdapterCollateralBase.sol';

contract TransferAdapterERC1155Default is TransferAdapterCollateralBase {
    constructor(address settings_, address bespoke_settings_)
        TransferAdapterCollateralBase(settings_, bespoke_settings_)
    {}

    function _transferCollateralIn(
        address collection,
        address from,
        uint256 tokenId,
        uint256 amount
    ) internal override {
        IERC1155(collection).safeTransferFrom(from, address(this), tokenId, amount, '');
    }

    function _transferCollateralOut(
        address collection,
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal override {
        IERC1155(collection).safeTransferFrom(address(this), to, tokenId, amount, '');
    }

    function _transferCollateralOutOnForeclose(
        address collection,
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal override {
        IERC1155(collection).safeTransferFrom(address(this), to, tokenId, amount, '');
    }
}
