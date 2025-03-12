// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "./ERC1155Tradable.sol";

contract TestERC1155OpenSea is ERC1155Tradable {
    constructor(address proxyRegistryAddress)
        ERC1155Tradable(
            "OpenSea NFT1155",
            "JamNFT1155",
            "https://gamejam.com/nft1155/",
            proxyRegistryAddress
        )
    {}
}
