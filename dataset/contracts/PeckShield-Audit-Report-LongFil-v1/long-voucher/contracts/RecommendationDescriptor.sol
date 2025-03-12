// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./ILongVoucherMetadataProvider.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract RecommendationDescriptor is ILongVoucherMetadataProvider {
    using Strings for uint256;

    string public name;
    string public desc;
    string public link;
    address public svg;

    constructor(string memory name_, string memory desc_, string memory link_, address svg_) {
        name = name_;
        desc = desc_;
        link = link_;
        svg = svg_;
    }

    function slotMetadata(
        uint256 slot_
    ) external view override returns (LongVoucherMetadata memory metadata) {
        slot_;
        metadata.name = name;
        metadata.desc = desc;
        metadata.link = link;
    }

    function tokenMetadata(
        uint256 tokenId_
    ) external view override returns (LongVoucherMetadata memory metadata) {
        metadata.name = string.concat(name, "#", tokenId_.toString());
        metadata.desc = metadata.name;
        metadata.link = string.concat(link, "/", tokenId_.toString());
    }

    function voucherSVG(
        uint256 tokenId_
    ) external view override returns (address) {
        tokenId_;
        return svg;
    }
} 
