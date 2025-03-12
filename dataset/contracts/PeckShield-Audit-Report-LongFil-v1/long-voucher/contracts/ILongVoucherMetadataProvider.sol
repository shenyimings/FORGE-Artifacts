// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface ILongVoucherMetadataProvider {
    struct Attribute {
        string name;
        string desc;
        string value;
    }

    struct LongVoucherMetadata {
        string name;
        string desc;
        string link;
        Attribute[20] attributes;
    }

    function slotMetadata(uint256 slot_) external view returns (LongVoucherMetadata memory);

    function tokenMetadata(uint256 tokenId_) external view returns (LongVoucherMetadata memory);

    function voucherSVG(uint256 tokenId_) external view returns (address);
}