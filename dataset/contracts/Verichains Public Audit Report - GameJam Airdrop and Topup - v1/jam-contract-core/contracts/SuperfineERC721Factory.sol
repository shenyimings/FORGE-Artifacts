// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./tokens/ERC721/SimpleERC721.sol";

contract SuperfineERC721Factory {
    SimpleERC721[] private uniqueItems;

    event CreateERC721(
        address indexed _owner,
        string template_type,
        address contract_address,
        string name,
        string symbol
    );

    function createERC721(
        string memory _name,
        string memory _symbol,
        string memory _tokenUri
    ) public {
        SimpleERC721 item = new SimpleERC721(
            msg.sender,
            _name,
            _symbol,
            _tokenUri
        );
        uniqueItems.push(item);
        emit CreateERC721(
            msg.sender,
            "SimpleERC721-V1",
            item.nftAddress(),
            _name,
            _symbol
        );
    }

    function getERC721(
        uint256 _index
    )
        public
        view
        returns (
            address nftAddress,
            address owner,
            string memory name,
            string memory symbol,
            uint256 totalSupply
        )
    {
        SimpleERC721 item = uniqueItems[_index];
        return (
            item.nftAddress(),
            item.owner(),
            item.name(),
            item.symbol(),
            item.totalSupply()
        );
    }
}
