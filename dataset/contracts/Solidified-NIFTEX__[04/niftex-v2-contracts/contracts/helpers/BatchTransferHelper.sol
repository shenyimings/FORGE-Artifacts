// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract BatchTransferHelper
{
    function batchTransferERC721(
        address[] calldata to,
        address[] calldata registry,
        uint256[] calldata id)
    external
    {
        require(to.length == registry.length);
        require(to.length == id.length);
        for (uint256 i = 0; i < to.length; ++i)
        {
            IERC721(registry[i]).transferFrom(msg.sender, to[i], id[i]);
        }
    }

    function batchTransferERC1155(
        address[]   calldata to,
        address[]   calldata registry,
        uint256[][] calldata id,
        uint256[][] calldata amount,
        bytes[]     calldata data)
    external
    {
        require(to.length == registry.length);
        require(to.length == id.length);
        require(to.length == amount.length);
        require(to.length == data.length);
        for (uint256 i = 0; i < to.length; ++i)
        {
            IERC1155(registry[i]).safeBatchTransferFrom(msg.sender, to[i], id[i], amount[i], data[i]);
        }
    }

}
